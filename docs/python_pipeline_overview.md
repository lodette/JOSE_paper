# Python Grading Pipeline: Technical Overview

The Python grading pipeline automates the evaluation of student Quarto (`.qmd`)
lab submissions using the OpenAI Chat Completions API. It is implemented across
three modules: `grading_context.py`, which manages all shared configuration and
grading materials; `grade_student.py`, which grades a single submission; and
`batch_grade.py`, which orchestrates batch processing across all students. No
prior setup step is required — the pipeline is stateless and self-contained per
run.

## Context and Configuration

`grading_context.py` is the single authoritative source for environment
configuration. It calls `load_dotenv()` once on import, reads `LAB_NUMBER` from
the environment (raising a clear error if absent), and defines all shared
constants: `MODEL`, `Q_COUNT` (the number of graded questions per lab), and
resolved file paths for the rubric JSON, starter template, instructor solution,
and grader instructions — all located in the `assignment/` directory except
`grader_instructions.txt`, which lives in `Python/`. The
`build_system_message()` function packages the grader instructions as an OpenAI
system message. `build_cached_context_messages()` loads the rubric, starter, and
solution as separate user messages each tagged with
`"cache_control": {"type": "ephemeral"}`, allowing the OpenAI API to reuse a
cached key-value representation of this shared prefix across the full batch of
student calls, reducing both latency and token cost.

## Single-Student Grading

`grade_student.py` exposes a single function, `grade_student_qmd()`, which
accepts a path to a student's `.qmd` file and returns a parsed Python
dictionary. An `OpenAI` client is instantiated inside the function on each call,
keeping the module free of side effects at import time. The function assembles
the full message list — system message, three cached context messages, and a
final user message containing the student submission wrapped in
`=== STUDENT_QMD_START/END ===` delimiters — and sends a single synchronous
request to the Chat Completions API using the `gpt-5.1` model.
`response_format={"type": "json_object"}` is set to enforce valid JSON output,
and `temperature=0.1` is used to minimise grading variability. The response is
parsed with `json.loads()` into a structured dictionary containing per-question
grades and feedback, a total, and an overall comment.

## Batch Processing and Output

`batch_grade.py` drives the full grading run. It imports `LAB_NUMBER` and
`Q_COUNT` directly from `grading_context.py` and reads `BASE_LAB_DIR` from the
environment, raising a clear error if it is absent. The script recursively
searches the lab directory for all matching student submission files, extracts
the student ID from the containing folder name, and calls `grade_student_qmd()`
for each. Each student is wrapped in a `try/except` block so that an API error
or unexpected response for one student writes an error row to the output and
allows the batch to continue. Results are flattened into rows and written to a
UTF-8 CSV file (`lab{N}_grades.csv`) with columns for the student ID,
per-question grades (`Q1`–`Q10`) and feedback, a total, and an overall comment.
Because each student is graded in an independent, stateless API call, the batch
can be resumed or rerun without any server-side cleanup.
