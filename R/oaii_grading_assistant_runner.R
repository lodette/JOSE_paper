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
# set up for processing (also defines openai_req, qmd_to_temp_md,
# upload_for_assistants, and create_assistant_v2)
source("./R/oaii_grading_assistant.R")

# -------------------
# Config
# -------------------
CONFIG_JSON    <- "./assignment/assistant_config.json"
directory_path <- paste0(getwd(), "/assignment")
output_csv     <- stringr::str_glue("{directory_path}/r_lab{LAB_NUMBER}_grades.csv")

# -------------------
# Assistants helpers using httr2
# Note: openai_req() is defined in oaii_grading_assistant.R via source() above
# -------------------

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
    role        = role,
    content     = content,
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
#' assistant to process the thread's messages. The run is configured with
#' \code{response_format = list(type = "json_object")} to enforce valid JSON
#' output at the API level, allowing the reply to be parsed directly with
#' \code{jsonlite::fromJSON()} without defensive multi-schema handling.
#' Runs are asynchronous; use \code{wait_run_complete()} to poll until the
#' run reaches a terminal state.
#'
#' @param thread_id Character. The ID of the thread to run the assistant on,
#'   as returned by \code{create_thread()$id}.
#' @param assistant_id Character. The ID of the assistant to use, as stored in
#'   \code{assistant_config.json} by \code{oaii_grading_assistant.R}.
#'
#' @returns A named list representing the run object, including at minimum
#'   \code{$id} (the run ID) and \code{$status} (initially \code{"queued"} or
#'   \code{"in_progress"}). The run is configured with \code{temperature = 0.1}
#'   to match the Python pipeline and minimise grading variability.
#'
#' @examples
start_run <- function(thread_id, assistant_id) {
  body <- list(
    assistant_id    = assistant_id,
    response_format = list(type = "json_object"),
    temperature     = 0.1
  )
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
    s   <- run$status
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
      parts   <- character()
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

#' Safely coerce a value to a length-1 numeric
#'
#' A defensive wrapper around \code{as.numeric()} that returns \code{NA_real_}
#' whenever the input is \code{NULL}, a zero-length vector, or non-numeric.
#' Prevents \code{as.numeric(NULL)} from silently producing \code{numeric(0)},
#' which would cause \code{as.data.frame()} to fail with
#' \emph{"arguments imply differing number of rows: 1, 0"}.
#'
#' @param x A scalar value (numeric, integer, character, or \code{NULL}).
#'
#' @returns A length-1 double: the numeric value of \code{x}, or
#'   \code{NA_real_} if \code{x} is \code{NULL}, empty, or non-numeric.
safe_num <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_real_)
  v <- suppressWarnings(as.numeric(x[[1]]))
  if (is.na(v)) NA_real_ else v
}

# -------------------
# Main grading loop
# -------------------

