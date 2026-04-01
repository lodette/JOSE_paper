---
editor_options: 
  markdown: 
    wrap: 72
---

# Automated Grading Pipelines: Comparison

Three pipelines automate the LLM-based grading of student Quarto
(`.qmd`) lab submissions and produce a CSV of per-question grades and
feedback. They share the same high-level goal and the same grading
materials — a JSON rubric, an instructor solution, and a starter
template — but differ in which OpenAI API they target, how grading
context is delivered to the model, and how much infrastructure must be
in place before grading can begin.

The primary comparison in the JOSE paper is **Python vs R (Assistants
v2)**. The **R (Chat Completions)** pipeline is a direct R port of the
Python approach and serves to confirm that observed differences are
attributable to the API choice rather than the programming language.

## Structural Differences

| Aspect | Python | R — Chat Completions | R — Assistants v2 |
|----|----|----|----|
| **API** | Chat Completions (`POST /chat/completions`) | Chat Completions (`POST /chat/completions`) | Assistants v2 (`/assistants`, `/threads`, `/runs`) |
| **Entry script(s)** | `grading_context.py`, `grade_student.py`, `batch_grade.py` | `chat_grading_runner.R` | `oaii_grading_assistant.R`, `oaii_grading_assistant_runner.R` |
| **Execution model** | Synchronous — one HTTP call per student | Synchronous — one HTTP call per student | Asynchronous — thread created, run started, then polled |
| **Setup required** | None — stateless | None — stateless | One-time per assignment (file upload + assistant creation) |
| **Context delivery** | Rubric, solution, starter inlined in every request | Rubric, solution, starter inlined in every request | Files uploaded once; model retrieves chunks via `file_search` |
| **Caching** | Ephemeral prompt caching on the shared prefix | Ephemeral prompt caching on the shared prefix | Persistent file storage on OpenAI servers |
| **Structured output** | `response_format={"type": "json_object"}` | `response_format = list(type = "json_object")` | `response_format = list(type = "json_object")` on run object |
| **Output parsing** | `json.loads()` | `jsonlite::fromJSON()` | `jsonlite::fromJSON()` |
| **Temperature** | `0.1` | `0.1` | `0.1` |
| **Model** | `gpt-5.1` | `gpt-5.1` | `gpt-5.1` |
| **CSV encoding** | UTF-8 | UTF-8 | UTF-8 BOM (Excel compatible) |
| **Feedback columns** | Per-question (`Q1_feedback`, …) | Per-question (`Q1_feedback`, …) | Concatenated in a single `Comments` column |

## Trade-offs

**Python** and **R (Chat Completions)** are operationally equivalent —
no setup step, no server-side state, and every grading run is fully
self-contained. Ephemeral caching amortises the token cost of the shared
rubric and solution across the batch. The trade-off is context window
pressure: rubric, solution, starter, and student submission must all fit
within a single call.

**R (Assistants v2)** offloads grading materials to OpenAI's file
storage, keeping per-call payloads small. The setup phase runs once per
assignment and is skipped on subsequent runs if `assistant_config.json`
is present and matches the current model. The cost is operational
complexity: the two-script workflow and asynchronous polling require
more infrastructure than the Chat Completions pipelines.

All three pipelines use the same model (`gpt-5.1`), temperature (`0.1`),
and API-enforced JSON output (`response_format = json_object`). The
variables under study are therefore the API surface (Assistants v2 vs
Chat Completions) and context delivery mechanism (file retrieval vs
inline prompt).
