# CLAUDE.md — JOSE Paper Automated Grading Project

## Project Overview

This project implements and compares two LLM-based automated grading pipelines for student lab submissions — one in **R** (using OpenAI Assistants v2) and one in **Python** (using OpenAI Chat Completions). The comparison is the subject of a JOSE paper.

---

## Architecture

### Dual Pipeline

| | R Pipeline | Python Pipeline |
|---|---|---|
| API | OpenAI Assistants v2 | Chat Completions |
| Execution | Asynchronous (polling) | Synchronous |
| File handling | Uploaded to OpenAI, referenced by ID | Passed inline |
| Setup | Two-phase (setup + run) | Single phase |
| Output CSV | UTF-8 BOM, `Comments` column | UTF-8, separate `Q*_feedback` columns |

### Shared Materials (`assignment/`)
Both pipelines use the same rubric, starter template, and solution file stored in `assignment/`.

---

## Key Files

```
R/
  oaii_grading_assistant.R       # One-time setup: create assistant, upload files, persist IDs
  oaii_grading_assistant_runner.R  # Batch grading loop

Python/
  grading_context.py             # Config, message building, prompt caching
  grade_student.py               # Grade a single student submission
  batch_grade.py                 # Entry point: walk folders, call grade_student, write CSV

assignment/
  assistant_config.json          # Persisted IDs: assistant_id, rubric_file_id, solution_file_id, starter_file_id
  rubric_lab_9.json              # 6 exercises × 5 pts, three sub-criteria each
  lab_9_starter.qmd
  lab_9_solutions.qmd
  student_1/lab-9.qmd           # Sample student submission

tests/
  R/test_helper_functions.R
  test_grading_context.py
  test_grade_student.py

docs/                            # Pipeline overviews, CI notes, session logs
```

---

## Environment Setup

### Required
- `.env` file at project root with `OPENAI_API_KEY=sk-...`

### R
```r
# Install R dependencies (handled by librarian in the scripts)
install.packages(c("httr2", "jsonlite", "stringr", "readr", "fs", "dotenv", "quarto", "librarian"))
```

### Python
```bash
pip install -r requirements.txt   # openai, python-dotenv
```

### Required environment variables (Python)
```
OPENAI_API_KEY=sk-...
LAB_NUMBER=9
BASE_LAB_DIR=/path/to/student/submissions
```

---

## Running the Pipelines

### R — Step 1: Setup (one-time per assignment)
```r
source("R/oaii_grading_assistant.R")
main()
# Writes assistant_id and file IDs to assignment/assistant_config.json
```

### R — Step 2: Grade
```r
source("R/oaii_grading_assistant_runner.R")
main()
# Writes assignment/r_lab{LAB_NUMBER}_grades.csv
```

### Python — Grade (single phase)
```bash
python Python/batch_grade.py
# Writes {BASE_LAB_DIR}/lab-{LAB_NUMBER}/lab{LAB_NUMBER}_grades.csv
```

---

## Running Tests

### R
```bash
Rscript -e "testthat::test_dir('tests/R', reporter = 'progress')"
```

### Python
```bash
pytest tests/ --ignore=tests/R
```

CI uses a dummy API key (`sk-test-dummy-key-for-ci`) — tests mock the OpenAI client and do not make real API calls.

---

## CI/CD

Two GitHub Actions workflows with path-based triggers:

- `.github/workflows/test-r.yml` — triggers on changes to `R/**`, `tests/R/**`, `assignment/**`
  - Checks R syntax, runs testthat
- `.github/workflows/test-python.yml` — triggers on changes to `Python/**`, `tests/**`, `assignment/**`
  - Runs ruff (F rules), then pytest

---

## Code Conventions

- **R:** All helper functions have Roxygen2 `#'` documentation. Logic is wrapped in a `main()` function to prevent auto-execution on `source()`.
- **Python:** All functions have docstrings. Config is loaded once in `grading_context.py` and imported by other modules — do not duplicate config loading.
- **Both:** Defensive error handling for missing files and unset API keys. Per-student exceptions are caught and recorded as error rows rather than halting the batch.

---

## Models

- R runner: `gpt-5.1`, `temperature = 0.1` (set in `R/oaii_grading_assistant.R` and `start_run()` in `R/oaii_grading_assistant_runner.R`)
- Python: `gpt-5.1` (set in `Python/grading_context.py`)

---

## Notes

- `assistant_config.json` stores live OpenAI IDs — do not commit real keys or IDs.
- The R setup phase must be re-run if the rubric, solution, or starter file changes (new file IDs needed).
- Student submission files are expected at `{BASE_LAB_DIR}/lab-{LAB_NUMBER}/<folder>/lab-{LAB_NUMBER}.qmd`.
- Output CSVs go to `assignment/` (R) or `{BASE_LAB_DIR}/lab-{LAB_NUMBER}/` (Python).
