# R Grading Pipelines: Technical Overview

Two independent R pipelines are provided. The **Assistants v2 pipeline**
uploads grading materials to OpenAI and uses semantic `file_search` for context
delivery; it is the primary R pipeline compared against Python in the JOSE
paper. The **Chat Completions pipeline** mirrors the Python approach by inlining
all context in every request with ephemeral prompt caching.

---

## Assistants v2 Pipeline

The Assistants v2 pipeline automates the evaluation of student Quarto (`.qmd`)
lab submissions using the OpenAI Assistants API v2. It is implemented across two
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
`lab-{N}.qmd` submission file. For each student, the script creates an
isolated conversation thread (`POST /threads`), appends a user message
containing the grading prompt and the full submission text, and attaches the
rubric, solution, and starter file IDs so the assistant can search them via
`file_search`. An assistant run is then started (`POST /threads/{id}/runs`) and
polled at 0.7-second intervals until it reaches a terminal state or a 180-second
timeout is exceeded.

## Output and Parsing

Once a run completes, the assistant's text reply is extracted from the thread
message list and parsed directly with `jsonlite::fromJSON()`. Valid JSON is
guaranteed at the API level by setting `response_format = list(type =
"json_object")` on the run request, so no defensive multi-schema handling is
needed. The reply is expected to conform to a single canonical schema: a
`questions` object with keys `Q1`–`Q10`, each containing `grade` and
`feedback` fields, plus a top-level `total` and `overall_comment`. Per-question
grades and feedback are assembled into a data frame alongside a computed total
and concatenated comments column. The final results for all students are written
to `r_lab{N}_grades.csv` with a UTF-8 BOM for Excel compatibility using
`readr::write_excel_csv()`.

---

## Chat Completions Pipeline

`chat_grading_runner.R` is a stateless, single-phase R pipeline that mirrors
`Python/grade_student.py` and `Python/batch_grade.py`. No setup step or
server-side state is required.

### Context Delivery

Grading materials (rubric JSON, starter `.qmd`, instructor solution `.qmd`) are
read from `R assignments/` and inlined in every API call. Each material is
wrapped in a `role = "user"` message tagged with
`cache_control = list(type = "ephemeral")`, matching the Python pipeline's
prompt-caching strategy exactly. The shared system prompt is read from
`Python/grader_instructions.txt`.

### Single-Student Grading

`grade_student()` assembles the full message list — system message, three cached
context messages, and a user message containing the student submission delimited
by `=== STUDENT_QMD_START/END ===` — and sends a single synchronous POST to
`/chat/completions` (`gpt-5.1`, `temperature = 0.1`,
`response_format = json_object`). The response is parsed with
`jsonlite::fromJSON()`.

### Batch Processing and Output

`main()` walks `R assignments/` for student submission subfolders, calls
`grade_student()` for each, and writes results to
`R assignments/r_chat_lab{N}_grades.csv` (UTF-8). Per-student exceptions are
caught and recorded as error rows; the batch continues regardless. Output
columns match the Python pipeline: `Student`, `Total`, `OverallComment`,
`Q1`–`QN`, `Q1_feedback`–`QN_feedback`.

### Shared utilities

`utils.R` provides `safe_num()`, a helper used by both `chat_grading_runner.R`
and `reliability_test.R` to coerce parsed JSON values to numeric, returning
`NA_real_` when conversion fails.
