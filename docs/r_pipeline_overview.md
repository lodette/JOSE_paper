# R Grading Pipeline: Technical Overview

The R grading pipeline automates the evaluation of student Quarto (`.qmd`) lab
submissions using the OpenAI Assistants API v2. It is implemented across two
scripts that must be run in sequence: a one-time **setup script**
(`oaii_grading_assistant.R`) and a **runner script**
(`oaii_grading_assistant_runner.R`).

## Setup Phase

The setup script prepares the grading context and creates a persistent OpenAI
Assistant. It first renders the instructor solution and starter `.qmd` files to
GitHub Flavored Markdown using `quarto::quarto_render()`, placing each output
in a temporary file to avoid polluting the source directory. The rendered
Markdown files and the JSON rubric are then uploaded to the OpenAI Files API
via `oaii::files_upload_request()` with `purpose = "assistants"`. Finally, an
Assistant is created via `POST /assistants` with the `file_search` tool
enabled, allowing it to retrieve relevant content from the uploaded files at
inference time. The resulting assistant ID and file IDs are persisted to
`assistant_config.json` for use by the runner.

## Grading Phase

The runner script processes student submissions in batch. It reads
`assistant_config.json` to recover the assistant and file IDs, then walks the
`assignment/` directory for student subfolders, each expected to contain a
`2025-lab-{N}.qmd` submission file. For each student, the script creates an
isolated conversation thread (`POST /threads`), appends a user message
containing the grading prompt and the full submission text, and attaches the
rubric, solution, and starter file IDs so the assistant can search them via
`file_search`. An assistant run is then started (`POST /threads/{id}/runs`) and
polled at 0.7-second intervals until it reaches a terminal state or a 180-second
timeout is exceeded.

## Output and Parsing

Once a run completes, the assistant's text reply is extracted from the thread
message list and parsed from JSON into a flat named list. The parser handles
multiple response schemas that the model may produce — a named `questions`
object, an array of question items, or a flat top-level structure — normalising
question keys such as `"Q1"`, `"question_1"`, or bare integers to a canonical
form. Per-question grades and feedback are assembled into a data frame alongside
a computed total and concatenated comments column. The final results for all
students are written to `r_lab{N}_grades.csv` with a UTF-8 BOM for Excel
compatibility using `readr::write_excel_csv()`.
