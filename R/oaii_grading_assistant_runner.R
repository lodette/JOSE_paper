# ======================================================================
# Grading Assistant runner in R
# - Reads key from .Renviron
# - Reads assistant_config.json for IDs
# - Walks student folders
# - Creates a thread per student, attaches rubric, solution, starter
# - Runs the assistant, polls, parses JSON reply into a table
# - Writes a UTF-8 BOM CSV for Excel compatibility
# ======================================================================

# ---- deps ----
# check if 'librarian' is installed and if not, install it
if (! "librarian" %in% rownames(installed.packages()) ){
  install.packages("librarian")
}

# load packages if not already loaded
librarian::shelf(
  tidyverse, rmarkdown, httr2, jsonlite, utils, base, fs, quarto,
  cezarykuran/oaii
)

# set the lab number
LAB_NUMBER <- 9
# set up for processing
source("./R/oaii_grading_assistant.R")

# -------------------
# Config
# -------------------
CONFIG_JSON    <- "./assignment/assistant_config.json"
directory_path <- paste0(getwd(),"/assignment")
output_csv     <- paste0(directory_path,"/r_lab9_grades.csv")
# -------------------
# Load assistant and file IDs
# -------------------
cfg                <- jsonlite::fromJSON(CONFIG_JSON, simplifyVector = TRUE)
assistant_id       <- cfg[["assistant_id"]]
rubric_file_id     <- cfg[["rubric_file_id"]]
solution_file_id   <- cfg[["solution_file_id"]]
starter_file_id    <- cfg[["starter_file_id"]]

# -------------------
# Assistants helpers using httr2
# -------------------

#' Build an authenticated OpenAI Assistants v2 request
#'
#' Constructs an \code{httr2} request object targeting the OpenAI v1 API,
#' pre-populated with a Bearer token from the \code{OPENAI_API_KEY} environment
#' variable and the \code{OpenAI-Beta: assistants=v2} header required by the
#' Assistants API.
#'
#' @param path Character. The API path to append to
#'   \code{https://api.openai.com/v1}, e.g. \code{"/threads"} or
#'   \code{"/threads/{id}/runs"}.
#'
#' @returns An \code{httr2_request} object ready for further modification (e.g.
#'   adding a body) and execution via \code{httr2::req_perform()}.
#'
#' @examples
openai_req <- function(path) {
  key <- Sys.getenv("OPENAI_API_KEY", unset = NA_character_)
  if (is.na(key) || !nzchar(key)) stop("OPENAI_API_KEY is not set.")
  httr2::request(paste0("https://api.openai.com/v1", path)) |>
    httr2::req_headers(
      "Authorization" = paste("Bearer", key),
      "OpenAI-Beta"   = "assistants=v2"
    )
}

#' Create a new OpenAI Assistants v2 thread
#'
#' Sends a \code{POST /threads} request to the OpenAI Assistants API to create
#' an empty conversation thread. A new thread should be created for each student
#' so that grading contexts remain isolated.
#'
#' @returns A named list representing the created thread object, including at
#'   minimum \code{$id} (the thread ID string used in subsequent API calls).
#'
#' @examples
create_thread <- function() {
  resp <- openai_req("/threads") |>
    httr2::req_headers("Content-Type" = "application/json") |>
    httr2::req_body_json(list(), auto_unbox = TRUE) |>
    httr2::req_perform()
  httr2::resp_check_status(resp)
  httr2::resp_body_json(resp, simplifyVector = TRUE)
}

#' Add a message to an OpenAI Assistants v2 thread
#'
#' Sends a \code{POST /threads/{thread_id}/messages} request to append a message
#' to an existing thread. In the grading workflow this is used to inject the
#' student submission along with file attachments (rubric, solution, starter)
#' that the assistant can search via \code{file_search}.
#'
#' @param thread_id Character. The ID of the thread to add the message to,
#'   as returned by \code{create_thread()$id}.
#' @param content Character. The text content of the message (e.g. the grading
#'   prompt including the student submission).
#' @param role Character. The role of the message author. Defaults to
#'   \code{"user"}; the Assistants API also accepts \code{"assistant"}.
#' @param attachments List or \code{NULL}. Optional list of file attachment
#'   objects, each with elements \code{file_id} (character) and \code{tools}
#'   (list specifying which tools can access the file, e.g.
#'   \code{list(list(type = "file_search"))}). Pass \code{NULL} for no
#'   attachments.
#'
#' @returns A named list representing the created message object as returned by
#'   the API, including its \code{$id}, \code{$role}, and \code{$content}.
#'
#' @examples
add_message <- function(thread_id, content, role = "user", attachments = NULL) {
  body <- list(
    role = role,
    content = content,
    attachments = attachments
  )
  resp <- openai_req(sprintf("/threads/%s/messages", thread_id)) |>
    httr2::req_headers("Content-Type" = "application/json") |>
    httr2::req_body_json(body, auto_unbox = TRUE, null = "null") |>
    httr2::req_perform()
  httr2::resp_check_status(resp)
  httr2::resp_body_json(resp, simplifyVector = TRUE)
}

