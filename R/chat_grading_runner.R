# ======================================================================
# Chat Completions grading runner (R)
# Mirrors the Python pipeline (Python/grade_student.py + batch_grade.py):
# - Passes rubric, solution, and starter inline with ephemeral caching
# - Single synchronous HTTP call per student (no threads / polling)
# - Uses gpt-5.1 at temperature 0.1, matching Python exactly
# - Writes UTF-8 CSV with separate Q*_feedback columns
# ======================================================================

# ---- deps ----
if (!"librarian" %in% rownames(installed.packages())) install.packages("librarian")
librarian::shelf(httr2, jsonlite, stringr, readr, fs)
if (file.exists(".env")) dotenv::load_dot_env()

# load shared utilities (safe_num)
source("./R/utils.R")

# ---- config ----
LAB_NUMBER  <- 9
MODEL       <- "gpt-5.1"
TEMPERATURE <- 0.1
Q_COUNT     <- 10L

# ---- paths ----
RUBRIC_PATH       <- stringr::str_glue("./R assignments/rubric_lab_{LAB_NUMBER}.json")
STARTER_PATH      <- stringr::str_glue("./R assignments/lab_{LAB_NUMBER}_starter.qmd")
SOLUTION_PATH     <- stringr::str_glue("./R assignments/lab_{LAB_NUMBER}_solutions.qmd")
INSTRUCTIONS_PATH <- "./Python/grader_instructions.txt"

directory_path <- paste0(getwd(), "/R assignments")
output_csv     <- stringr::str_glue("{directory_path}/r_chat_lab{LAB_NUMBER}_grades.csv")

Q_COLS          <- paste0("Q", seq_len(Q_COUNT))
Q_FEEDBACK_COLS <- paste0("Q", seq_len(Q_COUNT), "_feedback")
COL_ORDER       <- c("Student", "Total", "OverallComment", Q_COLS, Q_FEEDBACK_COLS)

# ---- helpers ----

#' Build an authenticated request to the Chat Completions endpoint
#'
#' Constructs an \code{httr2} request object targeting
#' \code{https://api.openai.com/v1/chat/completions}, pre-populated with a
#' Bearer token from the \code{OPENAI_API_KEY} environment variable. Unlike
#' \code{openai_req()} in \code{utils.R}, this function does not add the
#' \code{OpenAI-Beta} header, which is only required by the Assistants API.
#'
#' @returns An \code{httr2_request} object ready for a JSON body and
#'   \code{httr2::req_perform()}.
chat_req <- function() {
  key <- base::Sys.getenv("OPENAI_API_KEY", unset = NA_character_)
  if (base::is.na(key) || !base::nzchar(key)) stop("OPENAI_API_KEY is not set.")
  httr2::request("https://api.openai.com/v1/chat/completions") |>
    httr2::req_headers(
      "Authorization" = base::paste("Bearer", key),
      "Content-Type"  = "application/json"
    )
}

#' Build the system message from the shared grader instructions file
#'
#' Reads \code{Python/grader_instructions.txt} (shared with the Python
#' pipeline) and wraps its content in a \code{role = "system"} message dict.
#'
#' @returns A named list with elements \code{role} (\code{"system"}) and
#'   \code{content} (the instructions text).
#'
#' @seealso \code{\link{build_context_messages}}, \code{\link{grade_student}}
build_system_message <- function() {
  if (!fs::file_exists(INSTRUCTIONS_PATH)) stop("Missing file: ", INSTRUCTIONS_PATH)
  list(
    role    = "system",
    content = readr::read_file(INSTRUCTIONS_PATH)
  )
}

#' Build the three shared context messages with ephemeral prompt caching
#'
#' Loads the rubric JSON, starter \code{.qmd} template, and instructor
#' solution (resolved via \code{RUBRIC_PATH}, \code{STARTER_PATH}, and
#' \code{SOLUTION_PATH}) and wraps each in a user message tagged with
#' \code{cache_control = list(type = "ephemeral")}. This instructs the
#' OpenAI API to cache the key-value representation of this shared prefix
#' and reuse it across the student batch, reducing latency and token cost.
#' Mirrors \code{build_cached_context_messages()} in
#' \code{Python/grading_context.py}.
#'
#' @returns A list of three message dicts (rubric, starter, solution), each
#'   marked for ephemeral caching. Intended to be positioned after the system
#'   message and before the per-student user message.
#'
#' @seealso \code{\link{grade_student}}
build_context_messages <- function() {
  for (p in c(RUBRIC_PATH, STARTER_PATH, SOLUTION_PATH)) {
    if (!fs::file_exists(p)) stop("Missing file: ", p)
  }
  rubric_text   <- readr::read_file(RUBRIC_PATH)
  starter_text  <- readr::read_file(STARTER_PATH)
  solution_text <- readr::read_file(SOLUTION_PATH)

  list(
    list(
      role          = "user",
      cache_control = list(type = "ephemeral"),
      content       = list(list(
        type = "text",
        text = paste0("Rubric JSON for BSMM 8740 lab ", LAB_NUMBER, ":\n\n", rubric_text)
      ))
    ),
    list(
      role          = "user",
      cache_control = list(type = "ephemeral"),
      content       = list(list(
        type = "text",
        text = paste0("Starter .qmd template for lab ", LAB_NUMBER, ":\n\n", starter_text)
      ))
    ),
    list(
      role          = "user",
      cache_control = list(type = "ephemeral"),
      content       = list(list(
        type = "text",
        text = paste0("Solution .qmd for lab ", LAB_NUMBER, ":\n\n", solution_text)
      ))
    )
  )
}

