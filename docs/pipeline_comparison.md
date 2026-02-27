# Automated Grading Pipeline: R vs Python Comparison

Both pipelines automate the LLM-based grading of student Quarto (`.qmd`) lab
submissions and produce a CSV of per-question grades and feedback. They share
the same high-level goal and the same grading materials — a JSON rubric,
an instructor solution, and a starter template — but differ fundamentally in
which OpenAI API they target, how grading context is delivered to the model,
and how much infrastructure must be in place before grading can begin.

## Structural Differences

| Aspect | Python | R |
|---|---|---|
| **API** | Chat Completions (`POST /chat/completions`) | Assistants v2 (`/assistants`, `/threads`, `/runs`) |
| **Execution model** | Synchronous — one HTTP call per student | Asynchronous — thread created, run started, then polled |
| **Setup required** | None — stateless, run directly | One-time setup script creates a persistent Assistant and uploads files |
| **Context delivery** | Full rubric, solution, and starter inlined in every request | Files uploaded once; model retrieves relevant chunks via `file_search` |
| **Caching** | Ephemeral prompt caching on the shared prefix | Persistent file storage on OpenAI servers |
| **Structured output** | Enforced via `response_format={"type": "json_object"}` | Requested via prompt only; no API-level enforcement |
| **Output parsing** | Single `json.loads()` call | Multi-schema defensive parser (`parse_reply_to_row`) |
| **Scripts** | 3 modules (`grading_context.py`, `grade_student.py`, `batch_grade.py`) | 2 scripts (`oaii_grading_assistant.R`, `oaii_grading_assistant_runner.R`) |
| **CSV encoding** | UTF-8 | UTF-8 BOM (Excel compatible) |

## Trade-offs

The Python pipeline is simpler to operate: there is no setup step, the full
grading context is always present verbatim in the prompt, and `response_format`
guarantees well-formed JSON. Ephemeral caching amortises the token cost of
the shared rubric and solution across the batch. The trade-off is context
window pressure — rubric, solution, starter, and student submission must all
fit within a single call — and a hard dependency on cache hit rates for cost
efficiency at scale.

The R pipeline offloads grading materials to OpenAI's file storage, keeping
per-call payloads small and enabling the same Assistant to serve repeated
grading sessions without re-uploading. The cost is operational complexity: the
two-script workflow, asynchronous polling, and the absence of structured output
enforcement mean the R code requires substantially more defensive logic —
particularly in `parse_reply_to_row`, which handles three possible JSON schemas
the model might return. Adopting `response_format` on the run object (available
in Assistants v2) would bring the R pipeline to parity with Python on output
reliability.