#' Start an assistant run on an OpenAI Assistants v2 thread
#'
#' Sends a \code{POST /threads/{thread_id}/runs} request to trigger the
#' assistant to process the thread's messages. Runs are asynchronous; use
#' \code{wait_run_complete()} to poll until the run reaches a terminal state.
#'
#' @param thread_id Character. The ID of the thread to run the assistant on,
#'   as returned by \code{create_thread()$id}.
#' @param assistant_id Character. The ID of the assistant to use, as stored in
#'   \code{assistant_config.json} by \code{oaii_grading_assistant.R}.
#'
#' @returns A named list representing the run object, including at minimum
#'   \code{$id} (the run ID) and \code{$status} (initially \code{"queued"} or
#'   \code{"in_progress"}).
#'
#' @examples
start_run <- function(thread_id, assistant_id) {
  body <- list(assistant_id = assistant_id)
  resp <- openai_req(sprintf("/threads/%s/runs", thread_id)) |>
    httr2::req_headers("Content-Type" = "application/json") |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_perform()
  httr2::resp_check_status(resp)
  httr2::resp_body_json(resp, simplifyVector = TRUE)
}

#' Retrieve the current status of an OpenAI Assistants v2 run
#'
#' Sends a \code{GET /threads/{thread_id}/runs/{run_id}} request to fetch the
#' latest state of a run. Intended to be called repeatedly inside a polling
#' loop; prefer \code{wait_run_complete()} for blocking until completion.
#'
#' @param thread_id Character. The ID of the thread that owns the run.
#' @param run_id Character. The ID of the run to retrieve, as returned by
#'   \code{start_run()$id}.
#'
#' @returns A named list representing the run object. The \code{$status} element
#'   reflects the current state: one of \code{"queued"}, \code{"in_progress"},
#'   \code{"completed"}, \code{"failed"}, \code{"cancelled"}, or
#'   \code{"expired"}.
#'
#' @examples
retrieve_run <- function(thread_id, run_id) {
  resp <- openai_req(sprintf("/threads/%s/runs/%s", thread_id, run_id)) |>
    httr2::req_perform()
  httr2::resp_check_status(resp)
  httr2::resp_body_json(resp, simplifyVector = TRUE)
}

#' List messages in an OpenAI Assistants v2 thread
#'
#' Sends a \code{GET /threads/{thread_id}/messages} request to retrieve recent
#' messages from a thread. Returns results as a raw (non-simplified) list so
#' that nested content blocks are preserved for extraction by
#' \code{latest_assistant_text()}.
#'
#' @param thread_id Character. The ID of the thread whose messages to list.
#' @param order Character. Sort order for messages by creation time. Either
#'   \code{"desc"} (newest first, the default) or \code{"asc"} (oldest first).
#' @param limit Integer. Maximum number of messages to return. Defaults to
#'   \code{15}.
#'
#' @returns A named list representing the API page object, with a \code{$data}
#'   element containing a list of message objects. Each message object includes
#'   \code{$role} (\code{"user"} or \code{"assistant"}) and \code{$content}
#'   (a list of typed content blocks, e.g. \code{list(type = "text", text =
#'   list(value = "..."))}).
#'
#' @examples
list_messages <- function(thread_id, order = "desc", limit = 15) {
  resp <- openai_req(sprintf("/threads/%s/messages?order=%s&limit=%d", thread_id, order, limit)) |>
    httr2::req_perform()
  httr2::resp_check_status(resp)
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}

