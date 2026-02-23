# ======================================================================
# Grading Assistant runner in R
# - Loads .env
# - Reads assistant_config.json for IDs
# - Walks student folders
# - Creates a thread per student, attaches rubric, solution, starter
# - Runs the assistant, polls, parses JSON reply into a table
# - Writes a UTF-8 BOM CSV for Excel compatibility
# ======================================================================

# ---- deps ----
dotenv::load_dot_env()   # expects OPENAI_API_KEY in .env
# install.packages(c("fs","jsonlite","stringr","readr","httr2"))

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
# Assistants v2 helpers using httr2
# -------------------
openai_req <- function(path) {
  key <- Sys.getenv("OPENAI_API_KEY", unset = NA_character_)
  if (is.na(key) || !nzchar(key)) stop("OPENAI_API_KEY is not set.")
  httr2::request(paste0("https://api.openai.com/v1", path)) |>
    httr2::req_headers(
      "Authorization" = paste("Bearer", key),
      "OpenAI-Beta"   = "assistants=v2"
    )
}

create_thread_v2 <- function() {
  resp <- openai_req("/threads") |>
    httr2::req_headers("Content-Type" = "application/json") |>
    httr2::req_body_json(list(), auto_unbox = TRUE) |>
    httr2::req_perform()
  httr2::resp_check_status(resp)
  httr2::resp_body_json(resp, simplifyVector = TRUE)
}

add_message_v2 <- function(thread_id, content, role = "user", attachments = NULL) {
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

start_run_v2 <- function(thread_id, assistant_id) {
  body <- list(assistant_id = assistant_id)
  resp <- openai_req(sprintf("/threads/%s/runs", thread_id)) |>
    httr2::req_headers("Content-Type" = "application/json") |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_perform()
  httr2::resp_check_status(resp)
  httr2::resp_body_json(resp, simplifyVector = TRUE)
}

retrieve_run_v2 <- function(thread_id, run_id) {
  resp <- openai_req(sprintf("/threads/%s/runs/%s", thread_id, run_id)) |>
    httr2::req_perform()
  httr2::resp_check_status(resp)
  httr2::resp_body_json(resp, simplifyVector = TRUE)
}

list_messages_v2 <- function(thread_id, order = "desc", limit = 15) {
  resp <- openai_req(sprintf("/threads/%s/messages?order=%s&limit=%d", thread_id, order, limit)) |>
    httr2::req_perform()
  httr2::resp_check_status(resp)
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}

wait_run_complete_v2 <- function(thread_id, run_id, sleep_seconds = 0.7, timeout_seconds = 180) {
  t0 <- Sys.time()
  repeat {
    run <- retrieve_run_v2(thread_id, run_id)
    s <- run$status
    if (s %in% c("completed", "failed", "cancelled", "expired")) return(run)
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > timeout_seconds) {
      return(run)
    }
    Sys.sleep(sleep_seconds)
  }
}

latest_assistant_text <- function(thread_id) {
  msgs <- list_messages_v2(thread_id, order = "desc", limit = 15)
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

# extract_qnum <- function(key_or_value) {
#   if (is.null(key_or_value)) return(NA_integer_)
#   s <- trimws(as.character(key_or_value))
#   # patterns like Q1, q1, question_1, Question 1, 1
#   m <- regexpr("(?<!\\d)(?:q|question)?\\s*_?(\\d{1,2})(?!\\d)", s, perl = TRUE, ignore.case = TRUE)
#   if (m[1] > 0) {
#     n <- as.integer(regmatches(s, m)[1])
#     if (!is.na(n) && n >= 1L && n <= Q_COUNT) return(n)
#   }
#   if (grepl("^[0-9]+$", s)) {
#     n <- as.integer(s)
#     if (!is.na(n) && n >= 1L && n <= Q_COUNT) return(n)
#   }
#   NA_integer_
# }

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

coerce_float <- function(x) {
  v <- suppressWarnings(as.numeric(x))
  if (is.na(v)) return(NA_real_)
  v
}

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
    "Grade the following student submission for Regression Modeling Lab 3 using the uploaded rubric, ",
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
  thread <- create_thread_v2()

  # message with attachments for file_search
  attachments <- list(
    list(file_id = rubric_file_id,   tools = list(list(type = "file_search"))),
    list(file_id = solution_file_id, tools = list(list(type = "file_search"))),
    list(file_id = starter_file_id,  tools = list(list(type = "file_search")))
  )

  invisible(add_message_v2(thread_id = thread$id, content = prompt, role = "user", attachments = attachments))

  # run
  run <- start_run_v2(thread_id = thread$id, assistant_id = assistant_id)

  # poll with timeout
  final_run <- wait_run_complete_v2(thread_id = thread$id, run_id = run$id, sleep_seconds = 0.7, timeout_seconds = 180)

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