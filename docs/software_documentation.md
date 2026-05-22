# LLM-Based Automated Grading System — Software Documentation

**Authors:** Louis L. Odette, Muhammad Sarim **Repository:** <https://github.com/lodette/JOSE_paper>

------------------------------------------------------------------------

## Contents

1.  [Overview](#1-overview)
2.  [Repository Structure](#2-repository-structure)
3.  [Prerequisites](#3-prerequisites)
4.  [Installation](#4-installation)
5.  [Preparing Grading Materials](#5-preparing-grading-materials)
6.  [Running the R Pipelines](#6-running-the-r-pipelines)
7.  [Running the Python Pipeline](#7-running-the-python-pipeline)
8.  [Running the Claude Pipeline](#8-running-the-claude-pipeline)
9.  [Output Format](#9-output-format)
10. [Pipeline Comparison](#10-pipeline-comparison)
11. [Running Tests](#11-running-tests)
12. [Reliability Testing](#12-reliability-testing)

------------------------------------------------------------------------

## 1. Overview

This system automates the grading of student lab assignments using a large language model (LLM). Given a rubric, an instructor solution, and a set of student submissions in Quarto (`.qmd`) format, the grader returns a numeric grade and written feedback for each question in each assignment, written to a CSV file.

Three independent pipelines are provided that produce equivalent outputs from the same input materials:

-   **Python pipeline** — uses the OpenAI Chat Completions API. Grading materials are inlined in every request, with ephemeral prompt caching used to amortise the cost of the shared context across the batch. Execution is synchronous.
-   **Claude pipeline** — uses the Anthropic Messages API. Grading materials are inlined in every request with ephemeral prompt caching. Structured output is enforced via forced tool use rather than `response_format`. Execution is synchronous.
-   **R pipeline** — two variants. The primary variant (**Chat Completions**) mirrors the Python approach and is stateless. The advanced variant (**Assistants v2**) uploads grading materials to OpenAI once and retrieves them at inference time via `file_search`; execution is asynchronous with a polling loop.

All pipelines accept assignments containing any mix of programming questions, open-ended statistical reasoning questions, and closed-form numerical questions.

------------------------------------------------------------------------

## 2. Repository Structure

```         
.
├── R/
│   ├── oaii_grading_assistant.R         # Setup: upload files, create assistant, save IDs
│   ├── oaii_grading_assistant_runner.R  # Grading: batch loop, poll, parse, write CSV (Assistants v2)
│   ├── chat_grading_runner.R            # Grading: Chat Completions pipeline (mirrors Python)
│   ├── reliability_test.R               # Run grade_student() N times per student; write per-student CSVs
│   ├── aggregate_results.R              # Aggregate per-student reliability CSVs into comparison summary
│   └── utils.R                          # Shared helpers (safe_num, etc.)
│
├── Python/
│   ├── grading_context.py               # Config, shared message builders, prompt caching
│   ├── grade_student.py                 # Grade a single student submission
│   ├── batch_grade.py                   # Entry point: walk folders, grade all, write CSV
│   ├── summarize_criterion_coverage.py  # Direct criterion coverage summary (Intervention B+)
│   └── grader_instructions.txt          # System prompt passed to the LLM
│
├── Claude/
│   ├── grading_context.py               # Config, Anthropic system blocks, tool schema
│   ├── grade_student.py                 # Grade a single student submission via Messages API
│   ├── batch_grade.py                   # Entry point: walk folders, grade all, write CSV
│   └── grader_instructions.txt          # System prompt for the Anthropic pipeline
│
├── assignment/
│   ├── lab_9_rubric.json                # Grading rubric (per-exercise criteria and points)
│   ├── lab_9_starter.qmd                # Assignment template distributed to students
│   ├── lab_9_solutions.qmd             # Instructor solution
│   ├── assistant_config.json            # Persisted OpenAI IDs (written by R setup)
│   └── student_1/
│       └── lab-9.qmd                   # Example student submission
│
├── tests/
│   ├── R/
│   │   └── test_helper_functions.R      # testthat tests for R helpers
│   ├── test_grading_context.py
│   └── test_grade_student.py
│
├── .env                                 # API keys (not committed)
├── requirements.txt                     # Python package list
├── pyproject.toml                       # Python project metadata
└── CLAUDE.md                            # Project notes for Claude Code
```

------------------------------------------------------------------------

## 3. Prerequisites

### API keys

The Python and R pipelines require an **OpenAI API key**. The Claude
pipeline requires an **Anthropic API key**. Create a file named `.env`
at the project root:

```ini
OPENAI_API_KEY=sk-...        # required for Python and R pipelines
ANTHROPIC_API_KEY=sk-ant-... # required for Claude pipeline
BASE_LAB_DIR=/path/to/student/submissions

# Optional — uncomment to route Python/R calls to a local LM Studio / Ollama server:
# LLM_PROVIDER=local
# LLM_BASE_URL=http://localhost:1234/v1
# LLM_MODEL=qwen/qwen3.6-27b   # exact API id from /v1/models
# LLM_API_KEY=lm-studio
```

This file is read automatically by all pipelines at startup and must not be committed to version control. The Claude pipeline does not support local inference providers.

When using LM Studio (Python and R only), the following server settings are required before starting the server:

| Setting | Required value |
|---------|---------------|
| **API** | OpenAI-compatible (not "LM Studio API") |
| **Enable Thinking** | Off |
| **Context length** | 32768 |
| **Structured output** | Off |
| **Limit Response Length** | Off |

When `LLM_PROVIDER=local` is set, the Python and R Chat Completions pipelines automatically adapt: ephemeral prompt caching is disabled, `response_format=json_object` is omitted, `/no_think` is appended to the system message (for Qwen3 models), and markdown code fences are stripped from responses if present.

### R

-   R ≥ 4.4
-   Quarto CLI (required to render `.qmd` files during setup)
-   The following R packages:

``` r
install.packages(c(
  "librarian", "httr2", "jsonlite", "stringr",
  "readr", "fs", "quarto", "rmarkdown", "tidyverse",
  "testthat", "withr"
))
```

The `oaii` package (used for file uploads in the setup script) must be installed from GitHub:

``` r
remotes::install_github("cezarykuran/oaii")
```

### Python / Claude

-   Python ≥ 3.11

Install runtime and development dependencies:

``` bash
pip install -e ".[dev]"
```

Or install runtime dependencies only:

``` bash
pip install -r requirements.txt
```

------------------------------------------------------------------------

## 4. Installation

Clone the repository and move into it:

``` bash
git clone https://github.com/wallyjulian/grading.git
cd grading
```

Create the `.env` file:

``` bash
echo "OPENAI_API_KEY=sk-your-key-here" > .env
```

Install Python dependencies (see §3 above). R packages are loaded via `librarian::shelf()` at runtime — they will be installed automatically on first run if not already present.

------------------------------------------------------------------------

## 5. Preparing Grading Materials

All grading materials live in the `assignment/` directory. Three files are required before any pipeline can run.

### 5.1 Assignment files

| File                    | Purpose                                   |
|-------------------------|-------------------------------------------|
| `lab_{N}_starter.qmd`   | The assignment template given to students |
| `lab_{N}_solutions.qmd` | The instructor solution                   |
| `lab_{N}_rubric.json`   | Per-exercise grading criteria             |

Replace `{N}` with the lab number (e.g. `9`). The lab number is passed as a command-line argument to the Python and Claude pipelines and set at the top of the R scripts.

### 5.2 Rubric format

The rubric is a JSON file with a `GlobalScoring` block and one entry per exercise (`Ex1`, `Ex2`, …). Each exercise has a `Points` value, a `Criteria` description, a `Checks` object with three named sub-criteria, a `DiscretionaryPenalty` note, and an `OA_proxy` field. `OA_proxy` is a string describing a source-checkable property (a specific function call, formula, column name, or data input) that the grader should verify directly to assess OutputAccuracy. Set it to `""` when OutputAccuracy can be inferred from the code structure alone.

``` json
{
  "GlobalScoring": {
    "PerExercisePoints": 5,
    "Breakdown": ["CodeExecution (1 pt)", "ProcessFidelity (2 pt)", "OutputAccuracy (2 pt)"],
    "DiscretionaryPenaltyMax": 1,
    "Rules": [
      "Start from 5 points per exercise and deduct per sub-criterion.",
      "Clamp each exercise score to [0, 5]."
    ]
  },
  "Ex1": {
    "Points": 5,
    "Criteria": "Calculate probability that a new customer remains active after 6 months using Markov chain matrix operations",
    "Checks": {
      "CodeExecution (1 pt)": "Code creates transition matrix P using matrix(), then computes 6th power using %^% operator from expm, and multiplies initial state vector using %*%",
      "ProcessFidelity (2 pt)": "Defines 4x4 transition matrix P, computes P^6, multiplies initial state vector c(1,0,0,0) with P6 then with indicator vector c(1,1,1,0)",
      "OutputAccuracy (2 pt)": "Result is approximately 0.75 or 75%"
    },
    "DiscretionaryPenalty (up to -1 pt)": "Code does not execute to completion.",
    "OA_proxy": ""
  }
}
```

The rubric exercises (`Ex1`, `Ex2`, …) map to question columns (`Q1`, `Q2`, …) in the output CSV.

### 5.3 Grader instructions

`Python/grader_instructions.txt` is the system prompt used by both the **Python** and **R Chat Completions** pipelines. `Claude/grader_instructions.txt` is the system prompt used by the **Claude** pipeline; the two files are nearly identical, differing only in how structured output is requested (JSON object vs `submit_grade` tool call). Both instruct the model to grade based on the `.qmd` source only (not assumed execution output), to assess each sub-criterion independently before assigning a grade, and to produce `met`/`evidence` blocks for each of `CodeExecution`, `ProcessFidelity`, and `OutputAccuracy`. When the rubric exercise includes a non-empty `OA_proxy` field, the grader uses it as the primary basis for the OutputAccuracy assessment.

The expected JSON output structure is:

``` json
{
  "questions": {
    "Q1": {
      "CodeExecution":   { "met": true,  "evidence": "matrix() and %^% operator used correctly." },
      "ProcessFidelity": { "met": true,  "evidence": "Initial state vector multiplied with P^6 as specified." },
      "OutputAccuracy":  { "met": true,  "evidence": "Code structure produces a result ≈ 0.75 as expected." },
      "grade": 4.5,
      "feedback": "Transition matrix correct; P^6 computed correctly; output matches expected value."
    }
  },
  "total": 4.5,
  "overall_comment": "Strong understanding of Markov chains."
}
```

Edit the relevant `grader_instructions.txt` to adjust grading behaviour without changing any code.

### 5.4 Student submission layout

Student submissions must be organised as follows:

```         
{BASE_LAB_DIR}/
└── lab-{N}/
    ├── lab-9_StudentA/
    │   └── lab-9.qmd
    ├── lab-9_StudentB/
    │   └── lab-9.qmd
    └── ...
```

The student ID is extracted from the folder name as the portion after the first underscore (e.g. `StudentA` from `lab-9_StudentA`). The submission file must be named `lab-{N}.qmd`.

------------------------------------------------------------------------

## 6. Running the R Pipelines

Two independent R grading pipelines are provided. The **Assistants v2 pipeline** uploads grading materials to OpenAI and uses `file_search` for context retrieval. The **Chat Completions pipeline** mirrors the Python approach: materials are inlined in every request with ephemeral prompt caching.

### 6.1 Assistants v2 pipeline

The Assistants v2 pipeline runs in two phases. The setup phase is run once per assignment; the grading phase can be re-run at any time.

#### 6.1.1 Set environment variables

Add the following to your `.env` or R session:

``` r
LAB_NUMBER <- 9
```

Or set it before sourcing:

``` r
Sys.setenv(LAB_NUMBER = "9")
```

#### 6.1.2 Phase 1 — Setup (run once per assignment)

``` r
source("R/oaii_grading_assistant.R")
main()
```

This performs four steps:

1.  Renders `lab_{N}_solutions.qmd` and `lab_{N}_starter.qmd` to GitHub Flavored Markdown using `quarto::quarto_render()`. Output is written to a temporary file to avoid modifying the source directory.
2.  Uploads the rubric JSON, rendered solution, and rendered starter to the OpenAI Files API (`purpose = "assistants"`).
3.  Creates an OpenAI Assistant (`gpt-5.1`) with the `file_search` tool enabled, allowing it to retrieve content from the uploaded files at inference time.
4.  Writes the resulting IDs to `assignment/assistant_config.json`:

``` json
{
  "assistant_id": "asst_...",
  "rubric_file_id": "file-...",
  "solution_file_id": "file-...",
  "starter_file_id": "file-..."
}
```

> **Note:** Re-run the setup phase any time the rubric, solution, or starter file changes. New file IDs are needed because the previously uploaded versions remain on OpenAI's servers.

#### 6.1.3 Phase 2 — Grade

Set the path to the student submissions directory and run:

``` r
source("R/oaii_grading_assistant_runner.R")
main()
```

For each student subfolder the runner:

1.  Reads the student's `.qmd` file.
2.  Creates an isolated OpenAI thread (`POST /threads`).
3.  Posts a user message containing the grading prompt and full submission text, with the rubric, solution, and starter attached by file ID for `file_search` retrieval.
4.  Starts a run (`POST /threads/{id}/runs`) with `response_format = list(type = "json_object")` to guarantee valid JSON output.
5.  Polls the run status every 0.7 seconds until it reaches a terminal state (`"completed"`, `"failed"`, `"cancelled"`, or `"expired"`), with a 180-second timeout.
6.  Extracts the assistant's reply and parses it with `jsonlite::fromJSON()`.

Results are accumulated and written to `assignment/r_lab{N}_grades_{model}.csv` (UTF-8 BOM, for Excel compatibility) once all students have been processed. The `{model}` suffix is the sanitised model name (e.g. `gpt-5.1`), allowing OpenAI and local-LLM output to coexist.

### 6.2 Chat Completions pipeline

`chat_grading_runner.R` is a second R pipeline that mirrors the Python approach. Grading materials (rubric, starter, solution) are read from `R_assignments/` and inlined in every API call with ephemeral prompt caching, keeping the workflow stateless — no setup phase or uploaded files required.

#### 6.2.1 Set environment variables

``` r
LAB_NUMBER <- 9
```

`OPENAI_API_KEY` must be set in `.env` or the environment (or the four `LLM_*` variables for a local provider — see §3).

#### 6.2.2 Run

``` r
source("R/chat_grading_runner.R")
main()
```

For each student subfolder the runner:

1.  Reads the student's `.qmd` file.
2.  Assembles a message list: system message (from `Python/grader_instructions.txt`), three context messages (rubric, starter, solution — each tagged with `cache_control = list(type = "ephemeral")` when `LLM_PROVIDER` is `"openai"`; the tag is omitted for local providers), and a user message containing the student submission.
3.  Sends a single synchronous request to the configured endpoint (model configurable via `LLM_MODEL`, default `gpt-5.1`; `temperature = 0.1`; `response_format = json_object`).
4.  Parses the reply with `jsonlite::fromJSON()`.

Results are written to `R_assignments/r_chat_lab{N}_grades_{model}.csv` (UTF-8, with separate `Q*_feedback` columns).

------------------------------------------------------------------------

## 7. Running the Python Pipeline

The Python pipeline requires no setup phase. It reads configuration from the `.env` file and the shared `assignment/` files.

### 7.1 Run

``` bash
python Python/batch_grade.py --lab-number 9
python Python/batch_grade.py -n 4            # short form
```

`BASE_LAB_DIR` must be set in `.env`.

For each student submission file the pipeline:

1.  Loads shared grading materials once (rubric, starter, solution, grader instructions) from `assignment/`.
2.  Builds the message list:
    -   A **system message** containing the grader instructions.
    -   Three **context messages** (rubric, starter, solution), each tagged with `"cache_control": {"type": "ephemeral"}` when `LLM_PROVIDER` is `"openai"` so the API can cache and reuse their key-value representations across the full batch, reducing latency and token cost. The tag is omitted for local providers.
    -   A **user message** containing the student's `.qmd` source, wrapped in `=== STUDENT_QMD_START ===` / `=== STUDENT_QMD_END ===` delimiters.
3.  Sends a single synchronous request to the configured endpoint (model configurable via `LLM_MODEL`, default `gpt-5.1`; `temperature=0.1`; `response_format={"type": "json_object"}`).
4.  Parses the response with `json.loads()`.

Results are written to `{BASE_LAB_DIR}/lab-{N}/lab{N}_grades_{model}.csv` (UTF-8).

### 7.2 Grading a single student (programmatic use)

``` python
from pathlib import Path
from Python.grade_student import grade_student_qmd

result = grade_student_qmd(Path("assignment/student_1/lab-9.qmd"))

print(result["total"])
# → 23.5

for q, info in result["questions"].items():
    print(f"{q}: {info['grade']}  —  {info['feedback']}")
    print(f"  OA met: {info['OutputAccuracy']['met']}  ({info['OutputAccuracy']['evidence']})")
# → Q1: 5.0  —  Transition matrix correct; %^% operator used; output ≈ 0.75.
# →   OA met: True  (Code structure produces a result ≈ 0.75 as expected.)

print(result["overall_comment"])
# → Strong submission overall. Minor gaps in verification steps for Ex2 and Ex4.
```

------------------------------------------------------------------------

## 8. Running the Claude Pipeline

The Claude pipeline requires no setup phase. It mirrors the Python pipeline in structure but uses the Anthropic Messages API and enforces structured output via forced tool use rather than `response_format`.

### 8.1 Configuration

`ANTHROPIC_API_KEY` must be set in `.env`. The model is hardcoded as `claude-opus-4-7` in `Claude/grading_context.py`; sampling temperature parameters are not set (they are rejected by this model). Grading consistency is delegated to the rubric prompt, the cached shared context, and the schema-constrained tool call.

### 8.2 Run

``` bash
python Claude/batch_grade.py --lab-number 9
python Claude/batch_grade.py -n 4            # short form
```

`BASE_LAB_DIR` must be set in `.env`.

For each student submission file the pipeline:

1.  Loads shared grading materials once (rubric, starter, solution, grader instructions) from `assignment/`.
2.  Builds the request:
    -   A **system parameter** — a list of text blocks containing the grader instructions, tagged with `"cache_control": {"type": "ephemeral"}`. The Anthropic Messages API requires the list form (rather than a plain string) to attach cache breakpoints.
    -   A **context user message** containing three ephemerally-cached content blocks: rubric JSON, starter `.qmd`, and instructor solution. Packing all three into a single user message with per-block cache tags creates a monotonically growing cached prefix and allows the API to reuse it across the full student batch.
    -   A **student user message** containing the submission wrapped in `=== STUDENT_QMD_START ===` / `=== STUDENT_QMD_END ===` delimiters.
3.  Sends a single synchronous request to the Anthropic Messages API with `tool_choice={"type": "tool", "name": "submit_grade"}`, forcing the model to call the `submit_grade` tool exactly once. The tool's `input_schema` is a JSON Schema that matches the expected grading output, guaranteeing a valid, pre-parsed dict without any additional JSON parsing step.
4.  Extracts the tool-call `input` from the response's `content` blocks.

Results are written to `{BASE_LAB_DIR}/lab-{N}/lab{N}_grades_claude-opus-4-7.csv` (UTF-8).

### 8.3 Grading a single student (programmatic use)

``` python
import sys
sys.path.insert(0, "Claude")

from pathlib import Path
import grading_context
from grade_student import grade_student_qmd

grading_context.configure(9)
result = grade_student_qmd(Path("assignment/student_1/lab-9.qmd"))

print(result["total"])
# → 23.5

for q, info in result["questions"].items():
    print(f"{q}: {info['grade']}  —  {info['feedback']}")
# → Q1: 5.0  —  Transition matrix correct; P^6 computed correctly.

print(result["overall_comment"])
# → Strong submission overall.
```

------------------------------------------------------------------------

## 9. Output Format

All pipelines produce a CSV file with one row per student.

### 9.1 R Assistants v2 output — `assignment/r_lab{N}_grades_{model}.csv`

| Column | Type | Description |
|------------------------|------------------------|------------------------|
| `Student` | string | Student identifier (folder name, minus the `lab-{N}_` prefix) |
| `Q1` … `Q10` | numeric | Grade for each question |
| `Total` | numeric | Overall total reported by the model |
| `Comments` | string | Per-question feedback concatenated with `\|` as separator |

Encoding: UTF-8 BOM (for direct opening in Excel without import dialog).

**Example row:**

| Student | Q1 | Q2 | Q3 | Total | Comments |
|------------|------------|------------|------------|------------|------------|
| Ama8777 | 5 | 4 | 3.5 | 23.5 | Q1. Correct. \| Q2. sum(pi) check missing. \| Q3. Derivation incomplete. |

### 9.2 Python output — `{BASE_LAB_DIR}/lab-{N}/lab{N}_grades_{model}.csv`

| Column | Type | Description |
|------------------------|------------------------|------------------------|
| `Student` | string | Student identifier |
| `Total` | numeric | Overall total |
| `OverallComment` | string | 2–3 sentence summary |
| `Q1` … `Q10` | numeric | Grade per question |
| `Q1_feedback` … `Q10_feedback` | string | Feedback per question in separate columns |

Encoding: UTF-8.

### 9.3 Claude output — `{BASE_LAB_DIR}/lab-{N}/lab{N}_grades_claude-opus-4-7.csv`

Identical column layout to the Python output (§9.2). The model name suffix is always `claude-opus-4-7` since the model is hardcoded.

| Column | Type | Description |
|------------------------|------------------------|------------------------|
| `Student` | string | Student identifier |
| `Total` | numeric | Recomputed sum of per-question grades |
| `Model_Total` | numeric | Total as returned by the model (for cross-checking) |
| `OverallComment` | string | 2–3 sentence summary |
| `Q1` … `QN` | numeric | Grade per question |
| `Q1_feedback` … `QN_feedback` | string | Feedback per question in separate columns |

Encoding: UTF-8.

### 9.4 Error rows

If grading fails for an individual student (API timeout, malformed JSON, missing file, or missing tool-use block), all pipelines record an error row rather than halting the batch. All grade columns are set to `None`/`NA` and the comment column contains the exception message. The batch continues with the next student.

------------------------------------------------------------------------

## 10. Pipeline Comparison

Four pipelines are available. The primary comparison in the JOSE paper is between the **Python** pipeline and the **R (Assistants v2)** pipeline; the **R (Chat Completions)** pipeline is a direct R port of the Python approach and serves as a language-control condition; the **Claude** pipeline demonstrates portability across LLM providers.

| Aspect | Python | Claude | R — Chat Completions | R — Assistants v2 |
|---|---|---|---|---|
| **API** | OpenAI Chat Completions | Anthropic Messages | OpenAI Chat Completions | OpenAI Assistants v2 |
| **SDK** | `openai` | `anthropic` | `httr2` | `httr2` (via `oaii`) |
| **Execution** | Synchronous | Synchronous | Synchronous | Asynchronous with polling |
| **Setup required** | None | None | None | One-time per assignment |
| **Context delivery** | Inlined in every request | Inlined in every request | Inlined in every request | Uploaded once; retrieved via `file_search` |
| **Caching** | Ephemeral (OpenAI only) | Ephemeral (system blocks + 3 content blocks) | Ephemeral (OpenAI only) | Persistent file storage on OpenAI servers |
| **Structured output** | `response_format=json_object` | Forced tool use (`submit_grade` tool) | `response_format=json_object` | `response_format=json_object` on run |
| **Output parsing** | `json.loads()` | Tool-call `input` (pre-validated dict) | `jsonlite::fromJSON()` | `jsonlite::fromJSON()` |
| **Temperature** | `0.1` | n/a | `0.1` | `0.1` |
| **Model** | configurable via `LLM_MODEL` (default `gpt-5.1`) | `claude-opus-4-7` (hardcoded) | configurable via `LLM_MODEL` (default `gpt-5.1`) | configurable via `LLM_MODEL` (default `gpt-5.1`) |
| **Local provider support** | Yes | No | Yes | No |
| **CSV encoding** | UTF-8 | UTF-8 | UTF-8 | UTF-8 BOM |
| **Feedback columns** | Per-question (`Q1_feedback`, …) | Per-question (`Q1_feedback`, …) | Per-question (`Q1_feedback`, …) | Concatenated in `Comments` |

**Python** and **R (Chat Completions)** are operationally equivalent — stateless, no setup step, same caching strategy. The R Chat Completions runner exists to confirm that the Python pipeline's behaviour is reproducible in native R using the same API surface.

**Claude** matches Python and R (Chat Completions) in execution model and context delivery but uses the Anthropic Messages API. The key structural difference is structured output: forced tool use guarantees a pre-validated dict rather than a JSON string, eliminating any parsing step. The Claude pipeline does not support local inference providers.

**R (Assistants v2)** offloads grading materials to OpenAI file storage, keeping per-call payloads small. Repeated grading runs do not re-upload files. The cost is the two-script workflow and asynchronous polling logic.

------------------------------------------------------------------------

## 11. Running Tests

Tests confirm correct behaviour of helper functions without making real API calls. A dummy API key (`sk-test-dummy-key-for-ci`) is used in CI; the OpenAI client is fully mocked in the Python tests.

### R

``` bash
Rscript -e "testthat::test_dir('tests/R', reporter = 'progress')"
```

Tests cover: R syntax validity, `qmd_to_temp_md()` error on missing file, `upload_for_assistants()` error on missing file, `openai_req()` error when `OPENAI_API_KEY` is unset or empty, and correct `httr2_request` construction with a valid key.

### Python

``` bash
pytest tests/ --ignore=tests/R
```

Tests cover: `load_text()` (UTF-8 reading, `FileNotFoundError`), `build_system_message()` (structure and role), `build_cached_context_messages()` (three messages with ephemeral cache control when `LLM_PROVIDER="openai"`; no `cache_control` key when `LLM_PROVIDER="local"`), and `grade_student_qmd()` (response structure, model name, `response_format`, `FileNotFoundError` on missing submission).

------------------------------------------------------------------------

## 12. Reliability Testing

Reliability testing measures grading variability by running each student submission through a pipeline multiple times with identical inputs and recording the spread of scores across runs.

### 12.1 R reliability test

`R/reliability_test.R` drives repeated grading using the Chat Completions pipeline (`chat_grading_runner.R`). For each student it calls `grade_student()` `N` times and writes one CSV per student containing one row per run.

**Usage:**

``` r
N <- 10          # number of runs per student (default 10)
source("R/reliability_test.R")
```

Re-running the script **appends** new runs to existing CSVs with continuous run numbering, so running it ten times with `N = 10` accumulates 100 rows per student.

**Output files** are written beside the student submission folders:

```         
{directory_path}/{folder_name}_grades_{model}.csv
```

e.g. `R_assignments/lab-9_student_high_grades_gpt-5.1.csv`

Each CSV has columns: `Run`, `Total`, `OverallComment`, `Q1`–`QN`, `Q1_feedback`–`QN_feedback`.

### 12.2 Aggregating results

`R/aggregate_results.R` reads the per-student reliability CSVs produced by both the Python and R pipelines and computes mean and standard deviation for each score column, writing a summary CSV with two rows per student (Python then R), separated by blank rows.

**Prerequisites:**

-   R per-student CSVs in `R_assignments/` matching `lab-{N}_*_grades_*.csv`
-   Python per-student CSVs in `{BASE_LAB_DIR}/lab-{N}/` with matching names
-   `BASE_LAB_DIR` environment variable set

**Usage:**

``` r
source("R/aggregate_results.R")
```

**Output:** `assignment/comparison_summary.csv`

Numeric columns are formatted as `mean (sd)` (e.g. `4.6 (0.52)`). The question columns (`Q1`, `Q2`, …) are detected automatically from the data — no hardcoded count required.