#' Poll an OpenAI Assistants v2 run until it reaches a terminal state
#'
#' Repeatedly calls \code{retrieve_run()} at a fixed interval until the run
#' status is one of \code{"completed"}, \code{"failed"}, \code{"cancelled"}, or
#' \code{"expired"}, or until the timeout is exceeded. This is a blocking call;
#' script execution is suspended between polls via \code{Sys.sleep()}.
#'
#' @param thread_id Character. The ID of the thread that owns the run.
#' @param run_id Character. The ID of the run to poll, as returned by
#'   \code{start_run()$id}.
#' @param sleep_seconds Numeric. Seconds to wait between status checks.
#'   Defaults to \code{0.7}.
#' @param timeout_seconds Numeric. Maximum total seconds to wait before
#'   returning regardless of status. Defaults to \code{180}. The returned run
#'   object should be inspected for a non-\code{"completed"} status when the
#'   timeout is reached.
#'
#' @returns A named list representing the final run object at the point the
#'   function returned. Check \code{$status} to distinguish a successful
#'   completion (\code{"completed"}) from a timeout or failure.
#'
#' @examples
wait_run_complete <- function(thread_id, run_id, sleep_seconds = 0.7, timeout_seconds = 180) {
  t0 <- Sys.time()
  repeat {
    run <- retrieve_run(thread_id, run_id)
    s <- run$status
    if (s %in% c("completed", "failed", "cancelled", "expired")) return(run)
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > timeout_seconds) {
      return(run)
    }
    Sys.sleep(sleep_seconds)
  }
}

#' Extract the most recent assistant text reply from a thread
#'
#' Retrieves the thread's message list (newest first) and returns the
#' concatenated text content of the first message whose role is
#' \code{"assistant"}. Only \code{"text"} content blocks are included;
#' any image or file-citation blocks are ignored.
#'
#' @param thread_id Character. The ID of the thread to query.
#'
#' @returns A length-1 character string containing the assistant's reply text,
#'   with multiple text content blocks joined by \code{"\n"}. Returns an empty
#'   string (\code{""}) if no assistant message is found or if the thread
#'   contains no messages.
#' @export
#'
#' @examples
latest_assistant_text <- function(thread_id) {
  msgs <- list_messages(thread_id, order = "desc", limit = 15)
  data <- msgs[["data"]]
  if (is.null(data)) return("")
  for (m in data) {
    if (identical(m[["role"]], "assistant")) {
      parts <- character()
      content <- m[["content"]]
      if (is.list(content)) {
        for (c in content) {
          if (identical(c[["type"]], "text")) {
            val <- c[["text"]][["value"]]
            if (is.character(val)) parts <- c(parts, val)
          }
        }
      }
      return(paste(parts, collapse = "\n"))
    }
  }
  ""
}

# -------------------
# Helpers for parsing
# -------------------
Q_COUNT <- 10L
Q_COLS  <- paste0("Q", 1:Q_COUNT)

#' Extract a question number from a key or label string
#'
#' Parses common question-label formats produced by the LLM (e.g. \code{"Q1"},
#' \code{"q1"}, \code{"question_1"}, \code{"Question 3"}, or a bare integer
#' string like \code{"7"}) and returns the corresponding integer. Returns
#' \code{NA_integer_} for strings that cannot be mapped to a valid question
#' number within the range \code{1:Q_COUNT}.
#'
#' @param key_or_value Character, integer, or \code{NULL}. The label to parse.
#'   \code{NULL} is treated as a missing value and returns \code{NA_integer_}.
#'
#' @returns An integer in \code{1:Q_COUNT} if a valid question number is found,
#'   otherwise \code{NA_integer_}.
#'
#' @examples
extract_qnum <- function(key_or_value) {
  if (is.null(key_or_value)) return(NA_integer_)
  s <- trimws(as.character(key_or_value))

  # capture the digits in group 1
  rx <- regexec("(?i)(?:q|question)?\\s*_?(\\d{1,2})", s, perl = TRUE)
  mm <- regmatches(s, rx)[[1]]
  if (length(mm) >= 2L) {
    n <- as.integer(mm[2])
    if (!is.na(n) && n >= 1L && n <= Q_COUNT) return(n)
  }

  # bare number fallback
  if (grepl("^[0-9]+$", s)) {
    n <- as.integer(s)
    if (!is.na(n) && n >= 1L && n <= Q_COUNT) return(n)
  }

  NA_integer_
}

#' Safely coerce a value to a numeric (double)
#'
#' Attempts to convert \code{x} to a numeric value, suppressing the warning
#' that \code{as.numeric()} would otherwise emit on non-coercible inputs.
#' Intended for converting LLM-returned grade values that may be numeric,
#' integer, or character strings.
#'
#' @param x A scalar value of any type (typically numeric, integer, or
#'   character).
#'
#' @returns A length-1 double. Returns \code{NA_real_} if \code{x} cannot be
#'   coerced to a number (e.g. \code{NULL}, \code{NA}, or a non-numeric
#'   string).
#' @export
#'
#' @examples
coerce_float <- function(x) {
  v <- suppressWarnings(as.numeric(x))
  if (is.na(v)) return(NA_real_)
  v
}

