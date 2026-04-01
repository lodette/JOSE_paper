# Session Notes — 2026-03-31

## Objective

Investigate why the R and Python pipelines produce different grades for the
same submissions, remove confounding variables to enable a controlled
comparison, and ultimately produce a new R pipeline that is a true
apples-to-apples equivalent of the Python pipeline.

---

## Finding 1: Uncontrolled confounds in the original comparison

The two pipelines differed on three dimensions simultaneously, making the
original comparison uninterpretable:

| Confound | R (original) | Python |
|---|---|---|
| Model | `gpt-4.1-mini` | `gpt-5.1` |
| Temperature | unset (API default ~1.0) | `0.1` |
| Context delivery | `file_search` retrieval | inline with ephemeral caching |

Context delivery is the paradigm under study. Model and temperature were
unintended confounds.

---

## Changes: controlled comparison (commit `6c7513e`)

### `R/oaii_grading_assistant.R`
- Added module-level constant `MODEL <- "gpt-5.1"`
- Replaced hardcoded `"gpt-4.1-mini"` with `MODEL` in `create_assistant_v2()`

### `R/oaii_grading_assistant_runner.R`
- Added `temperature = 0.1` to the request body in `start_run()`

### `R/oaii_grading_assistant.R` — skip-setup guard
- Added `config_is_valid(config_path, expected_model)` helper: returns `TRUE`
  only when `assistant_config.json` exists, all required fields are present,
  and the stored model matches the current `MODEL` constant
- `main()` now skips setup entirely when a valid config exists, preventing
  orphaned assistant/file accumulation on repeated runs
- Config now stores `model` field; a model change automatically triggers
  fresh setup
- To force re-setup: delete `assignment/assistant_config.json`

---

## Changes: utils.R refactor (commit `5041622`)

Extracted shared functions into `R/utils.R` so the two R scripts are fully
independent of each other.

| Function | Moved from |
|---|---|
| `openai_req()` | `R/oaii_grading_assistant.R` |
| `safe_num()` | `R/oaii_grading_assistant_runner.R` |

### `R/oaii_grading_assistant.R`
- Removed `openai_req()` definition
- Added `if (!exists("openai_req", mode = "function")) source("./R/utils.R")`
  guard — skips the relative-path source when the test harness pre-populates
  the environment via `sys.source()`

### `R/oaii_grading_assistant_runner.R`
- Changed `source("./R/oaii_grading_assistant.R")` to `source("./R/utils.R")`
- Removed `safe_num()` definition
- Added explicit error if `assistant_config.json` is missing:
  setup no longer runs implicitly as a side effect of sourcing

### `tests/R/test_helper_functions.R`
- Pre-sources `utils.R` into `fns_env` before the setup file
- Added syntax check for `utils.R` (suite now 8/8)

---

## Finding 2: Assistants API does not support gpt-5.1

Attempting to run the R Assistants pipeline with `MODEL <- "gpt-5.1"` returned:

```
HTTP 400 Bad Request
"The requested model 'gpt-5.1' cannot be used with the Assistants API."
```

`gpt-5.1` is valid for Chat Completions (confirmed via `GET /v1/models`) but
not for the Assistants API. This means **model parity between the two
pipelines is structurally impossible with the Assistants architecture** — an
inherent limitation worth documenting in the paper.

The Assistants pipeline was left using `gpt-4.1-mini` (its original model)
for now; the model mismatch is noted as a limitation.

---

## Finding 3: quit() kills the interactive R session on source() errors

The error handler in both Assistants scripts called `quit(save = "no", status = 1)`
unconditionally. When `source()`-d interactively this terminates the R
session, masking the real error. Fixed in commit `df49a23`.

---

## Changes: new Chat Completions R runner (commit `df49a23`)

### New file: `R/chat_grading_runner.R`

A new R grading script that mirrors the Python pipeline exactly, enabling a
true apples-to-apples comparison between languages using the same API.

| Aspect | `chat_grading_runner.R` | Python pipeline |
|---|---|---|
| API | Chat Completions (`POST /chat/completions`) | Chat Completions |
| Model | `gpt-5.1` | `gpt-5.1` |
| Temperature | `0.1` | `0.1` |
| Context delivery | Inline with `cache_control: ephemeral` | Inline with `cache_control: ephemeral` |
| Instructions | `Python/grader_instructions.txt` (shared) | `Python/grader_instructions.txt` |
| Setup phase | None | None |
| Output CSV | UTF-8, separate `Q*_feedback` columns | UTF-8, separate `Q*_feedback` columns |

