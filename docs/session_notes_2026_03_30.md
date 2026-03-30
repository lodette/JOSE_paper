# Session Notes — 2026-03-30

## Objective

Make the R and Python pipelines a controlled comparison by eliminating
confounding variables (model, temperature), and fix a latent bug where the
R setup phase ran on every invocation, accumulating orphaned OpenAI assets.

---

## Background

The two pipelines were observed to produce different grades for the same
student submissions. The hypothesis was that the Assistants v2 architecture
used by the R pipeline is inherently less reliable than the Chat Completions
approach used by Python. Investigation identified three confounds that made
this hypothesis untestable:

| Confound | R (before) | Python |
|---|---|---|
| Model | `gpt-4.1-mini` | `gpt-5.1` |
| Temperature | unset (API default ~1.0) | `0.1` |
| Context delivery | `file_search` retrieval | inline with prompt caching |

Context delivery is the paradigm under study and was left intentionally
different. Model and temperature were unintended confounds and have been
corrected.

---

## Changes made

### 1. Matched model: `R/oaii_grading_assistant.R`

- Added module-level constant `MODEL <- "gpt-5.1"`.
- Replaced the hardcoded `"gpt-4.1-mini"` string in `create_assistant_v2()`
  with `MODEL`.

### 2. Matched temperature: `R/oaii_grading_assistant_runner.R`

- Added `temperature = 0.1` to the request body in `start_run()`, matching
  the Python pipeline's `temperature=0.1` in `grade_student.py`.
- Updated `start_run()` Roxygen `@returns` to document the temperature setting.

### 3. Skip-setup guard: `R/oaii_grading_assistant.R`

**Problem:** The runner calls `source("./R/oaii_grading_assistant.R")` at the
top level, which executes in the global environment and therefore triggers the
`if (identical(environment(), globalenv()))` guard, running `main()` on every
invocation. This created a new assistant and uploaded three files on every
grading run, accumulating orphaned assets in the OpenAI account and adding
unnecessary latency and storage cost.

**Fix:** Added `config_is_valid()` helper and a skip guard at the top of
`main()`.

`config_is_valid(config_path, expected_model)` returns `TRUE` only when:
- `assistant_config.json` exists and parses without error,
- all required fields (`assistant_id`, `rubric_file_id`, `solution_file_id`,
  `starter_file_id`, `model`) are present and non-empty, and
- the stored `model` matches `expected_model`.

The model check ensures that changing `MODEL` automatically triggers a fresh
setup, preventing the pipeline from grading with an assistant backed by the
wrong model.

`main()` now stores `model = MODEL` in `assistant_config.json` so future
invocations can compare against it.

To force re-setup (e.g. after changing the rubric or solution), delete
`assignment/assistant_config.json`.

---

## Files changed

| File | Change |
|---|---|
| `R/oaii_grading_assistant.R` | Added `MODEL` constant; added `config_is_valid()`; updated `main()` to skip setup when valid config exists; stores `model` in config |
| `R/oaii_grading_assistant_runner.R` | Added `temperature = 0.1` to `start_run()` body; updated Roxygen |
| `docs/pipeline_comparison.md` | Updated table and trade-offs to reflect current state |
| `CLAUDE.md` | Updated Models section |

---

## Remaining intentional differences between pipelines

| Aspect | R | Python |
|---|---|---|
| API | Assistants v2 | Chat Completions |
| Context delivery | `file_search` retrieval | Inline with ephemeral caching |
| Output CSV | Single `Comments` column, UTF-8 BOM | Separate `Q*_feedback` columns, UTF-8 |

These differences are the subject of the comparison, not confounds to be
eliminated.