#' Parse an LLM grading reply into a single-row named list
#'
#' Accepts the raw text returned by the grading assistant and attempts to
#' extract per-question grades and feedback into a flat named list suitable for
#' binding into a data frame. Handles three JSON schemas that the model may
#' produce: (1) a named \code{questions} object keyed by \code{"Q1"} through
#' \code{"Q10"}, (2) an array of question objects each with a \code{"question"}
#' key, and (3) a flat top-level object with question-keyed entries. If JSON
#' parsing fails entirely, the row is returned with all grade columns set to
#' \code{NA} and the raw reply truncated into the \code{Comments} field.
#'
#' @param reply_text Character. The raw text content of the assistant's reply,
#'   expected to be a JSON string but handled defensively if not.
#' @param student_name Character. The student identifier to populate the
#'   \code{Student} column of the returned row.
#'
#' @returns A named list with the following elements:
#'   \describe{
#'     \item{\code{Student}}{Character. The value of \code{student_name}.}
#'     \item{\code{Q1} through \code{Q10}}{Numeric (double). The grade for each
#'       question, or \code{NA_real_} if not found.}
#'     \item{\code{Total}}{Numeric (double). The overall total grade reported
#'       by the model, or \code{NA_real_} if absent.}
#'     \item{\code{Comments}}{Character. Per-question feedback strings
#'       concatenated with \code{" | "} as separator, or a parse-error message
#'       if JSON parsing failed, or \code{NA_character_} if no feedback was
#'       provided.}
#'   }
#' @export
#'
#' @examples
parse_reply_to_row <- function(reply_text, student_name) {
  row <- as.list(stats::setNames(rep(list(NA_real_), length(Q_COLS)), Q_COLS))
  row <- append(list(Student = student_name), row)
  row[["Total"]] <- NA_real_
  row[["Comments"]] <- NA_character_

  payload <- NULL
  try({
    payload <- jsonlite::fromJSON(reply_text, simplifyVector = FALSE)
  }, silent = TRUE)

  if (is.null(payload)) {
    row[["Comments"]] <- sprintf("ParseError. Raw reply start. %s", substr(reply_text, 1L, 1200L))
    return(row)
  }

  per_q <- new.env(parent = emptyenv())
  comments <- character()

  questions <- payload[["questions"]]
  if (is.null(questions)) questions <- payload[["per_question"]]
  if (is.null(questions)) questions <- payload[["exercises"]]

  if ( is.list(questions) && !is.null(names(questions)) ) {
    # dict-like
    for (k in names(questions)) {
      v <- questions[[k]]
      qn <- extract_qnum(k)
      if (is.na(qn)) next
      grade <- coerce_float(v[["grade"]] %||% v[["score"]])
      feedback <- v[["feedback"]] %||% v[["comments"]] %||% ""
      per_q[[as.character(qn)]] <- list(grade = grade, feedback = feedback)
    }
  } else if (is.list(questions) && is.null(names(questions))) {
    # list of items
    for (item in questions) {
      qn <- extract_qnum(item[["question"]] %||% item[["id"]] %||% item[["name"]])
      if (is.na(qn)) next
      grade <- coerce_float(item[["grade"]] %||% item[["score"]])
      feedback <- item[["feedback"]] %||% item[["comments"]] %||% ""
      per_q[[as.character(qn)]] <- list(grade = grade, feedback = feedback)
    }
  }

  if (length(ls(per_q)) == 0L) {
    for (k in names(payload)) {
      qn <- extract_qnum(k)
      if (is.na(qn)) next
      v <- payload[[k]]
      if (is.list(v)) {
        grade <- coerce_float(v[["grade"]] %||% v[["score"]])
        feedback <- v[["feedback"]] %||% v[["comments"]] %||% ""
      } else {
        grade <- coerce_float(v)
        feedback <- ""
      }
      per_q[[as.character(qn)]] <- list(grade = grade, feedback = feedback)
    }
  }

  for (i in 1:Q_COUNT) {
    key <- as.character(i)
    if (!exists(key, envir = per_q, inherits = FALSE)) next
    gi <- per_q[[key]][["grade"]]
    fb <- trimws(as.character(per_q[[key]][["feedback"]] %||% ""))
    row[[paste0("Q", i)]] <- gi
    if (nzchar(fb)) comments <- c(comments, sprintf("Q%d. %s", i, fb))
  }

  total <- payload[["total"]] %||% payload[["overall"]] %||% payload[["sum"]] %||% payload[["final"]]
  row[["Total"]] <- coerce_float(total)
  row[["Comments"]] <- if (length(comments)) paste(comments, collapse = " | ") else NA_character_
  row
}

