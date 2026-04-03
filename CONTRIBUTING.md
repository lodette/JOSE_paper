---
editor_options:
  markdown:
    wrap: 72
---

# Contributing

Thank you for your interest in this project. This document explains how
to report bugs, ask questions, and contribute code or documentation.

The repository is at <https://github.com/lodette/JOSE_paper>.

------------------------------------------------------------------------

## Reporting Issues

Use the [GitHub Issues](https://github.com/lodette/JOSE_paper/issues)
tab to report bugs or unexpected behaviour.

Before opening a new issue, please search existing issues to avoid
duplicates. When reporting a bug, include:

-   **Operating system** and version
-   **R version** (`R.version.string`) or **Python version**
    (`python --version`), as applicable
-   **Package versions** — for R, run `renv::diagnostics()`; for Python,
    run `pip show openai python-dotenv`
-   **The full error message** or unexpected output
-   **A minimal example** — the smallest input (rubric, submission
    snippet) that reproduces the problem
-   **Steps to reproduce** — what you ran and in what order

If the issue involves an API error (rate limit, authentication,
timeout), include the HTTP status code and any error text returned by
the API.

------------------------------------------------------------------------

## Seeking Support

For questions about usage, configuration, or adapting the grader to a
new assignment format, open a [GitHub
Discussion](https://github.com/lodette/JOSE_paper/discussions) under the
**Q&A** category.

If GitHub Discussions is not enabled on the repository, open a GitHub
Issue and apply the **question** label.

Please include:

-   Which pipeline you are using (Python, R Chat Completions, or R
    Assistants v2)
-   Your `BASE_LAB_DIR` folder structure (you can anonymise student
    folder names)
-   The lab number and a description of the rubric format
-   What you have already tried

------------------------------------------------------------------------

## Contributing Code

Contributions are welcome. The preferred workflow is:

1.  **Fork** the repository and create a feature branch from `main`
2.  Make your changes, following the code conventions below
3.  **Run the tests** (see [Running Tests](#running-tests)) and confirm
    they pass
4.  Open a **pull request** against `main` with a clear description of
    what the PR does and why

Please keep PRs focused — one feature or fix per PR makes review faster.
There is no formal changelog; PR descriptions serve as the record of
changes.

------------------------------------------------------------------------

## Environment Setup

### R

1.  Open the project in RStudio (or set the working directory to the
    project root)

2.  Install `renv` if not already installed:

    ``` r
    install.packages("renv")
    ```

3.  Restore all packages from the lockfile:

    ``` r
    renv::restore()
    ```

When you add or remove R packages during development, update the
lockfile with:

``` r
renv::snapshot()
```

Commit the updated `renv.lock` along with your code changes.

### Python

Create and activate the conda environment:

``` bash
conda env create -f environment.yml
conda activate jose-grader
```

When you add new Python packages, update `environment.yml`:

``` bash
conda env export --from-history > environment.yml
```

Commit the updated `environment.yml` along with your code changes.

### Environment Variables

Copy `.env.example` to `.env` and fill in your values:

``` ini
OPENAI_API_KEY=sk-proj-...       # Your OpenAI API key
BASE_LAB_DIR=/path/to/lab/folder # Parent folder containing lab-<N>/
```

The `.env` file is excluded from version control. Never commit it.

------------------------------------------------------------------------

## Running the Grader

### Python

``` bash
python Python/batch_grade.py                  # default lab (9)
python Python/batch_grade.py --lab-number 4   # grade lab 4
python Python/batch_grade.py -n 4             # short form
```

### R

``` r
LAB_NUMBER <- 4
source("R/chat_grading_runner.R")
main()
```

------------------------------------------------------------------------

## Running Tests {#running-tests}

### R

``` bash
Rscript -e "testthat::test_dir('tests/R', reporter = 'progress')"
```

### Python

``` bash
pytest tests/ --ignore=tests/R -v
```

Tests use a dummy API key (`sk-test-dummy-key-for-ci`) and mock the
OpenAI client — no real API calls are made. The fixture files in
`assignment/` (rubric, starter, solution for lab 9) are used by the
Python tests.

------------------------------------------------------------------------

## Code Conventions

Contributions should follow the conventions used throughout the
codebase.

### R

-   All helper functions have **Roxygen2 `#'` documentation** (title,
    `@param`, `@return`, `@examples` where appropriate)
-   Logic is wrapped in a **`main()` function** to prevent
    auto-execution on `source()`
-   Overridable config variables use the **`if (!exists("VAR"))`** guard
    pattern so they can be set before sourcing
-   Use `librarian::shelf()` for package loading
-   Handle errors defensively — per-student exceptions should be caught
    and recorded, not allowed to abort the batch

### Python

-   All functions have **docstrings** in Sphinx `:param:` / `:returns:`
    format
-   Configuration is loaded once in `grading_context.py` — do not
    duplicate `load_dotenv()` or env var reads in other modules
-   Call `grading_context.configure(lab_number)` before any grading
    functions are invoked
-   Per-student exceptions should be caught and recorded as error rows,
    not allowed to abort the batch
-   Lint with `ruff check --select F` before submitting a PR
