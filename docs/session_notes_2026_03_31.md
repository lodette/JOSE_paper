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

## Git history this session

| Commit | Description |
|---|---|
| `6c7513e` | Make R/Python pipelines a controlled comparison |
| `5041622` | Extract shared utilities into R/utils.R |
| `e22c996` | Merge branch `claude/tender-goldwasser` |
| `df49a23` | Add Chat Completions R runner for apples-to-apples comparison |
| `7ad7e17` | Make dotenv optional in chat_grading_runner.R |
