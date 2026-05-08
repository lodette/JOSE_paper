# Claude Grading Pipeline: Technical Overview

The Claude grading pipeline automates the evaluation of student Quarto (`.qmd`)
lab submissions using the **Anthropic Messages API**. It is implemented across
three modules: `grading_context.py`, which manages all shared configuration and
grading materials; `grade_student.py`, which grades a single submission; and
`batch_grade.py`, which orchestrates batch processing across all students. No
prior setup step is required — the pipeline is stateless and self-contained per
run, mirroring the Python (OpenAI Chat Completions) pipeline in shape but
swapping the SDK and the structured-output mechanism.

## Context and Configuration

`grading_context.py` is the single authoritative source for environment
configuration. It calls `load_dotenv()` once on import, reads `BASE_LAB_DIR`
from the environment (raising a clear error if absent), and defines all shared
constants: `MODEL` (`claude-opus-4-7`), `MAX_TOKENS`, `Q_COUNT`, and resolved
file paths for the rubric JSON, starter template, instructor solution, and
grader instructions. `configure(lab_number)` sets the lab-specific paths in
module globals so the same process can grade multiple labs without restarting.

`build_system_blocks()` packages the grader instructions as a single text
content block tagged with `cache_control={"type": "ephemeral"}`, returned as a
list suitable for the `system` parameter of the Messages API. The list form is
required to attach a cache breakpoint; a plain string `system` cannot be
cached.

`build_cached_context_message()` loads the rubric, starter, and solution and
packs them as three text content blocks inside a single user message, each
tagged with `cache_control={"type": "ephemeral"}`. Anthropic supports up to
four cache breakpoints per request; using one breakpoint per file produces a
monotonically growing cached prefix and matches the per-file caching structure
of the Python/OpenAI pipeline.

`build_grade_tool()` defines the `submit_grade` tool whose `input_schema`
encodes the required output structure (`questions`, `total`,
`overall_comment`). Forced tool use is the Anthropic-recommended pattern for
schema-constrained JSON output and is the analogue of OpenAI's
`response_format={"type": "json_object"}`.

## Single-Student Grading

`grade_student.py` exposes a single function, `grade_student_qmd()`, which
accepts a path to a student's `.qmd` file and returns a parsed Python
dictionary. An `Anthropic` client is instantiated inside the function on each
call, keeping the module free of side effects at import time. The function
assembles the system blocks, a user message containing the cached
rubric/starter/solution, and a final user message containing the student
submission wrapped in `=== STUDENT_QMD_START/END ===` delimiters. It sends a
single synchronous request to `client.messages.create()` with
`tools=[submit_grade_tool]` and
`tool_choice={"type": "tool", "name": "submit_grade"}` to require a single tool
call. Sampling parameters (`temperature`, `top_p`, `top_k`) are intentionally
omitted: the Messages API on `claude-opus-4-7` rejects them. This is a
deliberate API-level difference from the Python/OpenAI pipeline (which uses
`temperature=0.1`); grading consistency in the Claude pipeline is delegated to
the rubric prompt, the cached shared context, and the schema-constrained tool
call. The model's tool-call `input` is returned directly — no JSON parsing step
is needed because the SDK already validates the input against the schema.

## Batch Processing and Output

`batch_grade.py` drives the full grading run. It is structurally identical to
the Python/OpenAI batch driver, accepting `--lab-number` on the command line,
walking the lab directory for student `.qmd` files, calling
`grade_student_qmd()` for each, and writing a UTF-8 CSV with per-question
grades, per-question feedback, a recomputed `Total` (the arithmetic sum of the
per-question grades, used in preference to the model's returned `total` to
guard against drift), and a `Model_Total` column carrying the model's own
total for diagnostic comparison. Per-student exceptions are caught and recorded
as error rows so a single failure does not abort the batch.

## Key Differences from the Python (OpenAI) Pipeline

| Aspect | Python (OpenAI) | Claude (Anthropic) |
|----|----|----|
| **SDK** | `openai` | `anthropic` |
| **API surface** | `client.chat.completions.create` | `client.messages.create` |
| **System prompt** | Message in the `messages` list | Top-level `system` parameter (string or list of blocks) |
| **Cache breakpoints** | One per cached message | Up to 4, attached to individual content blocks |
| **Structured output** | `response_format={"type": "json_object"}` (JSON mode) | Forced tool use with a schema-typed tool input |
| **Output extraction** | `json.loads(response.choices[0].message.content)` | Find the `tool_use` block and read `block.input` |
| **Schema validation** | Post-hoc (`json.loads` may fail) | Up-front (the SDK validates the tool input) |
