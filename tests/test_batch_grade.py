"""
Unit tests for batch_grade.py.

These tests mock the per-student grading call so we can verify folder
discovery, CSV writing, student ID extraction, and error-row handling
without making any API requests.
"""
import csv
from pathlib import Path

import batch_grade
import grading_context


def _make_student_submission(base_dir: Path, folder_name: str, lab_number: int = 9) -> Path:
    student_dir = base_dir / f"lab-{lab_number}" / folder_name
    student_dir.mkdir(parents=True)
    qmd_path = student_dir / f"lab-{lab_number}.qmd"
    qmd_path.write_text("# Submission", encoding="utf-8")
    return qmd_path


def _mock_grade_payload(total: int) -> dict:
    questions = {
        f"Q{i}": {"grade": i, "feedback": f"Feedback for Q{i}"}
        for i in range(1, grading_context.Q_COUNT + 1)
    }
    return {
        "questions": questions,
        "total": total,
        "overall_comment": "Mocked overall comment.",
    }


def test_main_writes_expected_csv_for_multiple_students(tmp_path, monkeypatch):
    base_dir = tmp_path / "assignment"
    _make_student_submission(base_dir, "lab-9_student_alpha")
    _make_student_submission(base_dir, "lab-9_student_beta")

    monkeypatch.setattr(grading_context, "BASE_LAB_DIR", base_dir)

    totals_by_file = {
        "lab-9_student_alpha": 55,
        "lab-9_student_beta": 42,
    }

    def fake_grade_student_qmd(path: Path) -> dict:
        return _mock_grade_payload(totals_by_file[path.parent.name])

    monkeypatch.setattr(batch_grade, "grade_student_qmd", fake_grade_student_qmd)

    batch_grade.main(9)

    output_csv = base_dir / "lab-9" / "lab9_grades.csv"
    assert output_csv.exists()

    with output_csv.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    assert [row["Student"] for row in rows] == ["student_alpha", "student_beta"]
    assert [row["Total"] for row in rows] == ["55", "42"]
    assert rows[0]["OverallComment"] == "Mocked overall comment."
    assert rows[0]["Q1"] == "1"
    assert rows[0]["Q10_feedback"] == "Feedback for Q10"


def test_main_records_error_row_when_student_grading_fails(tmp_path, monkeypatch):
    base_dir = tmp_path / "assignment"
    _make_student_submission(base_dir, "lab-9_student_alpha")
    _make_student_submission(base_dir, "lab-9_student_beta")

    monkeypatch.setattr(grading_context, "BASE_LAB_DIR", base_dir)

    def fake_grade_student_qmd(path: Path) -> dict:
        if path.parent.name == "lab-9_student_beta":
            raise RuntimeError("simulated API failure")
        return _mock_grade_payload(55)

    monkeypatch.setattr(batch_grade, "grade_student_qmd", fake_grade_student_qmd)

    batch_grade.main(9)

    output_csv = base_dir / "lab-9" / "lab9_grades.csv"
    with output_csv.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    error_row = next(row for row in rows if row["Student"] == "student_beta")
    assert error_row["Total"] == ""
    assert error_row["OverallComment"] == "Error: simulated API failure"
    assert error_row["Q1"] == ""
    assert error_row["Q10_feedback"] == ""
