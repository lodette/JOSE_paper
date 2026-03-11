"""
Unit tests for grade_student.py.

The OpenAI client is fully mocked so no real API calls are made.
Tests verify that grade_student_qmd:
  - returns a dict with the expected top-level keys
  - passes the configured model to the API
  - propagates FileNotFoundError for missing student files
"""
import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from grade_student import grade_student_qmd
from grading_context import MODEL

# ---------------------------------------------------------------------------
# Shared fixture data
# ---------------------------------------------------------------------------

_MOCK_PAYLOAD = {
    "questions": {
        f"Q{i}": {"grade": 3, "feedback": f"Feedback for Q{i}."}
        for i in range(1, 9)
    },
    "total": 24,
    "overall_comment": "Strong submission overall.",
}


def _make_mock_response(payload: dict) -> MagicMock:
    mock = MagicMock()
    mock.choices[0].message.content = json.dumps(payload)
    return mock


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_returns_dict(tmp_path):
    student = tmp_path / "2025-lab-9.qmd"
    student.write_text("# Submission", encoding="utf-8")

    with patch("grade_student.OpenAI") as MockOpenAI:
        MockOpenAI.return_value.chat.completions.create.return_value = (
            _make_mock_response(_MOCK_PAYLOAD)
        )
        result = grade_student_qmd(student)

    assert isinstance(result, dict)


def test_contains_required_top_level_keys(tmp_path):
    student = tmp_path / "2025-lab-9.qmd"
    student.write_text("# Submission", encoding="utf-8")

    with patch("grade_student.OpenAI") as MockOpenAI:
        MockOpenAI.return_value.chat.completions.create.return_value = (
            _make_mock_response(_MOCK_PAYLOAD)
        )
        result = grade_student_qmd(student)

    assert {"questions", "total", "overall_comment"} <= result.keys()


def test_total_matches_payload(tmp_path):
    student = tmp_path / "2025-lab-9.qmd"
    student.write_text("# Submission", encoding="utf-8")

    with patch("grade_student.OpenAI") as MockOpenAI:
        MockOpenAI.return_value.chat.completions.create.return_value = (
            _make_mock_response(_MOCK_PAYLOAD)
        )
        result = grade_student_qmd(student)

    assert result["total"] == 24


def test_calls_api_with_configured_model(tmp_path):
    student = tmp_path / "2025-lab-9.qmd"
    student.write_text("# Submission", encoding="utf-8")

    with patch("grade_student.OpenAI") as MockOpenAI:
        mock_client = MockOpenAI.return_value
        mock_client.chat.completions.create.return_value = (
            _make_mock_response(_MOCK_PAYLOAD)
        )
        grade_student_qmd(student)
        call_kwargs = mock_client.chat.completions.create.call_args.kwargs

    assert call_kwargs["model"] == MODEL


def test_enforces_json_response_format(tmp_path):
    student = tmp_path / "2025-lab-9.qmd"
    student.write_text("# Submission", encoding="utf-8")

    with patch("grade_student.OpenAI") as MockOpenAI:
        mock_client = MockOpenAI.return_value
        mock_client.chat.completions.create.return_value = (
            _make_mock_response(_MOCK_PAYLOAD)
        )
        grade_student_qmd(student)
        call_kwargs = mock_client.chat.completions.create.call_args.kwargs

    assert call_kwargs.get("response_format") == {"type": "json_object"}


def test_raises_file_not_found_for_missing_student():
    with pytest.raises(FileNotFoundError):
        grade_student_qmd(Path("/nonexistent/student.qmd"))
