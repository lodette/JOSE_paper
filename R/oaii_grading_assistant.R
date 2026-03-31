# ======================================================================
# Grading Assistant (R with oaii Assistants API)
# - Renders solution.qmd to GitHub Flavored Markdown
# - Uploads rubric, solution, starter as assistant files
# - Creates an Assistant with file_search tool
# - Saves IDs to assistant_config.json
# ======================================================================

# Packages
# install.packages("oaii")   # if needed

# ---- config ----
MODEL <- "gpt-4.1"

# ---- paths ----
RUBRIC_PATH  <- stringr::str_glue("./R assignments/rubric_lab_{LAB_NUMBER}.json")
SOLUTION_QMD <- stringr::str_glue("./R assignments/lab_{LAB_NUMBER}_solutions.qmd")
STARTER_FILE <- stringr::str_glue("./R assignments/lab_{LAB_NUMBER}_starter.qmd")
CONFIG_JSON  <- "./R assignments/assistant_config.json"

#' Render a Quarto document to GitHub Flavored Markdown in a temporary file
#'
#' Renders a \code{.qmd} file to GitHub Flavored Markdown (\code{gfm}) using
#' \code{quarto::quarto_render()}, placing the initial output beside the source
#' file, then immediately moving it to a session-scoped temporary file. This
#' avoids leaving rendered artefacts in the source directory and produces a
#' path that can be safely passed to \code{upload_for_assistants()}.
#'
#' @param qmd_path Character. Path to the Quarto source file (\code{.qmd}) to
#'   render. The file must exist; an error is raised if it does not.
#'
#' @returns Character. The path to the temporary \code{.md} file containing the
#'   rendered GitHub Flavored Markdown output.
#'
#' @seealso \code{\link{upload_for_assistants}}, \code{\link{main}}
# ---- helper: render .qmd to .md beside the input, then move to temp ----
qmd_to_temp_md <- function(qmd_path) {
  if (!fs::file_exists(qmd_path)) stop("Missing file. ", qmd_path, " not found.")

  out_dir  <- fs::path_dir(qmd_path)
  out_file <- fs::path(out_dir, "solution.md")

  quarto::quarto_render(
    input         = qmd_path,
    output_file   = "solution.md",   # basename only
    output_format = "gfm"
  )

  tmp_md <- fs::file_temp(ext = "md")
  fs::file_move(out_file, tmp_md)
  tmp_md
}

#' Upload a file to OpenAI for use with the Assistants API
#'
#' Wraps \code{oaii::files_upload_request()} to upload a local file to the
#' OpenAI Files endpoint with \code{purpose = "assistants"}. The returned file
#' object contains the \code{$id} needed to attach the file to an assistant or
#' thread message. Typically called once per grading session for the rubric,
#' rendered solution, and starter template.
#'
#' @param path Character. Path to the local file to upload. The file must
#'   exist; an error is raised if it does not.
#' @param api_key Character. A valid OpenAI API key. Normally obtained via
#'   \code{Sys.getenv("OPENAI_API_KEY")}.
#'
#' @returns A named list representing the uploaded file object as returned by
#'   the OpenAI Files API, including at minimum \code{$id} (the file ID string
#'   used in subsequent Assistants API calls).
#'
#' @seealso \code{\link{main}}, \code{\link{create_assistant_v2}}
# ---- helper: upload a file for Assistants ----
upload_for_assistants <- function(path, api_key) {
  if (!fs::file_exists(path)) stop("Missing file. ", path, " not found.")
  res <- oaii::files_upload_request(
    file    = path
    , purpose = "assistants"
    , api_key = api_key
  )
  res
}

# ---- utils ----
# openai_req() and safe_num() live in R/utils.R.
# Source it only when not already loaded — the test harness pre-populates the
# environment via sys.source(), so a plain relative source() would fail when
# the working directory is tests/R/ rather than the project root.
if (!exists("openai_req", mode = "function")) source("./R/utils.R")

#' Create an OpenAI Assistants v2 assistant
#'
#' Sends a \code{POST /assistants} request to create a new persistent OpenAI
#' Assistant configured with a model, optional instructions, and a list of
#' tools. In the grading workflow this is called once per lab to create an
#' assistant that can search the uploaded rubric, solution, and starter files
#' via the \code{file_search} tool.
#'
#' @param model Character. The OpenAI model ID to use, e.g.
#'   \code{"gpt-4.1-mini"}.
#' @param name Character or \code{NULL}. An optional display name for the
#'   assistant (e.g. \code{"BSMM 8740 Lab 9 Grading Assistant"}).
#' @param instructions Character or \code{NULL}. The system-level instructions
#'   that define the assistant's behaviour. Passed as the \code{instructions}
#'   field in the API request body.
#' @param tools List. A list of tool configuration objects to enable for the
#'   assistant. Defaults to an empty list. For grading, pass
#'   \code{list(list(type = "file_search"))} to enable file retrieval.
#'
#' @returns A named list representing the created assistant object as returned
#'   by the API, including at minimum \code{$id} (the assistant ID string
#'   persisted to \code{assistant_config.json} for use by the runner script).
#'
#' @seealso \code{\link{main}}, \code{\link{openai_req}}
# ---- create an assistant ----
create_assistant_v2 <- function(model, name = NULL, instructions = NULL, tools = list()) {
  # model        = MODEL
  # name         = "Grading Assistant"
  # instructions = paste0(
  #   "You grade lab submissions using the rubric and the rendered solution. ",
  #   "Search attached files and cite sources where helpful."
  # )
  # tools        = list(list(type = "file_search"))
  body <- list(
    model = model,
    name = name,
    instructions = instructions,
    tools = tools
  )
  resp <- openai_req("/assistants") |>
    httr2::req_headers("Content-Type" = "application/json") |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_perform()
  httr2::resp_check_status(resp)
  httr2::resp_body_json(resp, simplifyVector = TRUE)
}