**Key functions:**
- `chat_req()` — builds authenticated request to `/chat/completions` (no
  Assistants beta header)
- `build_system_message()` — reads shared `grader_instructions.txt`
- `build_context_messages()` — rubric, starter, solution inline with
  `cache_control: ephemeral`
- `grade_student()` — single synchronous API call per student
- `main()` — batch loop with per-student error catching; writes
  `r_chat_lab{LAB_NUMBER}_grades.csv`

### `R/oaii_grading_assistant.R` and `R/oaii_grading_assistant_runner.R`
- `quit()` in error handler now guarded by `if (!interactive())` so sourcing
  interactively no longer kills the R session

### `R/chat_grading_runner.R` (commit `7ad7e17`)
- `dotenv` removed as hard dependency; `.env` loaded only if the file exists
  (API key is normally already present via `.Renviron`)
- Student submission directory updated to `R assignments/` to match local
  folder structure

---

## Three-pipeline comparison now available

| Pipeline | Script | API | Model | Notes |
|---|---|---|---|---|
| R Chat Completions | `R/chat_grading_runner.R` | Chat Completions | `gpt-5.1` | Apples-to-apples with Python |
| Python Chat Completions | `Python/batch_grade.py` | Chat Completions | `gpt-5.1` | Reference pipeline |
| R Assistants v2 | `R/oaii_grading_assistant_runner.R` | Assistants v2 | `gpt-4.1-mini` | Architectural comparison; model limited by Assistants API |

---

## Running the pipelines

### R Chat Completions (new — recommended for language comparison)
```r
source("R/chat_grading_runner.R")
# Writes: R assignments/r_chat_lab9_grades.csv
```

### Python Chat Completions
```bash
python Python/batch_grade.py
```

### R Assistants v2 (requires setup first)
```r
LAB_NUMBER <- 9
source("R/oaii_grading_assistant.R")   # setup (skipped if valid config exists)
source("R/oaii_grading_assistant_runner.R")  # grade
```

---

## Changes: reliability test script (commits `dcc5b63`, `cf9f77f`)

### New file: `R/reliability_test.R`

A script for measuring grading variability by running the Chat Completions
pipeline N times per student and saving results to a per-student CSV with
one row per run.

**Design:**
- Sources `chat_grading_runner.R` into a child environment via `sys.source()`
  so `main()` is never triggered — only `grade_student()` is borrowed
- `grade_n_times(student_file, student_name, n_runs, run_offset)` handles
  the per-student loop with per-run error catching
- Output files written beside student submission folders:
  `{directory_path}/{folder_name}_grades.csv`
  e.g. `R assignments/lab-9_student_high_grades.csv`
- Columns: `Run`, `Total`, `OverallComment`, `Q1`–`Q10`,
  `Q1_feedback`–`Q10_feedback`

**Append support (commit `cf9f77f`):**

Re-running the script appends to existing CSVs rather than overwriting,
with continuous run numbering. If a CSV already exists, `max(existing$Run)`
is read and passed as `run_offset` to `grade_n_times()`. This allows a
total of 100 runs to be accumulated across 10 separate invocations of 10.

Progress messages reflect the actual run range:
```
Grading student_high (runs 1–10) ...     ← first invocation
Grading student_high (runs 11–20) ...    ← second invocation
```

**Usage:**
```r
N <- 10                          # runs per invocation (default 10)
source("R/reliability_test.R")  # re-run to accumulate more rows
```

---

## Changes: Python reliability test (commit `f63e759`)

### New file: `Python/reliability_test.py`

Mirrors `R/reliability_test.R` for the Python pipeline.

- Accepts `--n` flag for number of runs per invocation (default 10)
- `_get_run_offset()` reads existing CSV to find max Run number for append continuity
- `grade_n_times()` loops N times, catching per-run exceptions as error rows
- Appends to existing CSVs without re-writing the header
- Output: `{BASE_LAB_DIR}/lab-{LAB_NUMBER}/{folder_name}_grades.csv`