#' Grade a single student \code{.qmd} submission via Chat Completions
#'
#' Assembles the full message list (system, three cached context messages,
#' student submission) and sends a single synchronous request to the Chat
#' Completions API with \code{response_format = json_object} and
#' \code{temperature = 0.1}. Mirrors \code{grade_student_qmd()} in
#' \code{Python/grade_student.py}.
#'
#' @param student_qmd_path Character or \code{fs::path}. Path to the
#'   student's \code{.qmd} file.
#'
#' @returns A named list parsed from the model's JSON response, containing
#'   \code{questions} (a named list of per-question \code{grade} and
#'   \code{feedback}), \code{total}, and \code{overall_comment}.
#'
#' @seealso \code{\link{build_system_message}},
#'   \code{\link{build_context_messages}}, \code{\link{main}}
grade_student <- function(student_qmd_path) {
  if (!fs::file_exists(student_qmd_path)) stop("Missing file: ", student_qmd_path)
  student_text <- readr::read_file(student_qmd_path)

  student_msg <- list(
    role    = "user",
    content = list(list(
      type = "text",
      text = paste0(
        "Here is a student's lab ", LAB_NUMBER, " .qmd file. ",
        "Using the rubric and templates already given above, ",
        "grade this file and return JSON only.\n\n",
        "=== STUDENT_QMD_START ===\n",
        student_text, "\n",
        "=== STUDENT_QMD_END ==="
      )
    ))
  )

  messages <- c(
    list(build_system_message()),
    build_context_messages(),
    list(student_msg)
  )

  body <- list(
    model           = MODEL,
    messages        = messages,
    response_format = list(type = "json_object"),
    temperature     = TEMPERATURE
  )

  resp <- chat_req() |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_perform()
  httr2::resp_check_status(resp)

  result <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  jsonlite::fromJSON(result$choices[[1]]$message$content,
                     simplifyVector = FALSE)
}

# ---- main ----

#' Grade all student submissions and write results to CSV
#'
#' Walks the \code{assignment/} directory for student submission subfolders,
#' grades each student's \code{.qmd} file using the Chat Completions API, and
#' writes results to a UTF-8 CSV. Per-student exceptions are caught and
#' recorded as error rows so a single failure does not abort the batch.
#' Mirrors \code{main()} in \code{Python/batch_grade.py}.
#'
#' @returns Called for its side effects. Returns \code{NULL} invisibly.
#'   Writes \code{r_chat_lab\{LAB_NUMBER\}_grades.csv} to
#'   \code{directory_path}.
#'
#' @seealso \code{\link{grade_student}}
main <- function() {
  all_entries <- list.dirs(directory_path, full.names = TRUE, recursive = FALSE)
  subdirs     <- all_entries[file.info(all_entries)$isdir %in% TRUE]

  records <- list()

  for (folder in subdirs) {
    student_file <- file.path(folder,
                              stringr::str_glue("lab-{LAB_NUMBER}.qmd"))
    if (!file.exists(student_file)) {
      message("Skipping ", basename(folder), ". Missing lab-",
              LAB_NUMBER, ".qmd")
      next
    }

    student_name <- stringr::str_remove(
      basename(folder),
      stringr::str_glue("(?i)^lab-{LAB_NUMBER}_")
    )
    message("Grading ", student_name, " ...")

    row <- tryCatch({
      result    <- grade_student(student_file)
      questions <- result[["questions"]]

      r <- list(
        Student        = student_name,
        Total          = safe_num(result[["total"]]),
        OverallComment = as.character(
          if (!is.null(result[["overall_comment"]])) result[["overall_comment"]] else ""
        )
      )
      for (q in Q_COLS) {
        qinfo              <- questions[[q]]
        r[[q]]             <- safe_num(qinfo[["grade"]])
        r[[paste0(q, "_feedback")]] <- as.character(
          if (!is.null(qinfo[["feedback"]])) qinfo[["feedback"]] else ""
        )
      }
      r

    }, error = function(e) {
      message("  ERROR grading ", student_name, ": ", conditionMessage(e))
      r <- list(Student        = student_name,
                Total          = NA_real_,
                OverallComment = paste("Error:", conditionMessage(e)))
      for (q in Q_COLS) {
        r[[q]]                      <- NA_real_
        r[[paste0(q, "_feedback")]] <- NA_character_
      }
      r
    })

    records[[length(records) + 1L]] <- row
  }

  if (length(records)) {
    df <- do.call(rbind.data.frame, lapply(records, function(x) {
      miss <- setdiff(COL_ORDER, names(x))
      for (m in miss) x[[m]] <- NA
      x <- x[COL_ORDER]
      x <- lapply(x, function(v) if (is.null(v) || length(v) == 0) NA else v)
      as.data.frame(x, stringsAsFactors = FALSE)
    }))
    readr::write_csv(df, output_csv, na = "")
    message("Saved grades to ", output_csv)
    utils::head(df, n = min(10L, nrow(df)))
  } else {
    message("No records to write.")
  }
}

# run
if (identical(environment(), globalenv())) {
  tryCatch(main(), error = function(e) {
    message("Error: ", conditionMessage(e))
    if (!interactive()) quit(save = "no", status = 1)
  })
}
