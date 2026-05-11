---
editor_options: 
  markdown: 
    wrap: sentence
---

# LLM-Based Automated Grading System for Quarto Lab Submissions

An automated grading pipeline that uses a large language model (LLM) to evaluate student `.qmd` (Quarto) lab submissions against a structured rubric.
Implemented in both **Python** and **R**, the two pipelines share the same goal and grading materials but differ in their API strategy, execution model, and configuration approach.
Designed for use in graduate-level quantitative methods courses.

------------------------------------------------------------------------

## Overview

Both pipelines read each student's Quarto lab file, supply the model with the grading rubric, the starter template, and the instructor solution, and return a structured JSON grade with per-question scores and feedback.
Results are written to a CSV file for easy import into a gradebook.

```         
Student .qmd  ─┐
Rubric JSON   ─┤──▶  LLM (OpenAI or local)  ──▶  JSON grade  ──▶  grades.csv
Starter .qmd  ─┤
Solution .qmd ─┘
```

------------------------------------------------------------------------

## Repository Structure

```         
.
├── Python/
│   ├── batch_grade.py                    # Python: entry point — grades all students
│   ├── grade_student.py                  # Python: grades a single student .qmd
│   ├── grading_context.py                # Python: loads rubric, templates, builds API messages
│   └── grader_instructions.txt           # Python: system prompt for the LLM grader
│
├── R/
│   ├── chat_grading_runner.R             # R (primary): stateless Chat Completions grader
│   ├── utils.R                           # R: shared helpers (model_slug, safe_num)
│   ├── reliability_test.R                # R: repeated grading for reliability analysis
│   ├── oaii_grading_assistant.R          # R (advanced): one-time setup for Assistants v2
│   └── oaii_grading_assistant_runner.R   # R (advanced): Assistants v2 batch grading loop
│
├── assignment/
│   ├── lab_<N>_rubric.json               # Shared: per-question rubric
│   ├── lab_<N>_solutions.qmd   # Shared: instructor solution
│   ├── lab_<N>_starter.qmd     # Shared: starter template
│   └── assistant_config.json             # R only: persisted assistant and file IDs
│
├── docs/
│   ├── r_pipeline_overview.md            # Technical overview of the R pipeline
│   ├── python_pipeline_overview.md       # Technical overview of the Python pipeline
│   └── pipeline_comparison.md           # Side-by-side comparison with table
│
├── .env.example                          # Python: template for environment variables
└── .gitignore
```

> `assignment/` holds the shared grading materials for both pipelines.
> Student submission folders and generated CSV files are excluded from version control via `.gitignore`.

------------------------------------------------------------------------

## Shared Grading Materials

Both pipelines require the same three files per lab, placed in `assignment/`:

| File | Description |
|----|----|
| `lab_<N>_rubric.json` | Per-question rubric with point values and grading criteria |
| `lab_<N>_solutions.qmd` | Instructor solution for the lab |
| `lab_<N>_starter.qmd` | Starter template distributed to students |

Student submissions are organized in subfolders:

```         
assignment/
└── lab-<N>_<StudentID>/
    └── lab-<N>.qmd
```

------------------------------------------------------------------------

## Python Pipeline

### How It Works

The Python pipeline uses the **OpenAI Chat Completions API** and is fully stateless — no setup step is required.
For each student, a single synchronous API call is made containing the rubric, solution, starter, and submission all inlined in the message list.
Ephemeral prompt caching (`"cache_control": {"type": "ephemeral"}`) is applied to the shared context so that the rubric, solution, and starter prefix is reused across the full student batch, reducing both latency and token cost (OpenAI only; disabled automatically when using a local provider).
`response_format={"type": "json_object"}` is set on every call to enforce valid JSON output.

### Prerequisites