**Usage:**
```bash
/Users/louisodette/anaconda3/envs/jose_paper/bin/python Python/reliability_test.py
/Users/louisodette/anaconda3/envs/jose_paper/bin/python Python/reliability_test.py --n 25
```

**Output location difference vs R:**
- R saves to: `R assignments/{folder_name}_grades.csv`
- Python saves to: `{BASE_LAB_DIR}/lab-9/{folder_name}_grades.csv`

---

## Changes: aggregation script (commits `41bef16`, `47c1d38`)

### New file: `R/aggregate_results.R`

Reads per-student reliability CSVs from both pipelines, computes column
means, and writes `assignment/comparison_summary.csv` with two rows per
student (Python then R) separated by blank rows.

**Columns:** `Pipeline`, `Student`, `N_Runs`, `Total`, `Q1`–`QN`

- `detect_q_cols()` reads the header of the first CSV and extracts columns
  matching `^Q[0-9]+$` sorted numerically — no hardcoded question count
- `compute_means()` averages `Total` and all Q columns across all runs
- Auto-discovers students from R CSVs and matches to corresponding Python CSVs

**Usage:**
```r
source("R/aggregate_results.R")
# writes: assignment/comparison_summary.csv
```

---

## Environment setup issues encountered

### Python environment
The system had two conda installations (`anaconda3` and `miniconda3`)
conflicting in PATH. `miniconda3` was winning, pointing to Python 3.6.7
which is too old for `openai>=1.0.0`. Resolution: use full paths explicitly.

```bash
/Users/louisodette/anaconda3/envs/jose_paper/bin/python --version  # 3.11.15
/Users/louisodette/anaconda3/envs/jose_paper/bin/pip install -r requirements.txt
/Users/louisodette/anaconda3/envs/jose_paper/bin/python Python/reliability_test.py
```

### .env file additions required
The following variables needed to be added to `.env` before the Python
pipeline would run:

```
LAB_NUMBER=9
BASE_LAB_DIR="/Users/louisodette/Documents/R_projects/JOSE_paper/python assignments"
```

`LAB_NUMBER` was missing entirely; `BASE_LAB_DIR` had a placeholder value.
Added `LAB_NUMBER` via `echo "LAB_NUMBER=9" >> .env`.

---

## CI failure: ruff F401 (commit `7129dad`)

`Python/reliability_test.py` had an unused `import sys` that failed the
ruff F401 lint check in GitHub Actions. Removed the import; CI passes.

---

## Changes: mean (sd) formatting in aggregate_results.R (commit `095580d`)

Updated `compute_means()` in `R/aggregate_results.R` to present each
numeric result as a formatted string `"mean (sd)"` rather than a plain
mean, e.g. `"5.6 (1.72)"`. Both mean and SD are rounded to 2 decimal
places. Applies to `Total` and all `Q*` columns.

The internal `fmt()` helper encapsulates the formatting:
```r
fmt <- function(x) {
  sprintf("%s (%s)",
          round(mean(x, na.rm = TRUE), 2),
          round(sd(x,   na.rm = TRUE), 2))
}
```

---

## Git history this session

| Commit | Description |
|---|---|
| `6c7513e` | Make R/Python pipelines a controlled comparison |
| `5041622` | Extract shared utilities into R/utils.R |
| `e22c996` | Merge branch `claude/tender-goldwasser` |
| `df49a23` | Add Chat Completions R runner for apples-to-apples comparison |
| `7ad7e17` | Make dotenv optional in chat_grading_runner.R |
| `7152da4` | Add session notes for 2026-03-31 |
| `dcc5b63` | Add reliability_test.R to measure grading variability |
| `cf9f77f` | Add append support to reliability_test.R |
| `84ff8f4` | Update session notes with reliability_test.R changes |
| `f63e759` | Add Python reliability_test.py to mirror R version |
| `41bef16` | Add aggregate_results.R to summarise reliability test outputs |
| `47c1d38` | Detect Q_COLS from data in aggregate_results.R |
| `7129dad` | Fix unused import in reliability_test.py (ruff F401) |
| `7603f21` | Update session notes |
| `095580d` | Format aggregate_results.R output as 'mean (sd)' |
