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
    """
    Grade a single student's .qmd file and return a Python dict
    with the JSON structure:

    {
      "questions": {
        "Q1": { "grade": <number>, "feedback": "<comment>" },
        ...
        "Q10": { "grade": <number>, "feedback": "<comment>" }
      },
      "total": <sum of all question grades>,
      "overall_comment": "<2-3 sentence summary>"
    }

    Parameters
    ----------
    student_qmd_path : Path
        Absolute or relative path to the student's .qmd submission file.

    Returns
    -------
    dict
        Parsed JSON response from the model.
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
