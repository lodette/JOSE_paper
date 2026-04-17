# JOSE Paper — Project Log

------------------------------------------------------------------------

## Session 1 — 2026-02-27

### Requested

-   Compare control flow of Python and R grading code; map equivalent functions
-   Compare Chat Completions API (Python) vs Assistants API v2 (R); pros and cons
-   Add complete Roxygen documentation to all functions in `oaii_grading_assistant_runner.R` (branch `llo_mods`)
-   Add complete Roxygen documentation to all functions in `oaii_grading_assistant.R`
-   Create short downloadable markdown overview documents for R pipeline, Python pipeline, and a comparison of both
-   Propose a reorganization plan for the R code (no changes until approved)
-   Implement all 5 approved reorganization changes

### Done

-   Mapped Python functions (`grade_student_qmd`, `build_cached_context_messages`, etc.) to R equivalents (`create_thread`, `add_message`, `start_run`, `wait_run_complete`, etc.)
-   Documented API trade-offs: Python is stateless with ephemeral caching; R is stateful with persistent file storage and async polling
-   Added full Roxygen2 docstrings to all 12 functions in `oaii_grading_assistant_runner.R`
-   Added full Roxygen2 docstrings to all 5 functions in `oaii_grading_assistant.R`
-   Created `docs/r_pipeline_overview.md`, `docs/python_pipeline_overview.md`, `docs/pipeline_comparison.md`
-   Rewrote `oaii_grading_assistant_runner.R` implementing all 5 approved changes

### Decisions

-   **Removed `parse_reply_to_row()`, `extract_qnum()`, `coerce_float()`, `%||%`**: Adding `response_format = list(type = "json_object")` to `start_run()` enforces a single canonical JSON schema, making multi-schema defensive parsing unnecessary
-   **Removed duplicate `openai_req()`** from runner: the setup script (`oaii_grading_assistant.R`) is `source()`d at the top, so `openai_req()` is already in scope
-   **Wrapped top-level grading code in `main()`** with `if (identical(environment(), globalenv()))` guard: prevents side effects when the file is `source()`d by other scripts
-   **`LAB_NUMBER` variable + `str_glue()`**: replaces all hard-coded `"2025-lab-9"` and `"r_lab9_grades.csv"` strings, making the runner lab-agnostic

### Files touched

| File | Change |
|----|----|
| `R/oaii_grading_assistant_runner.R` | Full rewrite — Roxygen, `response_format`, `main()`, `LAB_NUMBER`, removed 4 functions |
| `R/oaii_grading_assistant.R` | Roxygen added to all 5 functions |
| `docs/r_pipeline_overview.md` | Created |
| `docs/python_pipeline_overview.md` | Created |
| `docs/pipeline_comparison.md` | Created |

### Pending

-   Commit `R/oaii_grading_assistant_runner.R` (still unstaged as of end of session)

------------------------------------------------------------------------

## Session 2 — 2026-02-28

### Requested

-   Update `r_pipeline_overview.md` to reflect post-refactor parsing (output/parsing section was outdated)
-   Update `README.md` to cover both Python and R versions
-   Propose a reorganization plan for the Python code (no changes until approved)
-   Implement all 5 approved Python reorganization changes; update docs if needed
-   Add Sphinx-style docstrings to all Python functions
-   Set up a notes filesystem for the project

### Done

-   Updated Output and Parsing section of `docs/r_pipeline_overview.md` to describe `response_format` enforcement and direct `jsonlite::fromJSON()` parsing
-   Rewrote `README.md` to cover both pipelines: shared materials, separate Python and R sections, pipeline comparison table, updated grader instructions note
-   Proposed and implemented 5 Python changes (approved before implementation):
    1.  Centralized `load_dotenv()` and `LAB_NUMBER` in `grading_context.py`; imported by the other modules
    2.  Removed hardcoded Windows `BASE_LAB_DIR` fallback; raises `ValueError` if absent
    3.  Added per-student `try/except` in `batch_grade.py`; writes error row and continues
    4.  Added `Q_COUNT = 10` named constant in `grading_context.py`; imported into `batch_grade.py`
    5.  Moved `client = OpenAI()` inside `grade_student_qmd()` to eliminate module-level side effect
-   Also corrected grading material file paths in `grading_context.py` to point to `assignment/` (where files actually live) rather than project root
-   Updated `docs/python_pipeline_overview.md` to reflect all five changes
-   Added Sphinx-style docstrings (`:param:`, `:type:`, `:returns:`, `:rtype:`, `:raises:`) to all 5 Python functions across the three modules
-   Created `notes/` directory with this log

### Decisions

-   **`grading_context.py` as single config source**: keeps environment loading and all constants (`LAB_NUMBER`, `MODEL`, `Q_COUNT`, file paths) in one place; other modules import rather than re-read from env
-   **`ValueError` on missing `BASE_LAB_DIR`**: consistent with how `LAB_NUMBER` is handled; silent fallback to a personal path was a latent bug
-   **Per-student error handling**: mirrors the R runner's resilience pattern — one bad API response should not abort an entire batch
-   **Sphinx docstring style**: chosen over NumPy style for consistency with the existing partial docstring in `grade_student.py` and better compatibility with standard Python tooling (Sphinx autodoc, VS Code hover)

### Files touched

| File | Change |
|----|----|
| `docs/r_pipeline_overview.md` | Output and Parsing section updated |
| `README.md` | Full rewrite to cover both Python and R |
| `grading_context.py` | `load_dotenv()` centralized, `Q_COUNT` added, paths corrected to `assignment/`, Sphinx docstrings |
| `grade_student.py` | `load_dotenv()` removed, `LAB_NUMBER` imported, `client` moved inside function, Sphinx docstring |
| `batch_grade.py` | `BASE_LAB_DIR` fallback removed, `Q_COUNT` imported, per-student error handling, `main()` docstring |
| `docs/python_pipeline_overview.md` | Updated to reflect all 5 changes |
| `notes/README.md` | Created |
| `notes/jose_paper_log.md` | Created (this file) |

### Pending

-   Commit all changes from both sessions (runner rewrite + Python refactor + docs)