#' Grade all student submissions and write results to CSV
#'
#' Walks the \code{assignment/} directory for student submission subfolders,
#' grades each student's \code{.qmd} file using the pre-configured OpenAI
#' Assistant, and writes results to a UTF-8 BOM CSV file for Excel
#' compatibility. For each student a new thread is created, the submission is
#' sent with rubric, solution, and starter file attachments, and the assistant
#' run is polled until completion. Valid JSON output is guaranteed by the
#' \code{response_format} enforced in \code{start_run()}, so the reply is
#' parsed with a direct \code{jsonlite::fromJSON()} call.
#'
#' Reads \code{assistant_id}, \code{rubric_file_id}, \code{solution_file_id},
#' and \code{starter_file_id} from \code{CONFIG_JSON}. Submission files are
#' expected at \code{assignment/lab-{LAB_NUMBER}_<id>/lab-{LAB_NUMBER}.qmd}.
#' Output is written to \code{output_csv}.
#'
#' @returns Called for its side effects. Returns \code{NULL} invisibly.
#'   Writes \code{r_lab\{LAB_NUMBER\}_grades.csv} to \code{directory_path} and
#'   emits progress messages via \code{message()}.
#'
#' @seealso \code{\link{create_thread}}, \code{\link{add_message}},
#'   \code{\link{start_run}}, \code{\link{wait_run_complete}},
#'   \code{\link{latest_assistant_text}}
main <- function() {

  # Load assistant and file IDs from config
  cfg              <- jsonlite::fromJSON(CONFIG_JSON, simplifyVector = TRUE)
  assistant_id     <- cfg[["assistant_id"]]
  rubric_file_id   <- cfg[["rubric_file_id"]]
  solution_file_id <- cfg[["solution_file_id"]]
  starter_file_id  <- cfg[["starter_file_id"]]

  Q_COUNT <- 10L
  Q_COLS  <- paste0("Q", 1:Q_COUNT)
  records <- list()

  # immediate subfolders only
  all_entries <- list.dirs(directory_path, full.names = TRUE, recursive = FALSE)
  subdirs     <- all_entries[file.info(all_entries)$isdir %in% TRUE]

  for (folder in subdirs) { #folder = subdirs[20]
    student_file <- file.path(folder, stringr::str_glue("lab-{LAB_NUMBER}.qmd"))
    if (!file.exists(student_file)) {
      message("Skipping ", basename(folder), stringr::str_glue(". Missing lab-{LAB_NUMBER}.qmd"))
      next
    }

    student_name <- stringr::str_remove(
      basename(folder),
      stringr::str_glue("(?i)^lab-{LAB_NUMBER}_")
    )
    student_text <- readChar(student_file, nchars = file.info(student_file)$size, useBytes = TRUE)

    prompt <- paste0(
      "Grade the following student submission using the uploaded rubric, ",
      "reference solution, and starter file. Follow the rubric strictly.\n\n",
      "Return a JSON object with this exact schema:\n",
      "{\n",
      "  \"questions\": {\n",
      "    \"Q1\": {\"grade\": <number>, \"feedback\": \"<text>\"},\n",
      "    ...\n",
      "    \"Q10\": {\"grade\": <number>, \"feedback\": \"<text>\"}\n",
      "  },\n",
      "  \"total\": <number>,\n",
      "  \"overall_comment\": \"<2-3 sentence summary>\"\n",
      "}\n\n",
      "--- STUDENT SUBMISSION START ---\n",
      student_text,
      "\n--- STUDENT SUBMISSION END ---\n"
    )

    # Create a new isolated thread for this student
    thread <- create_thread()

    # Attach rubric, solution, and starter for file_search
    attachments <- list(
      list(file_id = rubric_file_id,   tools = list(list(type = "file_search"))),
      list(file_id = solution_file_id, tools = list(list(type = "file_search"))),
      list(file_id = starter_file_id,  tools = list(list(type = "file_search")))
    )
    invisible(add_message(thread_id = thread$id, content = prompt,
                          role = "user", attachments = attachments))

    # Start run — response_format = json_object enforced inside start_run()
    run       <- start_run(thread_id = thread$id, assistant_id = assistant_id)
    final_run <- wait_run_complete(thread_id = thread$id, run_id = run$id,
                                   sleep_seconds = 0.7, timeout_seconds = 180)

    if (!identical(final_run$status, "completed")) {
      row <- c(
        list(Student = student_name),
        stats::setNames(rep(list(NA_real_), Q_COUNT), Q_COLS),
        list(Total = NA_real_, Comments = sprintf("Run status: %s", final_run$status))
      )
      records[[length(records) + 1L]] <- row
      message("Run not completed for ", student_name, ". Status: ", final_run$status)
      next
    }

    # Parse reply — valid JSON is guaranteed by response_format
    reply_text <- latest_assistant_text(thread$id)
    payload    <- jsonlite::fromJSON(reply_text, simplifyVector = FALSE)
    questions  <- payload[["questions"]]

    row <- list(Student = student_name)
    for (i in seq_len(Q_COUNT)) {
      q        <- paste0("Q", i)
      row[[q]] <- safe_num(questions[[q]][["grade"]])
    }
    row[["Total"]]    <- safe_num(payload[["total"]])
    row[["Comments"]] <- paste(
      vapply(paste0("Q", seq_len(Q_COUNT)), function(q) {
        fb <- questions[[q]][["feedback"]]
        if (!is.null(fb) && nzchar(trimws(as.character(fb)))) {
          sprintf("%s: %s", q, fb)
        } else {
          ""
        }
      }, character(1L)),
      collapse = " | "
    )

    records[[length(records) + 1L]] <- row
    message("Collected ", student_name)
  }

  # Build data frame and save
  if (length(records)) {
    col_order <- c("Student", Q_COLS, "Total", "Comments")
    df <- do.call(rbind.data.frame, lapply(records, function(x) {
      miss <- setdiff(col_order, names(x))
      if (length(miss)) for (m in miss) x[[m]] <- NA
      x <- x[col_order]
      x <- lapply(x, function(v) if (is.null(v) || length(v) == 0) NA else v)
      as.data.frame(x, stringsAsFactors = FALSE)
    }))
    # write CSV with BOM for Excel
    readr::write_excel_csv(df, output_csv, na = "")
    message("Saved grades table to ", output_csv)
    utils::head(df, n = min(10L, nrow(df)))
  } else {
    message("No records to write.")
  }
}

# run
if (identical(environment(), globalenv())) {
  tryCatch(main(), error = function(e) {
    message("Error: ", conditionMessage(e))
    quit(save = "no", status = 1)
  })
}
