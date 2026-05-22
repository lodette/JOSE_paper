---
editor_options: 
  markdown: 
    wrap: 72
---

# Automated Grading Pipelines: Comparison

Four pipelines automate the LLM-based grading of student Quarto (`.qmd`)
lab submissions and produce a CSV of per-question grades and feedback.
They share the same high-level goal and the same grading materials — a
JSON rubric, an instructor solution, and a starter template — but differ
in which API they target, how grading context is delivered to the model,
and how structured output is enforced.

The primary comparison in the JOSE paper is **Python vs R (Assistants
v2)**. The **R (Chat Completions)** pipeline is a direct R port of the
Python approach and serves to confirm that observed differences are
attributable to the API choice rather than the programming language. The
**Claude** pipeline is a parallel implementation using the Anthropic
Messages API and demonstrates portability of the approach across LLM
providers.

## Structural Differences

| Aspect | Python | Claude | R — Chat Completions | R — Assistants v2 |
|----|----|----|----|----|
| **API** | OpenAI Chat Completions | Anthropic Messages | OpenAI Chat Completions | OpenAI Assistants v2 |
| **SDK** | `openai` | `anthropic` | `httr2` | `httr2` (via `oaii` wrapper) |
| **Entry script(s)** | `grading_context.py`, `grade_student.py`, `batch_grade.py` | `grading_context.py`, `grade_student.py`, `batch_grade.py` | `chat_grading_runner.R` | `oaii_grading_assistant.R`, `oaii_grading_assistant_runner.R` |
| **Execution model** | Synchronous — one HTTP call per student | Synchronous — one HTTP call per student | Synchronous — one HTTP call per student | Asynchronous — thread created, run started, then polled |
| **Setup required** | None — stateless | None — stateless | None — stateless | One-time per assignment (file upload + assistant creation) |
| **Context delivery** | Rubric, solution, starter inlined in every request | Rubric, solution, starter inlined in every request | Rubric, solution, starter inlined in every request | Files uploaded once; model retrieves chunks via `file_search` |
| **Caching** | Ephemeral prompt caching on shared prefix | Ephemeral prompt caching (system blocks + 3 content blocks) | Ephemeral prompt caching on shared prefix | Persistent file storage on OpenAI servers |
| **Structured output** | `response_format={"type": "json_object"}` | Forced tool use (`tool_choice` + `submit_grade` JSON-schema tool) | `response_format = list(type = "json_object")` | `response_format = list(type = "json_object")` on run object |
| **Output parsing** | `json.loads()` | Tool-call `input` (pre-validated dict) | `jsonlite::fromJSON()` | `jsonlite::fromJSON()` |
| **Temperature** | `0.1` | n/a (not accepted by `claude-opus-4-7`) | `0.1` | `0.1` |
| **Model** | configurable via `LLM_MODEL` (default `gpt-5.1`) | `claude-opus-4-7` | configurable via `LLM_MODEL` (default `gpt-5.1`) | configurable via `LLM_MODEL` (default `gpt-5.1`) |
| **Local provider support** | Yes (`LLM_PROVIDER=local`) | No | Yes (`LLM_PROVIDER=local`) | No |
| **CSV encoding** | UTF-8 | UTF-8 | UTF-8 | UTF-8 BOM (Excel compatible) |
| **Feedback columns** | Per-question (`Q1_feedback`, …) | Per-question (`Q1_feedback`, …) | Per-question (`Q1_feedback`, …) | Concatenated in a single `Comments` column |

## Trade-offs

**Python** and **R (Chat Completions)** are operationally equivalent —
no setup step, no server-side state, and every grading run is fully
self-contained. Ephemeral caching amortises the token cost of the shared
rubric and solution across the batch. The trade-off is context window
pressure: rubric, solution, starter, and student submission must all fit
within a single call. Both support local inference via
`LLM_PROVIDER=local`.

**Claude** matches Python and R (Chat Completions) in execution model
and context delivery, but uses the Anthropic Messages API and the
`claude-opus-4-7` model. The key structural difference is how structured
output is enforced: rather than `response_format=json_object`, the
Claude pipeline uses forced tool use — a `submit_grade` tool with a JSON
Schema input definition — which means the response is a pre-validated
dict rather than a JSON string requiring parsing. Caching applies to
both the system instruction blocks and the per-file content blocks in
the user message. The Claude pipeline does not support local inference
providers.

**R (Assistants v2)** offloads grading materials to OpenAI's file
storage, keeping per-call payloads small. The setup phase runs once per
assignment and is skipped on subsequent runs if `assistant_config.json`
is present and matches the current model. The cost is operational
complexity: the two-script workflow and asynchronous polling require
more infrastructure than the Chat Completions pipelines, and the
pipeline is not portable to local providers or non-OpenAI APIs.

## Variables Under Study

The Python, Claude, and R (Chat Completions) pipelines isolate specific
dimensions for comparison:

- **Python vs R (Chat Completions):** same API, different language —
  confirms that reliability differences are attributable to API
  behaviour rather than implementation language.
- **Python vs Claude:** same execution model and context delivery,
  different provider — demonstrates portability and highlights
  provider-specific constraints (structured output mechanism,
  temperature handling, local inference support).
- **Python / R (Chat Completions) vs R (Assistants v2):** same language
  family, different API surface — the primary comparison in the JOSE
  paper, examining how context delivery mechanism affects grading
  reliability and operational complexity.
