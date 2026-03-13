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
# ---- paths ----
RUBRIC_PATH  <- stringr::str_glue("./assignment/rubric_lab_{LAB_NUMBER}.json")
SOLUTION_QMD <- stringr::str_glue("./assignment/lab_{LAB_NUMBER}_solutions.qmd")
STARTER_FILE <- stringr::str_glue("./assignment/lab_{LAB_NUMBER}_starter.qmd")
CONFIG_JSON  <- "./assignment/assistant_config.json"

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

#' Build an authenticated OpenAI Assistants v2 request
#'
#' Constructs an \code{httr2} request object targeting the OpenAI v1 API,
#' pre-populated with a Bearer token from the \code{OPENAI_API_KEY} environment
#' variable and the \code{OpenAI-Beta: assistants=v2} header required by the
#' Assistants API.
#'
#' @param path Character. The API path to append to
#'   \code{https://api.openai.com/v1}, e.g. \code{"/assistants"}.
#'
#' @returns An \code{httr2_request} object ready for further modification (e.g.
#'   adding a body) and execution via \code{httr2::req_perform()}.
#'
#' @seealso \code{\link{create_assistant_v2}}
# ---- helper. build a request with auth and beta header ----
openai_req <- function(path) {
  key <- base::Sys.getenv("OPENAI_API_KEY", unset = NA_character_)
  if (base::is.na(key) || !base::nzchar(key)) {
    base::stop("OPENAI_API_KEY is not set.")
  }
  httr2::request(base::paste0("https://api.openai.com/v1", path)) |>
    httr2::req_headers(
      "Authorization" = base::paste("Bearer", key),
      "OpenAI-Beta"   = "assistants=v2"
    )
}

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

#' Set up the OpenAI grading assistant for a lab
#'
#' Orchestrates the one-time setup required before batch grading can begin.
#' Specifically: renders the solution and starter \code{.qmd} files to GitHub
#' Flavored Markdown, uploads the rubric, rendered solution, and rendered
#' starter to the OpenAI Files API, creates an Assistants v2 assistant
#' configured with the \code{file_search} tool, and persists the resulting IDs
#' to \code{assistant_config.json} for consumption by the runner script
#' (\code{oaii_grading_assistant_runner.R}).
#'
#' Reads file paths from the module-level constants \code{RUBRIC_PATH},
#' \code{SOLUTION_QMD}, \code{STARTER_FILE}, and \code{CONFIG_JSON}, which are
#' constructed from the \code{LAB_NUMBER} variable set before sourcing this
#' file.
#'
#' @returns Called for its side effects. Returns \code{NULL} invisibly.
#'   Writes \code{assistant_config.json} containing \code{assistant_id},
#'   \code{rubric_file_id}, \code{solution_file_id}, and
#'   \code{starter_file_id}. Emits progress messages via \code{message()}.
#'
#' @seealso \code{\link{qmd_to_temp_md}}, \code{\link{upload_for_assistants}},
#'   \code{\link{create_assistant_v2}}
# ---- main ----
main <- function() {
  # ensure key present
  key <- Sys.getenv("OPENAI_API_KEY", unset = NA_character_)
  if (is.na(key) || !nzchar(key)) stop("OPENAI_API_KEY is not set.")

  # render solution to GFM
  solution_md <- qmd_to_temp_md(SOLUTION_QMD)
  starter_md  <- qmd_to_temp_md(STARTER_FILE)

  # upload three files
  rubric_file   <- upload_for_assistants(RUBRIC_PATH, api_key = key)
  solution_file <- upload_for_assistants(solution_md, api_key = key)
  starter_file  <- upload_for_assistants(starter_md, api_key = key)

  # # create assistant with file_search tool
  # assistant <- oaii::assistants_create_assistant_request(
  #   model        = "gpt-4.1-mini",
  #   name         = "BSMM 8740 Lab 3 Grading Assistant",
  #   instructions = paste0(
  #     "You grade lab submissions using the rubric and the rendered solution. ",
  #     "Search attached files and cite sources where helpful."
  #   ),
  #   tools        = list(list(type = "file_search")),
  #   file_ids     = NULL,
  #   api_key      = key
  # )

  # create assistantwith file_search tool
  assistant <- create_assistant_v2(
    model        = "gpt-4.1-mini",
    name         = "BSMM 8740 Lab 9 Grading Assistant",
    instructions = paste0(
      "You grade lab submissions using the rubric and the rendered solution. ",
      "Search attached files and cite sources where helpful."
    ),
    tools        = list(list(type = "file_search"))
  )

  # persist IDs
  cfg <- list(
    assistant_id      = assistant$id,
    rubric_file_id    = rubric_file$id,
    solution_file_id  = solution_file$id,
    starter_file_id   = starter_file$id
  )

  jsonlite::write_json(cfg, CONFIG_JSON, pretty = TRUE, auto_unbox = TRUE)

  message("Assistant created. ", assistant$id)
  message("Saved IDs to ", CONFIG_JSON)
}

# run
if (identical(environment(), globalenv())) {
  tryCatch(main(), error = function(e) {
    message("Error. ", conditionMessage(e))
    quit(save = "no", status = 1)
  })
}