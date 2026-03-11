# CI Testing Overview

This document describes the GitHub Actions workflows and unit-test suite added
to validate both grading pipelines without making real OpenAI API calls.  All
files were introduced together and form a single, coherent CI layer.

---

## Repository additions at a glance

```
.github/
└── workflows/
    ├── test-python.yml        # CI for the Python pipeline
    └── test-r.yml             # CI for the R pipeline

conftest.py                    # pytest environment bootstrap (project root)

tests/
├── test_grading_context.py    # Unit tests: grading_context.py
├── test_grade_student.py      # Unit tests: grade_student.py (mocked API)
└── R/
    └── test_helper_functions.R  # Unit tests: R helper functions
```

---

## GitHub Actions: Python workflow

**File:** `.github/workflows/test-python.yml`

**Trigger:** push or pull-request to `main` when any of the following paths
change: `**.py`, `tests/**`, `grader_instructions.txt`, `assignment/**`, or
the workflow file itself.

**Steps:**

| Step | Tool | Purpose |
|---|---|---|
| Checkout | `actions/checkout@v4` | Clone the repository |
| Set up Python | `actions/setup-python@v5` (3.11, pip cache) | Reproducible interpreter |
| Install dependencies | `pip install openai python-dotenv pytest ruff` | Runtime + test + lint |
| Lint | `ruff check --select F .` | Catch undefined names, unused imports (pyflakes rules only) |
| Test | `pytest tests/ --ignore=tests/R -v` | Run all Python unit tests |

**Environment variables injected by the workflow:**

| Variable | Value in CI | Purpose |
|---|---|---|
| `LAB_NUMBER` | `"9"` | Satisfies the import-time check in `grading_context.py` |
| `OPENAI_API_KEY` | `"sk-test-dummy-key-for-ci"` | Prevents key-missing errors; never reaches the API |
| `BASE_LAB_DIR` | `"/tmp/test_lab"` | Satisfies the import-time check in `batch_grade.py` |

The linting step uses the `F` (pyflakes) rule-set deliberately: it catches
real programming errors (undefined names, unused imports, shadowed variables)
without failing on stylistic choices such as line length or variable naming.

---

## GitHub Actions: R workflow

**File:** `.github/workflows/test-r.yml`

**Trigger:** push or pull-request to `main` when any of the following paths
change: `R/**`, `tests/R/**`, `assignment/**`, or the workflow file itself.

**Steps:**

| Step | Tool | Purpose |
|---|---|---|
| Checkout | `actions/checkout@v4` | Clone the repository |
| Set up R | `r-lib/actions/setup-r@v2` (R 4.4, RSPM) | Pre-built CRAN binaries for speed |
| Cache R library | `actions/cache@v4` keyed on `R/**` | Avoid re-installing packages on every run |
| Install packages | `Rscript` inline | Install CRAN and GitHub dependencies |
| Syntax check | `Rscript -e "parse(file=…)"` loop | Verify every `.R` file in `R/` is syntactically valid |
| Run R tests | `Rscript -e "testthat::test_dir('tests/R')"` | Execute all `testthat` tests |

**R packages installed in CI:**

| Package | Source | Used by |
|---|---|---|
| `httr2` | CRAN | `oaii_grading_assistant.R` HTTP helpers |
| `jsonlite` | CRAN | JSON serialisation in both R scripts |
| `fs` | CRAN | File-system operations |
| `stringr` | CRAN | Path construction via `str_glue` |
| `readr` | CRAN | CSV output in the runner |
| `quarto` | CRAN | Namespace required for `quarto::quarto_render` |
| `librarian` | CRAN | Package loader used in the runner |
| `remotes` | CRAN | GitHub package installation |
| `testthat` | CRAN | Test framework |
| `withr` | CRAN | `with_envvar` helper used in tests |
| `cezarykuran/oaii` | GitHub | OpenAI Assistants API wrapper |

**Environment variables injected by the workflow:**

| Variable | Value in CI |
|---|---|
| `OPENAI_API_KEY` | `"sk-test-dummy-key-for-ci"` |

`LAB_NUMBER` is set as an R variable (`LAB_NUMBER <- 9L`) inside the test
file rather than as a shell environment variable, matching the convention used
by the R scripts themselves.

---

## Python test suite

### `conftest.py` — environment bootstrap

Placed at the **project root** so pytest adds the root directory to
`sys.path` automatically.  Sets all three environment variables using
`os.environ.setdefault` before any test module is imported:

```
LAB_NUMBER      → "9"
OPENAI_API_KEY  → "sk-test-dummy-key-for-ci"
BASE_LAB_DIR    → "/tmp/test_lab"
```

`setdefault` is used rather than a hard assignment so that a developer
running locally with a real `.env` file (and real values) does not have those
values silently overwritten.

---

### `tests/test_grading_context.py` — 10 tests

Tests the three public functions in `grading_context.py` without any API
interaction.

**`load_text`**

