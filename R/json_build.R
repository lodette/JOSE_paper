# ======================================================================
# Rubric JSON generator
#
# Uses the ellmer package to call the Anthropic (Claude) API and
# generate a grading rubric JSON for a given lab. The model is provided
# the instructor solution and the rubric schema as context and asked to
# produce a fully-populated rubric conforming to that schema.
#
# The output is validated as well-formed JSON and checked against
# rubric_schema.json before being written to assignment/.
#
# Usage:
#   LAB_NUMBER <- 4          # set lab number (default 9)
#   source("R/json_build.R")
#
# Output: assignment/rubric_lab_{LAB_NUMBER}.json
# ======================================================================

# ---- config ----
if (!exists("LAB_NUMBER")) LAB_NUMBER <- 9L
if (!exists("OVERWRITE"))  OVERWRITE  <- FALSE

# ---- deps ----
if (!"librarian" %in% rownames(installed.packages())) install.packages("librarian")
librarian::shelf(ellmer, readr, stringr, fs, jsonlite, jsonvalidate)
if (file.exists(".env")) dotenv::load_dot_env()

# ---- paths ----
SOLUTION_PATH     <- stringr::str_glue("./R assignments/lab_{LAB_NUMBER}_solutions.qmd")
SCHEMA_PATH       <- "./assignment/rubric_schema.json"
INSTRUCTIONS_PATH <- "./python/rubric_instructions.txt"
OUTPUT_PATH       <- stringr::str_glue("./assignment/rubric_lab_{LAB_NUMBER}.json")

# ---- helpers ----

#' Interpolate the rubric-generation prompt from the instructions template
#'
#' Reads \code{python/rubric_instructions.txt}, which contains
#' \code{\{\{solution_txt\}\}} and \code{\{\{schema_txt\}\}} as
#' \code{ellmer::interpolate()} placeholders, and returns the fully
#' populated prompt string ready to be sent to the model.
#'
#' @param solution_txt Character. Full text of the instructor solution
#'   \code{.qmd} file. Substituted into the \code{\{\{solution_txt\}\}}
#'   placeholder.
#' @param schema_txt Character. Full text of \code{rubric_schema.json}.
#'   Substituted into the \code{\{\{schema_txt\}\}} placeholder.
#'
#' @returns An \code{ellmer} interpolated prompt object ready to be
#'   passed to \code{this_chat$chat()}.
build_prompt <- function(solution_txt, schema_txt) {
  if (!fs::file_exists(INSTRUCTIONS_PATH)) stop("Missing file: ", INSTRUCTIONS_PATH)
  instructions_txt <- readr::read_file(INSTRUCTIONS_PATH)
  ellmer::interpolate(instructions_txt)
}

#' Validate a JSON string as well-formed and schema-conformant
#'
#' First checks that \code{json_str} is parseable JSON using
#' \code{jsonlite::validate()}. If valid, checks conformance against
#' \code{rubric_schema.json} using \code{jsonvalidate::json_validate()}.
#' Stops on malformed JSON; warns (but does not stop) on schema
#' violations so the file is still written for inspection.
#'
#' @param json_str Character. The JSON string to validate.
#' @param schema_path Character. Path to the JSON Schema file.
#'
#' @returns Invisibly returns \code{TRUE} if both checks pass,
#'   \code{FALSE} if the schema check fails.
validate_rubric <- function(json_str, schema_path) {
  if (!jsonlite::validate(json_str)) {
    stop("Model output is not valid JSON.")
  }
  message("  JSON structure: OK")

  schema_result <- jsonvalidate::json_validate(
    json_str, schema_path,
    verbose = TRUE, greedy = TRUE
  )
  if (!isTRUE(schema_result)) {
    warning("Output is valid JSON but does not fully conform to ",
            "rubric_schema.json — review before use.")
    message("  Schema conformance: WARNING (see above)")
  } else {
    message("  Schema conformance: OK")
  }
  invisible(isTRUE(schema_result))
}

# ---- main ----

#' Generate and save a rubric JSON for the configured lab
#'
#' Reads the instructor solution and rubric schema, builds a prompt,
#' calls the Anthropic API via \code{ellmer}, validates the response,
#' pretty-prints it, and writes it to
#' \code{assignment/rubric_lab\{LAB_NUMBER\}.json}.
#'
#' @returns Called for its side effects. Returns \code{NULL} invisibly.
#'   Writes \code{assignment/rubric_lab\{LAB_NUMBER\}.json}.
#'
#' @seealso \code{\link{build_prompt}}, \code{\link{validate_rubric}}
main <- function() {

  # ---- check files ----
  for (p in c(SOLUTION_PATH, SCHEMA_PATH, INSTRUCTIONS_PATH)) {
    if (!fs::file_exists(p)) stop("Missing file: ", p)
  }

  # ---- read files ----
  solution_txt <- readr::read_file(SOLUTION_PATH)
  schema_txt   <- readr::read_file(SCHEMA_PATH)

  # ---- overwrite guard ----
  if (fs::file_exists(OUTPUT_PATH) && !OVERWRITE) {
    stop(OUTPUT_PATH, " already exists. ",
         "Set OVERWRITE <- TRUE before sourcing to replace it.")
  }

  # ---- build client ----
  ant_key <- Sys.getenv("ANT_API_KEY", unset = NA_character_)
  if (is.na(ant_key) || !nzchar(ant_key)) stop("ANT_API_KEY is not set.")

  this_chat <- ellmer::chat_anthropic(api_key = ant_key)$clone()$set_turns(list())

  # ---- call API ----
  # build_prompt() reads rubric_instructions.txt and substitutes
  # {{solution_txt}} and {{schema_txt}} via ellmer::interpolate()
  message("Generating rubric for lab ", LAB_NUMBER, " ...")

  raw_result <- tryCatch(
    this_chat$chat(build_prompt(solution_txt, schema_txt), echo = "none"),
    error = function(e) stop("API call failed: ", conditionMessage(e))
  )

  # ---- validate ----
  message("Validating output ...")
  validate_rubric(raw_result, SCHEMA_PATH)

  # ---- pretty-print and write ----
  parsed <- jsonlite::fromJSON(raw_result, simplifyVector = FALSE)
  pretty <- jsonlite::toJSON(parsed, pretty = TRUE, auto_unbox = TRUE)

  fs::dir_create(dirname(OUTPUT_PATH))
  readr::write_file(pretty, OUTPUT_PATH)
  message("Rubric written to ", OUTPUT_PATH)
}

# run
if (identical(environment(), globalenv())) {
  tryCatch(main(), error = function(e) {
    message("Error: ", conditionMessage(e))
    if (!interactive()) quit(save = "no", status = 1)
  })
}
