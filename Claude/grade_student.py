from pathlib import Path
from anthropic import Anthropic

import grading_context
from grading_context import (
    MODEL,
    MAX_TOKENS,
    load_text,
    build_system_blocks,
    build_cached_context_message,
    build_grade_tool,
)


def grade_student_qmd(student_qmd_path: Path) -> dict:
    """Grade a single student's ``.qmd`` submission using the Anthropic Messages API.

    Assembles a system parameter (grader instructions, cached), a single
    user message containing the rubric, starter, and solution as three
    ephemerally-cached content blocks, and a final user message holding
    the student submission wrapped in ``=== STUDENT_QMD_START/END ===``
    delimiters. Sends a single synchronous request to the Messages API
    with forced tool use on the ``submit_grade`` tool to guarantee the
    response conforms to the grading schema. Sampling parameters
    (``temperature``, ``top_p``, ``top_k``) are not used: they are
    rejected by Claude Opus 4.7. Grading consistency is delegated to the
    rubric prompt, the cached shared context, and the schema-constrained
    tool call.

    Forced tool use is the Anthropic-recommended pattern for
    schema-constrained JSON output and is the analogue of OpenAI's
    ``response_format={"type": "json_object"}`` used in the Python/OpenAI
    pipeline. The model's tool call ``input`` is returned directly without
    additional JSON parsing.

    The returned dict conforms to the schema::

        {
            "questions": {
                "Q1": {"grade": <number>, "feedback": "<comment>"},
                ...
                "QN": {"grade": <number>, "feedback": "<comment>"}
            },
            "total": <sum of all question grades>,
            "overall_comment": "<2-3 sentence summary>"
        }

    :param student_qmd_path: Absolute or relative path to the student's
        ``.qmd`` submission file.
    :type student_qmd_path: pathlib.Path
    :returns: The validated tool-call input as a Python dictionary
        containing ``"questions"``, ``"total"``, and ``"overall_comment"``
        keys.
    :rtype: dict
    :raises FileNotFoundError: If *student_qmd_path* does not exist.
    :raises anthropic.AnthropicError: If the API call fails due to a
        network error, authentication failure, or rate limit.
    :raises ValueError: If the model returns a response that does not
        contain a ``submit_grade`` tool call.
    """
    client = Anthropic()

    system_blocks = build_system_blocks()
    context_msg   = build_cached_context_message()
    student_text  = load_text(student_qmd_path)

    student_msg = {
        "role": "user",
        "content": [
            {
                "type": "text",
                "text": (
                    f"Here is a student's lab {grading_context.LAB_NUMBER} .qmd file. "
                    "Using the rubric and templates already given above, grade this "
                    "file by calling the submit_grade tool exactly once.\n\n"
                    "=== STUDENT_QMD_START ===\n"
                    f"{student_text}\n"
                    "=== STUDENT_QMD_END ==="
                ),
            }
        ],
    }

    response = client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        system=system_blocks,
        messages=[context_msg, student_msg],
        tools=[build_grade_tool()],
        tool_choice={"type": "tool", "name": "submit_grade"},
    )

    for block in response.content:
        if getattr(block, "type", None) == "tool_use" and block.name == "submit_grade":
            return block.input

    raise ValueError(
        "Model response did not contain a submit_grade tool_use block; "
        f"stop_reason={response.stop_reason!r}"
    )
