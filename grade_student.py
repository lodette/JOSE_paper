import json
from pathlib import Path
from openai import OpenAI
from grading_context import (
    MODEL,
    load_text,
    build_system_message,
    build_cached_context_messages,
    LAB_NUMBER,
)


def grade_student_qmd(student_qmd_path: Path) -> dict:
    """Grade a single student's ``.qmd`` submission using the Chat Completions API.

    Assembles a full message list consisting of the system message (grader
    instructions), three ephemerally-cached context messages (rubric, starter,
    solution), and a final user message containing the student submission
    wrapped in ``=== STUDENT_QMD_START/END ===`` delimiters. Sends a single
    synchronous request to the Chat Completions API with
    ``response_format={"type": "json_object"}`` to enforce valid JSON output
    and ``temperature=0.1`` to minimise grading variability.

    The returned dict conforms to the schema::

        {
            "questions": {
                "Q1": {"grade": <number>, "feedback": "<comment>"},
                ...
                "Q10": {"grade": <number>, "feedback": "<comment>"}
            },
            "total": <sum of all question grades>,
            "overall_comment": "<2-3 sentence summary>"
        }

    :param student_qmd_path: Absolute or relative path to the student's
        ``.qmd`` submission file.
    :type student_qmd_path: pathlib.Path
    :returns: Parsed JSON response from the model as a Python dictionary
        containing ``"questions"``, ``"total"``, and ``"overall_comment"``
        keys.
    :rtype: dict
    :raises FileNotFoundError: If *student_qmd_path* does not exist.
    :raises openai.OpenAIError: If the API call fails due to a network error,
        authentication failure, or rate limit.
    :raises json.JSONDecodeError: If the model returns malformed JSON despite
        the ``json_object`` response format constraint.
    """
    client = OpenAI()

    system_msg    = build_system_message()
    context_msgs  = build_cached_context_messages()
    student_text  = load_text(student_qmd_path)

    student_msg = {
        "role": "user",
        "content": [
            {
                "type": "text",
                "text": (
                    f"Here is a student's lab {LAB_NUMBER} .qmd file. "
                    "Using the rubric and templates already given above, "
                    "grade this file and return JSON only.\n\n"
                    "=== STUDENT_QMD_START ===\n"
                    f"{student_text}\n"
                    "=== STUDENT_QMD_END ==="
                ),
            }
        ],
    }

    messages = [system_msg] + context_msgs + [student_msg]

    response = client.chat.completions.create(
        model=MODEL,
        messages=messages,
        response_format={"type": "json_object"},
        temperature=0.1,
    )

    raw = response.choices[0].message.content
    return json.loads(raw)