| Test | What it checks |
|---|---|
| `test_load_text_reads_utf8_file` | Reads and returns the exact content of a UTF-8 file |
| `test_load_text_accepts_string_path` | Accepts a plain `str` as well as a `Path` |
| `test_load_text_raises_for_missing_file` | Raises `FileNotFoundError` for a non-existent path |

**`build_system_message`**

| Test | What it checks |
|---|---|
| `test_build_system_message_returns_dict` | Return value is a `dict` |
| `test_build_system_message_role_is_system` | `role` key equals `"system"` |
| `test_build_system_message_content_is_nonempty_string` | `content` is a non-empty `str` |

**`build_cached_context_messages`**

| Test | What it checks |
|---|---|
| `test_build_cached_context_messages_returns_three_messages` | Exactly three messages are returned (rubric, starter, solution) |
| `test_build_cached_context_messages_all_user_role` | Every message has `role = "user"` |
| `test_build_cached_context_messages_have_ephemeral_cache_control` | Every message carries `cache_control = {"type": "ephemeral"}` |
| `test_build_cached_context_messages_content_is_single_text_block` | `content` is a one-element list whose sole item has `type = "text"` and non-empty `text` |

The last four tests exercise the real `assignment/` fixture files that live in
the repository, giving them light integration coverage at no extra cost.

---

### `tests/test_grade_student.py` — 6 tests

Tests `grade_student_qmd` using `unittest.mock.patch` to replace the `OpenAI`
class in `grade_student`'s namespace.  The mock client returns a pre-built
JSON payload; no network call is ever made.

| Test | What it checks |
|---|---|
| `test_returns_dict` | Return value is a `dict` |
| `test_contains_required_top_level_keys` | Keys `questions`, `total`, `overall_comment` are all present |
| `test_total_matches_payload` | `total` equals the value in the mocked response |
| `test_calls_api_with_configured_model` | The `model` kwarg passed to `create()` equals `grading_context.MODEL` |
| `test_enforces_json_response_format` | `response_format={"type": "json_object"}` is passed to `create()` |
| `test_raises_file_not_found_for_missing_student` | `FileNotFoundError` is raised when the `.qmd` path does not exist |

---

## R test suite

### `tests/R/test_helper_functions.R` — 7 tests

Uses `testthat` as the test framework and `withr::with_envvar` to temporarily
override environment variables within individual tests.

**Safe sourcing of `oaii_grading_assistant.R`**

The helper script ends with the guard:

```r
if (identical(environment(), globalenv())) {
  tryCatch(main(), error = function(e) { ... quit(...) })
}
```

If the file were sourced naively into `globalenv()`, `main()` would execute
and — on failure — call `quit()`, killing the test runner process.  The test
file avoids this by sourcing into a dedicated child environment:

```r
fns_env <- new.env(parent = globalenv())
fns_env$LAB_NUMBER <- 9L
sys.source("R/oaii_grading_assistant.R", envir = fns_env)
```

Because `fns_env` is not `globalenv()`, the guard evaluates to `FALSE` and
`main()` is never called.  The helper functions are then copied into the test
file's namespace for convenient use.

**Tests**

| Test | Function tested | What it checks |
|---|---|---|
| `oaii_grading_assistant.R parses without error` | — | Syntax-only parse of the setup script |
| `oaii_grading_assistant_runner.R parses without error` | — | Syntax-only parse of the runner script |
| `qmd_to_temp_md raises error for a missing file` | `qmd_to_temp_md` | `stop("Missing file …")` is triggered before any Quarto render |
| `upload_for_assistants raises error for a missing file` | `upload_for_assistants` | `stop("Missing file …")` is triggered before any API upload |
| `openai_req raises error when OPENAI_API_KEY is unset` | `openai_req` | `NA` key value triggers the guard |
| `openai_req raises error when OPENAI_API_KEY is empty string` | `openai_req` | Empty-string key triggers the guard |
| `openai_req returns an httr2_request with a valid key` | `openai_req` | Non-empty dummy key produces an `httr2_request` object without any HTTP call |

---

## Design decisions

**No real API calls.** All tests use either `unittest.mock` (Python) or
`sys.source` isolation with dummy credentials (R).  The `OPENAI_API_KEY`
values used in CI are syntactically valid non-empty strings that will be
rejected by the OpenAI API but satisfy every local validation check in the
codebase.

**Fixture files from the repository.** Rather than creating artificial stubs,
the Python context tests read the real `assignment/rubric_lab_9.json`,
`BSMM_8740_lab_9_starter.qmd`, `BSMM_8740_lab_9_solutions.qmd`, and
`grader_instructions.txt`.  This means the tests also catch problems such as a
missing or malformed rubric file.

**Linting scope.** `ruff --select F` covers pyflakes rules: undefined names,
undefined local variables, redefined imports, and unused imports.  Style rules
(line length, naming conventions) are intentionally excluded so the linter
catches bugs rather than acting as a style enforcer.

**R package caching.** The R workflow caches `$R_LIBS_USER` keyed on the hash
of all files in `R/`.  On a cache hit, the install step is skipped entirely,
keeping the workflow fast.  A cache miss occurs only when the R source files
change — a reasonable proxy for when dependencies might change.
