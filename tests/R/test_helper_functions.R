# ===========================================================================
# Unit tests for R/oaii_grading_assistant.R helper functions
#
# Strategy:
#   - Load functions by sourcing into a dedicated environment so the
#     `if (identical(environment(), globalenv())) { main() }` guard
#     never fires, preventing any real API calls or Quarto renders.
#   - Test only the defensive (non-API) logic: file-existence checks and
#     missing-key guards.
#   - Syntax tests for both R scripts are included as a smoke check.
# ===========================================================================

library(testthat)
library(withr)

# ---------------------------------------------------------------------------
# Source helper functions into an isolated environment
# ---------------------------------------------------------------------------

LAB_NUMBER <- 9L   # needed by oaii_grading_assistant.R's module-level code
Sys.setenv(OPENAI_API_KEY = "sk-test-dummy-key-for-ci")

# ---------------------------------------------------------------------------
# Resolve project root robustly.
# testthat::test_dir() changes the working directory to the test folder
# (tests/R/) before executing each file, so relative paths like "R/..."
# break.  We detect which situation we are in by checking whether the R/
# directory is visible from the current working directory; if not, we
# navigate two levels up (tests/R -> tests -> project root).
# ---------------------------------------------------------------------------
proj_root <- if (file.exists("R/oaii_grading_assistant.R")) {
  normalizePath(".")
} else {
  normalizePath(file.path(getwd(), "../.."))
}

fns_env <- new.env(parent = globalenv())
fns_env$LAB_NUMBER <- LAB_NUMBER
sys.source(file.path(proj_root, "R", "oaii_grading_assistant.R"), envir = fns_env)

qmd_to_temp_md        <- fns_env$qmd_to_temp_md
upload_for_assistants <- fns_env$upload_for_assistants
openai_req            <- fns_env$openai_req

# ---------------------------------------------------------------------------
# Syntax checks
# ---------------------------------------------------------------------------

test_that("oaii_grading_assistant.R parses without error", {
  expect_no_error(
    parse(file = file.path(proj_root, "R", "oaii_grading_assistant.R"))
  )
})

test_that("oaii_grading_assistant_runner.R parses without error", {
  expect_no_error(
    parse(file = file.path(proj_root, "R", "oaii_grading_assistant_runner.R"))
  )
})

# ---------------------------------------------------------------------------
# qmd_to_temp_md: missing-file guard
# ---------------------------------------------------------------------------

test_that("qmd_to_temp_md raises error for a missing file", {
  expect_error(
    qmd_to_temp_md("/nonexistent/path/missing.qmd"),
    "Missing file"
  )
})

# ---------------------------------------------------------------------------
# upload_for_assistants: missing-file guard
# ---------------------------------------------------------------------------

test_that("upload_for_assistants raises error for a missing file", {
  expect_error(
    upload_for_assistants("/nonexistent/file.txt", api_key = "dummy"),
    "Missing file"
  )
})

# ---------------------------------------------------------------------------
# openai_req: missing / empty API key guard
# ---------------------------------------------------------------------------

test_that("openai_req raises error when OPENAI_API_KEY is unset", {
  withr::with_envvar(c(OPENAI_API_KEY = NA_character_), {
    expect_error(openai_req("/assistants"), "OPENAI_API_KEY is not set")
  })
})

test_that("openai_req raises error when OPENAI_API_KEY is empty string", {
  withr::with_envvar(c(OPENAI_API_KEY = ""), {
    expect_error(openai_req("/assistants"), "OPENAI_API_KEY is not set")
  })
})

test_that("openai_req returns an httr2_request with a valid key", {
  req <- openai_req("/assistants")
  expect_s3_class(req, "httr2_request")
})