#' Check whether a valid assistant config exists for the given model
#'
#' Reads \code{assistant_config.json} and returns \code{TRUE} only when the
#' file exists, can be parsed as JSON, contains non-empty values for all
#' required fields (\code{assistant_id}, \code{rubric_file_id},
#' \code{solution_file_id}, \code{starter_file_id}, \code{model}), and the
#' stored \code{model} matches \code{expected_model}. Any parse error returns
#' \code{FALSE} silently.
#'
#' @param config_path Character. Path to \code{assistant_config.json}.
#' @param expected_model Character. The model ID the current session requires,
#'   e.g. \code{"gpt-5.1"}. A mismatch causes the function to return
#'   \code{FALSE}, triggering a fresh setup with the correct model.
#'
#' @returns Logical scalar. \code{TRUE} if the config is present, complete, and
#'   matches \code{expected_model}; \code{FALSE} otherwise.
#'
#' @seealso \code{\link{main}}
config_is_valid <- function(config_path, expected_model) {
  if (!fs::file_exists(config_path)) return(FALSE)
  cfg <- tryCatch(
    jsonlite::read_json(config_path),
    error = function(e) NULL
  )
  if (is.null(cfg)) return(FALSE)
  required <- c("assistant_id", "rubric_file_id", "solution_file_id",
                "starter_file_id", "model")
  has_all <- all(vapply(required, function(k) {
    v <- cfg[[k]]
    !is.null(v) && nzchar(as.character(v))
  }, logical(1L)))
  has_all && identical(cfg[["model"]], expected_model)
}

#' Set up the OpenAI grading assistant for a lab
#'
#' Orchestrates the setup required before batch grading can begin. If a valid
#' \code{assistant_config.json} already exists for the current \code{MODEL},
#' setup is skipped entirely and the function returns invisibly — preventing
#' redundant file uploads and assistant creation on repeated runs. When setup
#' is needed, the function: renders the solution and starter \code{.qmd} files
#' to GitHub Flavored Markdown, uploads the rubric, rendered solution, and
#' rendered starter to the OpenAI Files API, creates an Assistants v2 assistant
#' configured with the \code{file_search} tool, and persists the resulting IDs
#' (plus the model name) to \code{assistant_config.json}.
#'
#' Reads file paths from the module-level constants \code{RUBRIC_PATH},
#' \code{SOLUTION_QMD}, \code{STARTER_FILE}, \code{CONFIG_JSON}, and
#' \code{MODEL}, which are set at the top of this file.
#'
#' @returns Called for its side effects. Returns \code{NULL} invisibly.
#'   Writes \code{assistant_config.json} containing \code{assistant_id},
#'   \code{rubric_file_id}, \code{solution_file_id}, \code{starter_file_id},
#'   and \code{model}. Emits progress messages via \code{message()}.
#'
#' @seealso \code{\link{config_is_valid}}, \code{\link{qmd_to_temp_md}},
#'   \code{\link{upload_for_assistants}}, \code{\link{create_assistant_v2}}
# ---- main ----
main <- function() {
  # ensure key present
  key <- Sys.getenv("OPENAI_API_KEY", unset = NA_character_)
  if (is.na(key) || !nzchar(key)) stop("OPENAI_API_KEY is not set.")

  # skip setup if a valid config already exists for this model
  if (config_is_valid(CONFIG_JSON, MODEL)) {
    message("Valid assistant config found for model ", MODEL, ". Skipping setup.")
    return(invisible(NULL))
  }

  # render solution to GFM
  solution_md <- qmd_to_temp_md(SOLUTION_QMD)
  starter_md  <- qmd_to_temp_md(STARTER_FILE)

  # upload three files
  rubric_file   <- upload_for_assistants(RUBRIC_PATH, api_key = key)
  solution_file <- upload_for_assistants(solution_md, api_key = key)
  starter_file  <- upload_for_assistants(starter_md, api_key = key)

  # create assistant with file_search tool
  assistant <- create_assistant_v2(
    model        = MODEL,
    name         = "Grading Assistant",
    instructions = paste0(
      "You grade lab submissions using the rubric and the rendered solution. ",
      "Search attached files and cite sources where helpful."
    ),
    tools        = list(list(type = "file_search"))
  )

  # persist IDs and model
  cfg <- list(
    assistant_id      = assistant$id,
    rubric_file_id    = rubric_file$id,
    solution_file_id  = solution_file$id,
    starter_file_id   = starter_file$id,
    model             = MODEL
  )

  jsonlite::write_json(cfg, CONFIG_JSON, pretty = TRUE, auto_unbox = TRUE)

  message("Assistant created. ", assistant$id)
  message("Saved IDs to ", CONFIG_JSON)
}

# run
if (identical(environment(), globalenv())) {
  tryCatch(main(), error = function(e) {
    message("Error. ", conditionMessage(e))
    if (!interactive()) quit(save = "no", status = 1)
  })
}