-   Python 3.10+
-   An [OpenAI API key](https://platform.openai.com/api-keys) *or* a locally running LM Studio / Ollama server

``` bash
pip install openai python-dotenv
```

### Configuration

1.  Copy the example environment file:

    ``` bash
    cp .env.example .env
    ```

2.  Edit `.env` with your values:

    ``` ini
    OPENAI_API_KEY=sk-proj-...      # Your OpenAI API key
    BASE_LAB_DIR=/path/to/your/lab/folder

    # Optional — uncomment to use a local LM Studio / Ollama server instead:
    # LLM_PROVIDER=local
    # LLM_BASE_URL=http://localhost:1234/v1
    # LLM_MODEL=qwen3.6-27b-q4_k_m
    # LLM_API_KEY=lm-studio
    ```

    `BASE_LAB_DIR` should be the parent folder containing a subdirectory named `lab-<N>`.
    Student submission folders are expected inside `lab-<N>/`.

### Usage

``` bash
python Python/batch_grade.py                  # default lab (9)
python Python/batch_grade.py --lab-number 4   # grade lab 4
python Python/batch_grade.py -n 4             # short form
```

This will: 1.
Recursively find every `lab-<N>.qmd` file under `<BASE_LAB_DIR>/lab-<N>/`.
2.
Send each file to the LLM along with the rubric, starter, and solution.
3.
Parse the returned JSON grade.
4.
Write all results to `<BASE_LAB_DIR>/lab-<N>/lab<N>_grades_{model}.csv`.

### Output Format (Python)

| Column                         | Description                               |
|--------------------------------|-------------------------------------------|
| `Student`                      | Student ID extracted from the folder name |
| `Total`                        | Sum of all question grades                |
| `OverallComment`               | 2–3 sentence summary from the LLM         |
| `Q1` … `Q10`                   | Numeric grade for each question           |
| `Q1_feedback` … `Q10_feedback` | Per-question feedback from the LLM        |

CSV encoding: **UTF-8**.

------------------------------------------------------------------------

## R Pipeline

The primary R pipeline (`chat_grading_runner.R`) is the direct R equivalent of the Python pipeline — stateless, no setup step, same Chat Completions API, same grader instructions, same output format.

### How It Works

`chat_grading_runner.R` uses the **Chat Completions API** and is fully stateless.
For each student, a single synchronous HTTP call is made with the rubric, solution, starter, and submission all inlined in the message list.
Ephemeral prompt caching is applied to the shared context when using the OpenAI API (disabled automatically for local providers).
`response_format = list(type = "json_object")` enforces valid JSON output, parsed directly with `jsonlite::fromJSON()`.

### Prerequisites

-   R 4.4+
-   An [OpenAI API key](https://platform.openai.com/api-keys) *or* a locally running LM Studio / Ollama server
-   The following R packages (installed automatically via `librarian` on first run): `httr2`, `jsonlite`, `stringr`, `readr`, `fs`

### Configuration

The lab number is set at the top of `chat_grading_runner.R`:

``` r
LAB_NUMBER <- 4   # change this to target a different lab
```

The API key and provider are read from `.env` at the project root — the same file used by the Python pipeline:

``` ini
OPENAI_API_KEY=sk-proj-...
```

To use a local LM Studio / Ollama server instead, uncomment the three `Sys.setenv()` lines near the top of `chat_grading_runner.R` (see also [Running Locally with LM Studio](#running-locally-with-lm-studio)):

``` r
# Sys.setenv(LLM_PROVIDER = "local")
# Sys.setenv(LLM_BASE_URL = "http://localhost:1234/v1")
# Sys.setenv(LLM_MODEL    = "<model-name>")
```

### Usage

``` r
source("R/chat_grading_runner.R")
main()
```

Or use the **Source** button in RStudio.
The script will:

1.  Read the rubric, starter, and solution from `R assignments/`.
2.  Walk every student subfolder in `R assignments/lab-<N>/`.
3.  Send each submission to the LLM with the shared grading context.
4.  Parse the JSON response.
5.  Write results to `R assignments/lab-<N>/r_chat_lab<N>_grades_{model}.csv`.

### Output Format (R Chat Completions)

| Column                        | Description                               |
|-------------------------------|-------------------------------------------|
| `Student`                     | Student ID extracted from the folder name |
| `Total`                       | Sum of all question grades                |
| `OverallComment`              | 2–3 sentence summary from the LLM         |
| `Q1` … `QN`                   | Numeric grade for each question           |
| `Q1_feedback` … `QN_feedback` | Per-question feedback in separate columns |

CSV encoding: **UTF-8**.

### R Assistants v2 Pipeline (advanced)

An alternative R pipeline (`oaii_grading_assistant_runner.R`) uses the **OpenAI Assistants API v2**.
It runs in two phases: a one-time setup that uploads grading materials and creates a persistent Assistant, and a grading loop that creates an isolated thread per student and polls each run to completion.
This approach keeps per-call payloads small and avoids re-uploading files for repeated grading runs, but requires an OpenAI API key and cannot be used with local providers.
See [`docs/r_pipeline_overview.md`](docs/r_pipeline_overview.md) for full setup and usage instructions.

------------------------------------------------------------------------

## Running Locally with LM Studio {#running-locally-with-lm-studio}

Both the Python and R Chat Completions pipelines can route calls to a locally running model instead of the OpenAI API — useful for privacy, offline use, or cost control.

### 1. Install and configure LM Studio

1.  Download [LM Studio](https://lmstudio.ai) and install it.
2.  In the **Discover** tab, search for and download **`qwen3.6-27b-q4_k_m`** — this is the currently recommended model for this workload on an Apple Silicon machine with 64 GB RAM.
3.  Load the model (click the model name → **Load**).
4.  Open the **Developer** tab and start the local server. The default address is `http://localhost:1234/v1`. Confirm the server is running before proceeding.

### 2. Configure the Python pipeline

Uncomment and fill in the four `LLM_*` lines in your `.env`:

``` ini
LLM_PROVIDER=local
LLM_BASE_URL=http://localhost:1234/v1
LLM_MODEL=qwen3.6-27b-q4_k_m
LLM_API_KEY=lm-studio
```

Then run as normal:

``` bash
python Python/batch_grade.py --lab-number 4
```

### 3. Configure the R pipeline

Uncomment the three `Sys.setenv()` lines near the top of `chat_grading_runner.R` and fill in the model name:

``` r
Sys.setenv(LLM_PROVIDER = "local")
Sys.setenv(LLM_BASE_URL = "http://localhost:1234/v1")
Sys.setenv(LLM_MODEL    = "qwen3.6-27b-q4_k_m")
```

Then run as normal:

``` r
source("R/chat_grading_runner.R")
main()
```

### Notes

-   The model name must match exactly what LM Studio reports — check the **Developer** tab or query `http://localhost:1234/v1/models`.
-   Ephemeral prompt caching is an OpenAI-specific feature and is disabled automatically when `LLM_PROVIDER=local`.
-   Output files include the model name as a suffix (e.g. `lab4_grades_qwen3.6-27b-q4_k_m.csv`), so local and OpenAI results coexist without overwriting each other.
-   Local model grading quality has not been formally evaluated in this study.

------------------------------------------------------------------------

## Pipeline Comparison

| Aspect | Python | R — Chat Completions | R — Assistants v2 |
|----|----|----|----|
| **API** | Chat Completions | Chat Completions | Assistants v2 |
| **Execution model** | Synchronous | Synchronous | Asynchronous with polling |
| **Setup required** | None | None | One-time per assignment |
| **Context delivery** | Inlined in every request | Inlined in every request | Uploaded once; retrieved via `file_search` |
| **Caching** | Ephemeral (OpenAI only) | Ephemeral (OpenAI only) | Persistent file storage on OpenAI servers |
| **Local provider support** | Yes | Yes | No |
| **Structured output** | `response_format={"type": "json_object"}` | `response_format = list(type = "json_object")` | `response_format = list(type = "json_object")` on run |
| **Output parsing** | `json.loads()` | `jsonlite::fromJSON()` | `jsonlite::fromJSON()` |
| **Model** | configurable via `LLM_MODEL` (default `gpt-5.1`) | configurable via `LLM_MODEL` (default `gpt-5.1`) | configurable via `LLM_MODEL` (default `gpt-5.1`) |
| **Scripts** | 3 modules in `Python/` | `chat_grading_runner.R`, `utils.R` | `oaii_grading_assistant.R`, `oaii_grading_assistant_runner.R` |
| **CSV encoding** | UTF-8 | UTF-8 | UTF-8 BOM (Excel compatible) |
| **Feedback columns** | Separate `Q1_feedback` … `QN_feedback` | Separate `Q1_feedback` … `QN_feedback` | Single concatenated `Comments` column |

------------------------------------------------------------------------

## Rubric Format

Each rubric file (`lab_<N>_rubric.json`) follows this schema:

``` json
{
  "GlobalScoring": {
    "PerExercisePoints": 5,
    "Breakdown": ["CodeExecution (1 pt)", "ProcessFidelity (2 pt)", "OutputAccuracy (2 pt)"],
    "Rules": [ "..." ]
  },
  "Ex1": {
    "Points": 5,
    "Criteria": "Description of what is being tested",
    "Checks": {
      "CodeExecution (1 pt)": "...",
      "ProcessFidelity (2 pt)": "...",
      "OutputAccuracy (2 pt)": "..."
    },
    "DiscretionaryPenalty (up to -1 pt)": "..."
  }
}
```

------------------------------------------------------------------------

## Grader Instructions

`Python/grader_instructions.txt` is used by the **Python** pipeline as the LLM system prompt.
It instructs the model to:

-   Grade only what appears in the student's `.qmd` source (not assumed execution output).
-   Return a single JSON object with `questions`, `total`, and `overall_comment`.
-   Keep feedback concise and rubric-aligned.

The **R Chat Completions** pipeline (`chat_grading_runner.R`) uses the same `Python/grader_instructions.txt` file as the Python pipeline — any change to that file affects both pipelines equally.

The **R Assistants v2** pipeline embeds a briefer set of instructions inline in the runner's grading prompt, with the assistant configured at creation time to search the uploaded rubric and solution files for relevant content.

Modify `Python/grader_instructions.txt` to adjust grading behaviour for both the Python and R Chat Completions pipelines without changing any code.

------------------------------------------------------------------------

## Adding a New Lab

**Python** — pass the lab number as a command-line argument:

``` bash
python Python/batch_grade.py --lab-number 10
```

**R** — set `LAB_NUMBER` at the top of `chat_grading_runner.R` and run:

``` r
LAB_NUMBER <- 10
source("R/chat_grading_runner.R")
main()
```

For both pipelines, place the corresponding files in `assignment/` and `R assignments/` before running:

-   `lab_10_rubric.json`
-   `lab_10_starter.qmd`
-   `lab_10_solutions.qmd`

------------------------------------------------------------------------

## Security Note

Both pipelines read credentials from the `.env` file at the project root.
This file must never be committed to version control — the `.gitignore` already excludes it.
Always use `.env.example` as the sharing template.

------------------------------------------------------------------------

## Citation

If you use this system in your research, please cite:

Sarim, M., & Odette, L. L.
(2026).
*LLM-Based Automated Grading System*.
Zenodo.
<https://doi.org/10.5281/zenodo.19410580>
