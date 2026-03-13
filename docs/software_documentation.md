# LLM-Based Automated Grading System — Software Documentation

**Authors:** Louis L. Odette, Muhammad Sarim **Repository:** <https://github.com/wallyjulian/grading>

------------------------------------------------------------------------

## Contents

1.  [Overview](#1-overview)
2.  [Repository Structure](#2-repository-structure)
3.  [Prerequisites](#3-prerequisites)
4.  [Installation](#4-installation)
5.  [Preparing Grading Materials](#5-preparing-grading-materials)
6.  [Running the R Pipeline](#6-running-the-r-pipeline)
7.  [Running the Python Pipeline](#7-running-the-python-pipeline)
8.  [Output Format](#8-output-format)
9.  [Pipeline Comparison](#9-pipeline-comparison)
10. [Running Tests](#10-running-tests)

------------------------------------------------------------------------

## 1. Overview

This system automates the grading of student lab assignments using a large language model (LLM). Given a rubric, an instructor solution, and a set of student submissions in Quarto (`.qmd`) format, the grader returns a numeric grade and written feedback for each question in each assignment, written to a CSV file.

Two independent pipelines are provided that produce equivalent outputs from the same input materials:

-   **R pipeline** — uses the OpenAI Assistants v2 API. Grading materials are uploaded to OpenAI once and retrieved by the model at inference time via semantic search (`file_search`). Execution is asynchronous, with a polling loop monitoring each run to completion.
-   **Python pipeline** — uses the OpenAI Chat Completions API. Grading materials are inlined in every request, with prompt caching used to amortise the cost of the shared context across the batch. Execution is synchronous.

Both pipelines accept assignments containing any mix of programming questions, open-ended statistical reasoning questions, and closed-form numerical questions.

------------------------------------------------------------------------

## 2. Repository Structure

```         
.
├── R/
│   ├── oaii_grading_assistant.R         # Setup: upload files, create assistant, save IDs
│   └── oaii_grading_assistant_runner.R  # Grading: batch loop, poll, parse, write CSV
│
├── Python/
│   ├── grading_context.py               # Config, shared message builders, prompt caching
│   ├── grade_student.py                 # Grade a single student submission
│   ├── batch_grade.py                   # Entry point: walk folders, grade all, write CSV
│   └── grader_instructions.txt          # System prompt passed to the LLM
│
├── assignment/
│   ├── rubric_lab_9.json                # Grading rubric (per-exercise criteria and points)
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
├── .env                                 # API key (not committed)
├── requirements.txt                     # Python and R package lists
├── pyproject.toml                       # Python project metadata
└── CLAUDE.md                            # Project notes for Claude Code
```

------------------------------------------------------------------------

## 3. Prerequisites

### API key

Both pipelines require an OpenAI API key. Create a file named `.env` at the project root:

```         
OPENAI_API_KEY=sk-...
```

This file is read automatically by both pipelines at startup and must not be committed to version control.

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

### Python

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

All grading materials live in the `assignment/` directory. Three files are required before either pipeline can run.

### 5.1 Assignment files

| File                    | Purpose                                   |
|-------------------------|-------------------------------------------|
| `lab_{N}_starter.qmd`   | The assignment template given to students |
| `lab_{N}_solutions.qmd` | The instructor solution                   |
| `rubric_lab_{N}.json`   | Per-exercise grading criteria             |

Replace `{N}` with the lab number (e.g. `9`). The lab number is read from the `LAB_NUMBER` environment variable at runtime.

### 5.2 Rubric format

The rubric is a JSON file with a `GlobalScoring` block and one entry per exercise (`Ex1`, `Ex2`, …). Each exercise has a `Points` value, a `Criteria` description, a `Checks` object with three named sub-criteria, and a `DiscretionaryPenalty` note.

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
    "DiscretionaryPenalty (up to -1 pt)": "Code does not execute to completion."
  }
}
```

The rubric exercises (`Ex1`, `Ex2`, …) map to question columns (`Q1`, `Q2`, …) in the output CSV.

### 5.3 Grader instructions (Python pipeline)

`Python/grader_instructions.txt` contains the system prompt given to the LLM. It instructs the model to grade based on the `.qmd` source only (not assumed execution output), to apply the rubric criteria, and to return a single JSON object in the following schema:

``` json
{
  "questions": {
    "Q1": { "grade": 4.5, "feedback": "Transition matrix correct; P^6 computed correctly; output matches expected value." },
    "Q2": { "grade": 3.0, "feedback": "Stationary distribution solved but sum(pi) verification missing." }
  },
  "total": 7.5,
  "overall_comment": "Strong understanding of Markov chains. Minor gaps in verification steps."
}
```

Edit this file to update the grading instructions without changing any code.

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

## 6. Running the R Pipeline

The R pipeline runs in two phases. The setup phase is run once per assignment; the grading phase can be re-run at any time.

### 6.1 Set environment variables

Add the following to your `.env` or R session:

``` r
LAB_NUMBER <- 9
```

Or set it before sourcing:

``` r
Sys.setenv(LAB_NUMBER = "9")
```

### 6.2 Phase 1 — Setup (run once per assignment)

``` r
source("R/oaii_grading_assistant.R")
main()
```

This performs four steps:

1.  Renders `lab_{N}_solutions.qmd` and `lab_{N}_starter.qmd` to GitHub Flavored Markdown using `quarto::quarto_render()`. Output is written to a temporary file to avoid modifying the source directory.
2.  Uploads the rubric JSON, rendered solution, and rendered starter to the OpenAI Files API (`purpose = "assistants"`).
3.  Creates an OpenAI Assistant (`gpt-4.1-mini`) with the `file_search` tool enabled, allowing it to retrieve content from the uploaded files at inference time.
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

### 6.3 Phase 2 — Grade

Set the path to the student submissions directory and run:

``` r
# In your .env or before sourcing:
# CONFIG_JSON  <- "./assignment/assistant_config.json"
# directory_path <- paste0(getwd(), "/lab-9")

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

Results are accumulated and written to `assignment/r_lab{N}_grades.csv` (UTF-8 BOM, for Excel compatibility) once all students have been processed.

------------------------------------------------------------------------

## 7. Running the Python Pipeline

The Python pipeline requires no setup phase. It reads all configuration from environment variables and the shared `assignment/` files.

### 7.1 Set environment variables

Add the following to your `.env`:

```         
LAB_NUMBER=9
BASE_LAB_DIR=/path/to/student/submissions
```

`BASE_LAB_DIR` should be the parent of the `lab-{N}/` folder — the pipeline appends `lab-{N}/` automatically.

### 7.2 Run

``` bash
python Python/batch_grade.py
```

For each student submission file the pipeline:

1.  Loads shared grading materials once (rubric, starter, solution, grader instructions) from `assignment/`.
2.  Builds the message list:
    -   A **system message** containing the grader instructions.
    -   Three **context messages** (rubric, starter, solution), each tagged with `"cache_control": {"type": "ephemeral"}` so the OpenAI API can cache and reuse their key-value representations across the full batch, reducing both latency and token cost.
    -   A **user message** containing the student's `.qmd` source, wrapped in `=== STUDENT_QMD_START ===` / `=== STUDENT_QMD_END ===` delimiters.
3.  Sends a single synchronous request to `POST /chat/completions` (`gpt-5.1`, `temperature=0.1`, `response_format={"type": "json_object"}`).
4.  Parses the response with `json.loads()`.

Results are written to `{BASE_LAB_DIR}/lab-{N}/lab{N}_grades.csv` (UTF-8).

### 7.3 Grading a single student (programmatic use)

``` python
from pathlib import Path
from Python.grade_student import grade_student_qmd

result = grade_student_qmd(Path("assignment/student_1/lab-9.qmd"))

print(result["total"])
# → 23.5

for q, info in result["questions"].items():
    print(f"{q}: {info['grade']}  —  {info['feedback']}")
# → Q1: 5.0  —  Transition matrix correct; %^% operator used; output ≈ 0.75.
# → Q2: 4.0  —  Stationary distribution correct; sum(pi) check missing.
# ...

print(result["overall_comment"])
# → Strong submission overall. Minor gaps in verification steps for Ex2 and Ex4.
```

------------------------------------------------------------------------

## 8. Output Format

Both pipelines produce a CSV file with one row per student.

### 8.1 R output — `assignment/r_lab{N}_grades.csv`

| Column | Type | Description |
|----|----|----|
| `Student` | string | Student identifier (folder name, minus the `lab-{N}_` prefix) |
| `Q1` … `Q10` | numeric | Grade for each question |
| `Total` | numeric | Overall total reported by the model |
| `Comments` | string | Per-question feedback concatenated with `\|` as separator |

Encoding: UTF-8 BOM (for direct opening in Excel without import dialog).

**Example row:**

| Student | Q1 | Q2 | Q3 | Total | Comments |
|----|----|----|----|----|----|
| Ama8777 | 5 | 4 | 3.5 | 23.5 | Q1. Correct. \| Q2. sum(pi) check missing. \| Q3. Derivation incomplete. |

### 8.2 Python output — `{BASE_LAB_DIR}/lab-{N}/lab{N}_grades.csv`

| Column | Type | Description |
|----|----|----|
| `Student` | string | Student identifier |
| `Total` | numeric | Overall total |
| `OverallComment` | string | 2–3 sentence summary |
| `Q1` … `Q10` | numeric | Grade per question |
| `Q1_feedback` … `Q10_feedback` | string | Feedback per question in separate columns |

Encoding: UTF-8.

### 8.3 Error rows

If grading fails for an individual student (API timeout, malformed JSON, or missing file), both pipelines record an error row rather than halting the batch. In the R pipeline, all grade columns are set to `NA` and the `Comments` column contains the error description. In the Python pipeline, all grade columns are `None` and `OverallComment` contains the exception message. The batch continues with the next student.

------------------------------------------------------------------------

## 9. Pipeline Comparison

| Aspect | Python | R |
|----|----|----|
| **API** | Chat Completions | Assistants v2 |
| **Execution** | Synchronous | Asynchronous with polling |
| **Setup required** | None | One-time per assignment |
| **Context delivery** | Inlined in every request | Uploaded once; retrieved via `file_search` |
| **Caching** | Ephemeral prompt caching | Persistent file storage on OpenAI servers |
| **Structured output** | `response_format` enforced at API level | `response_format` set on run object |
| **Output CSV encoding** | UTF-8 | UTF-8 BOM |
| **Feedback columns** | One column per question (`Q1_feedback`, …) | All feedback concatenated in `Comments` |
| **Model** | `gpt-5.1` | `gpt-4.1-mini` |

**Python** is simpler to operate — no setup step, no server-side state, and every grading run is fully self-contained. The full context must fit in a single call, but ephemeral caching keeps token costs manageable across a batch.

**R** keeps per-call payloads small by offloading grading materials to OpenAI file storage, making repeated grading sessions (e.g. late submissions) cheaper once files are already uploaded. The cost is the two-script workflow and the asynchronous polling logic.

------------------------------------------------------------------------

## 10. Running Tests

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

Tests cover: `load_text()` (UTF-8 reading, `FileNotFoundError`), `build_system_message()` (structure and role), `build_cached_context_messages()` (three messages, ephemeral cache control), and `grade_student_qmd()` (response structure, model name, `response_format`, `FileNotFoundError` on missing submission).
