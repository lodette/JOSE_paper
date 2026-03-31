# ======================================================================
# Reliability test for the Chat Completions grading pipeline
#
# Runs grade_student() N times for every student submission and writes
# one CSV per student containing N rows — one per run. This allows
# variability in LLM grading to be measured across repeated calls with
# identical inputs.
#
# Output files are written beside the student submission folders:
#   {directory_path}/{folder_name}_grades.csv
# e.g. "R assignments/lab-9_student_high_grades.csv"
#
# Usage:
#   N <- 10          # set number of runs per invocation (default 10)
#   source("R/reliability_test.R")
#
# Re-running appends to existing CSVs with continuous run numbering,
# so 10 runs of N=10 accumulate to 100 rows per student.
# ======================================================================

# ---- config ----
if (!exists("N"))          N          <- 10L   # override before sourcing
if (!exists("LAB_NUMBER")) LAB_NUMBER <- 9L

# ---- deps ----
if (!"librarian" %in% rownames(installed.packages())) install.packages("librarian")
librarian::shelf(httr2, jsonlite, stringr, readr, fs)
if (file.exists(".env")) dotenv::load_dot_env()

# load shared utilities (safe_num)
source("./R/utils.R")

# ---- load grading functions without triggering main() ----
# sys.source() into a child env prevents the globalenv() guard in
# chat_grading_runner.R from firing, so main() is never called.
runner_env            <- new.env(parent = globalenv())
runner_env$LAB_NUMBER <- LAB_NUMBER
sys.source("R/chat_grading_runner.R", envir = runner_env)

grade_student <- runner_env$grade_student

# ---- paths and column layout ----
directory_path  <- runner_env$directory_path

Q_COUNT         <- runner_env$Q_COUNT
Q_COLS          <- paste0("Q", seq_len(Q_COUNT))
Q_FEEDBACK_COLS <- paste0("Q", seq_len(Q_COUNT), "_feedback")
COL_ORDER       <- c("Run", "Total", "OverallComment", Q_COLS, Q_FEEDBACK_COLS)

# ---- helpers ----

#' Grade one student N times and return a data frame with one row per run
#'
#' Calls \code{grade_student()} \code{n_runs} times for the same submission
#' file, recording the run index alongside all grade and feedback fields.
#' Per-run exceptions are caught and recorded as error rows so a single API
#' failure does not abort the student's batch.
#'
#' @param student_file Character. Path to the student's \code{.qmd} file.
#' @param student_name Character. Display name used in progress messages.
#' @param n_runs Integer. Number of grading runs to perform.
#' @param run_offset Integer. Value added to each run index so that run
#'   numbers continue from the last row of an existing CSV rather than
#'   restarting at 1. Defaults to \code{0L}.
#'
#' @returns A \code{data.frame} with \code{n_runs} rows and columns
#'   \code{Run}, \code{Total}, \code{OverallComment},
#'   \code{Q1}–\code{Q{Q_COUNT}}, and
#'   \code{Q1_feedback}–\code{Q{Q_COUNT}_feedback}.
grade_n_times <- function(student_file, student_name, n_runs, run_offset = 0L) {
  records <- vector("list", n_runs)

  for (i in seq_len(n_runs)) {
    run_number <- run_offset + i
    message("  Run ", run_number, " (", i, "/", n_runs, ") ...")

    records[[i]] <- tryCatch({
      result    <- grade_student(student_file)
      questions <- result[["questions"]]

      r <- list(
        Run            = run_number,
        Total          = safe_num(result[["total"]]),
        OverallComment = as.character(
          if (!is.null(result[["overall_comment"]])) result[["overall_comment"]] else ""
        )
      )
      for (q in Q_COLS) {
        qinfo    <- questions[[q]]
        r[[q]]   <- safe_num(qinfo[["grade"]])
        r[[paste0(q, "_feedback")]] <- as.character(
          if (!is.null(qinfo[["feedback"]])) qinfo[["feedback"]] else ""
        )
      }
      r

    }, error = function(e) {
      message("    ERROR on run ", run_number, ": ", conditionMessage(e))
      r <- list(Run            = run_number,
                Total          = NA_real_,
                OverallComment = paste("Error:", conditionMessage(e)))
      for (q in Q_COLS) {
        r[[q]]                      <- NA_real_
        r[[paste0(q, "_feedback")]] <- NA_character_
      }
      r
    })
  }

  do.call(rbind.data.frame, lapply(records, function(x) {
    miss <- setdiff(COL_ORDER, names(x))
    for (m in miss) x[[m]] <- NA
    x <- x[COL_ORDER]
    x <- lapply(x, function(v) if (is.null(v) || length(v) == 0) NA else v)
    as.data.frame(x, stringsAsFactors = FALSE)
  }))
}

# ---- main ----

#' Run the reliability test across all student submissions
#'
#' Walks \code{directory_path} for student submission subfolders, grades
#' each student \code{N} times via \code{grade_n_times()}, and writes one
#' CSV per student beside the submission folder:
#' \code{{directory_path}/{folder_name}_grades.csv}.
#'
#' If a CSV already exists for a student, the new runs are appended with
#' run numbers continuing from the last recorded run. This allows a total
#' of 100 runs to be accumulated across 10 separate invocations of 10,
#' for example.
#'
#' @returns Called for its side effects. Returns \code{NULL} invisibly.
main <- function() {
  all_entries <- list.dirs(directory_path, full.names = TRUE, recursive = FALSE)
  subdirs     <- all_entries[file.info(all_entries)$isdir %in% TRUE]

  if (length(subdirs) == 0L) {
    stop("No student subfolders found in ", directory_path)
  }

  message("Starting reliability test: ", N, " runs x ",
          length(subdirs), " students\n")

  for (folder in subdirs) {
    student_file <- file.path(folder,
                              stringr::str_glue("lab-{LAB_NUMBER}.qmd"))
    if (!file.exists(student_file)) {
      message("Skipping ", basename(folder), " — no lab-", LAB_NUMBER, ".qmd")
      next
    }

    folder_name  <- basename(folder)       # e.g. "lab-9_student_high"
    student_name <- stringr::str_remove(
      folder_name,
      stringr::str_glue("(?i)^lab-{LAB_NUMBER}_")
    )
    output_csv   <- file.path(directory_path,
                              paste0(folder_name, "_grades.csv"))

    # Detect existing runs so new ones continue from the last run number
    if (file.exists(output_csv)) {
      existing   <- readr::read_csv(output_csv, show_col_types = FALSE)
      run_offset <- max(existing$Run, na.rm = TRUE)
      message("Grading ", student_name, " (runs ", run_offset + 1L,
              "–", run_offset + N, ") ...")
    } else {
      run_offset <- 0L
      message("Grading ", student_name, " (runs 1–", N, ") ...")
    }

    df <- grade_n_times(student_file, student_name, N, run_offset)

    if (run_offset > 0L) {
      readr::write_csv(df, output_csv, na = "", append = TRUE,
                       col_names = FALSE)
    } else {
      readr::write_csv(df, output_csv, na = "")
    }
    message("  Saved: ", output_csv, "\n")
  }

  message("Reliability test complete.")
}

# run
if (identical(environment(), globalenv())) {
  tryCatch(main(), error = function(e) {
    message("Error: ", conditionMessage(e))
    if (!interactive()) quit(save = "no", status = 1)
  })
}