#' Null-coalescing operator
#'
#' Returns \code{a} if it is not \code{NULL}, otherwise returns \code{b}.
#' Useful for providing fallback values when extracting fields from loosely
#' structured lists (e.g. LLM JSON responses where field names may vary).
#'
#' @param a An R object. Returned as-is if not \code{NULL}.
#' @param b An R object. Returned when \code{a} is \code{NULL}.
#'
#' @returns \code{a} if \code{!is.null(a)}, otherwise \code{b}.
`%||%` <- function(a, b) if (!is.null(a)) a else b

# -------------------
# Main loop to data frame
# -------------------
records <- list()

# immediate subfolders only
all_entries <- list.dirs(directory_path, full.names = TRUE, recursive = FALSE)
subdirs <- all_entries[file.info(all_entries)$isdir %in% TRUE]

for (folder in subdirs) { #folder = subdirs[20]
  student_file <- file.path(folder, "2025-lab-9.qmd")
  if (!file.exists(student_file)) {
    message("Skipping ", basename(folder), ". Missing 2025-lab-3.qmd")
    next
  }

  student_name <- stringr::str_remove(basename(folder), "(?i)^2025-lab-9_")
  student_text <- readChar(student_file, nchars = file.info(student_file)$size, useBytes = TRUE)

  prompt <- paste0(
    "Grade the following student submission using the uploaded rubric, ",
    "reference solution, and starter file. Follow the rubric strictly and return JSON only ",
    "with per-exercise grades and feedback and the total.\n\n",
    "Your JSON schema SHOULD be one of.\n",
    "1) {\n",
    "  \"questions\": {\n",
    "    \"Q1\": {\"grade\": <number>, \"feedback\": \"<text>\"},\n",
    "    ...\n",
    "    \"Q10\": {\"grade\": <number>, \"feedback\": \"<text>\"}\n",
    "  },\n",
    "  \"total\": <number>\n",
    "}\n",
    "OR\n",
    "2) {\n",
    "  \"questions\": [\n",
    "    {\"question\": \"Q1\", \"grade\": <number>, \"feedback\": \"<text>\"},\n",
    "    ...,\n",
    "    {\"question\": \"Q10\", \"grade\": <number>, \"feedback\": \"<text>\"}\n",
    "  ],\n",
    "  \"total\": <number>\n",
    "}\n\n",
    "Return JSON only. Do not wrap in code fences.\n\n",
    "--- STUDENT SUBMISSION START ---\n",
    student_text,
    "\n--- STUDENT SUBMISSION END ---\n"
  )

  # thread
  thread <- create_thread()

  # message with attachments for file_search
  attachments <- list(
    list(file_id = rubric_file_id,   tools = list(list(type = "file_search"))),
    list(file_id = solution_file_id, tools = list(list(type = "file_search"))),
    list(file_id = starter_file_id,  tools = list(list(type = "file_search")))
  )

  invisible(add_message(thread_id = thread$id, content = prompt, role = "user", attachments = attachments))

  # run
  run <- start_run(thread_id = thread$id, assistant_id = assistant_id)

  # poll with timeout
  final_run <- wait_run_complete(thread_id = thread$id, run_id = run$id, sleep_seconds = 0.7, timeout_seconds = 180)

  if (!identical(final_run$status, "completed")) {
    empty_row <- as.list(stats::setNames(rep(list(NA_real_), length(Q_COLS)), Q_COLS))
    empty_row <- append(list(Student = student_name), empty_row)
    empty_row[["Total"]] <- NA_real_
    empty_row[["Comments"]] <- sprintf("Run status. %s", final_run$status)
    records[[length(records) + 1L]] <- empty_row
    message("Run not completed for ", student_name, ". Status ", final_run$status)
    next
  }

  reply_text <- latest_assistant_text(thread$id)
  row <- parse_reply_to_row(reply_text, student_name)
  records[[length(records) + 1L]] <- row
  message("Collected ", student_name)
}

# -------------------
# Build data frame and save
# -------------------
if (length(records)) {
  # ensure consistent columns
  col_order <- c("Student", Q_COLS, "Total", "Comments")
  # coerce lists to data frame
  df <- do.call(rbind.data.frame, lapply(records, function(x) {
    # fill missing columns with NA
    miss <- setdiff(col_order, names(x))
    if (length(miss)) for (m in miss) x[[m]] <- NA
    # order columns
    x <- x[col_order]
    # return one row data.frame
    as.data.frame(x, stringsAsFactors = FALSE)
  }))
  # write CSV with BOM for Excel
  readr::write_excel_csv(df, output_csv, na = "")
  message("Saved grades table to ", output_csv)
  utils::head(df, n = min(10L, nrow(df)))
} else {
  message("No records to write.")
}