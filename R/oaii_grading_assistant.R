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
RUBRIC_PATH  <- "./assignment/rubric_lab_9.json"
SOLUTION_QMD <- "./assignment/BSMM_8740_lab_9_solutions.qmd"
STARTER_FILE <- "./assignment/BSMM_8740_lab_9_starter.qmd"
CONFIG_JSON  <- "./assignment/assistant_config.json"

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