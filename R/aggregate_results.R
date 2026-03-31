# ======================================================================
# Aggregate reliability test results across Python and R pipelines
#
# For each student, reads the Python and R *_grades.csv reliability
# output files, computes per-column means, and writes a summary CSV
# with two rows per student (Python then R) separated by a blank row.
#
# Output columns: Pipeline, Student, N_Runs, Total, Q1-QN (detected from data)
#
# Usage:
#   source("R/aggregate_results.R")
# ======================================================================

# ---- config ----
LAB_NUMBER <- 9L

# ---- deps ----
if (!"librarian" %in% rownames(installed.packages())) install.packages("librarian")
librarian::shelf(readr, fs, stringr)
if (file.exists(".env")) dotenv::load_dot_env()

# ---- directories ----
r_dir        <- paste0(getwd(), "/R assignments")

base_lab_dir <- Sys.getenv("BASE_LAB_DIR", unset = NA_character_)
if (is.na(base_lab_dir) || !nzchar(base_lab_dir)) {
  stop("BASE_LAB_DIR environment variable is not set.")
}
python_dir   <- file.path(base_lab_dir, paste0("lab-", LAB_NUMBER))

output_csv   <- paste0(getwd(), "/assignment/comparison_summary.csv")

# ---- helpers ----

#' Detect question columns from a grades CSV
#'
#' Reads the header of a CSV and returns all column names matching
#' \code{^Q[0-9]+$}, sorted numerically. Used to derive \code{Q_COLS}
#' from the data rather than relying on a hardcoded count.
#'
#' @param csv_path Character. Path to any per-student grades CSV.
#'
#' @returns A character vector of column names such as
#'   \code{c("Q1", "Q2", ..., "QN")}, sorted by question number.
detect_q_cols <- function(csv_path) {
  cols <- names(readr::read_csv(csv_path, n_max = 0, show_col_types = FALSE))
  q    <- grep("^Q[0-9]+$", cols, value = TRUE)
  q[order(as.integer(sub("Q", "", q)))]
}

#' Compute column means from a reliability CSV and return a single-row data frame
#'
#' Reads a per-student grades CSV produced by \code{reliability_test.R} or
#' \code{reliability_test.py} and computes the mean of \code{Total} and each
#' \code{Q*} column across all runs. Returns \code{NULL} with a warning if
#' the file does not exist.
#'
#' @param csv_path Character. Path to the per-student grades CSV.
#' @param pipeline_label Character. Label for the \code{Pipeline} column,
#'   e.g. \code{"Python"} or \code{"R"}.
#' @param student_name Character. Label for the \code{Student} column.
#' @param q_cols Character vector of question column names to average,
#'   as returned by \code{detect_q_cols()}.
#'
#' @returns A one-row \code{data.frame} with columns \code{Pipeline},
#'   \code{Student}, \code{N_Runs}, \code{Total}, and the averaged
#'   question columns, or \code{NULL} if the file is missing.
compute_means <- function(csv_path, pipeline_label, student_name, q_cols) {
  if (!file.exists(csv_path)) {
    warning("Missing file: ", csv_path)
    return(NULL)
  }
  df      <- readr::read_csv(csv_path, show_col_types = FALSE)
  q_means <- stats::setNames(
    lapply(q_cols, function(q) mean(df[[q]], na.rm = TRUE)),
    q_cols
  )
  as.data.frame(
    c(list(Pipeline = pipeline_label,
           Student  = student_name,
           N_Runs   = nrow(df),
           Total    = mean(df$Total, na.rm = TRUE)),
      q_means),
    stringsAsFactors = FALSE
  )
}

# ---- main ----

#' Aggregate all per-student reliability CSVs into a single summary
#'
#' Scans \code{r_dir} for per-student grades CSVs matching
#' \code{lab-{LAB_NUMBER}_*_grades.csv}, detects question columns from the
#' first CSV found, finds the corresponding Python CSV in \code{python_dir},
#' computes means for both, and writes a summary CSV with a Python row then
#' an R row per student, separated by blank rows.
#'
#' @returns Called for its side effects. Writes \code{comparison_summary.csv}
#'   to \code{assignment/}.
main <- function() {
  r_csvs <- list.files(
    r_dir,
    pattern   = stringr::str_glue("^lab-{LAB_NUMBER}_.+_grades\\.csv$"),
    full.names = TRUE
  )

  if (length(r_csvs) == 0L) stop("No R reliability CSVs found in ", r_dir)

  # detect question columns from the first CSV
  q_cols    <- detect_q_cols(sort(r_csvs)[[1]])
  col_order <- c("Pipeline", "Student", "N_Runs", "Total", q_cols)
  message("Detected question columns: ", paste(q_cols, collapse = ", "))

  # blank separator row
  blank_row <- as.data.frame(
    stats::setNames(rep(list(NA), length(col_order)), col_order),
    stringsAsFactors = FALSE
  )

  all_rows <- list()

  for (r_csv in sort(r_csvs)) {
    fname        <- basename(r_csv)           # "lab-9_student_low_grades.csv"
    folder_name  <- stringr::str_remove(fname, "_grades\\.csv$")
    student_name <- stringr::str_remove(
      folder_name,
      stringr::str_glue("(?i)^lab-{LAB_NUMBER}_")
    )
    python_csv <- file.path(python_dir, fname)

    message("Aggregating: ", student_name)

    python_row <- compute_means(python_csv, "Python", student_name, q_cols)
    r_row      <- compute_means(r_csv,      "R",      student_name, q_cols)

    if (!is.null(python_row)) all_rows[[length(all_rows) + 1L]] <- python_row
    if (!is.null(r_row))      all_rows[[length(all_rows) + 1L]] <- r_row
    all_rows[[length(all_rows) + 1L]] <- blank_row
  }

  # drop trailing blank row
  if (length(all_rows) > 0L) all_rows[[length(all_rows)]] <- NULL

  df <- do.call(rbind.data.frame, all_rows)

  fs::dir_create(dirname(output_csv))
  readr::write_csv(df, output_csv, na = "")
  message("Saved summary to ", output_csv)
}

if (identical(environment(), globalenv())) {
  tryCatch(main(), error = function(e) {
    message("Error: ", conditionMessage(e))
    if (!interactive()) quit(save = "no", status = 1)
  })
}
