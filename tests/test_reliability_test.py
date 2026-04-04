"""
Unit tests for Python/reliability_test.py.

These tests mock the grading call so we can verify run-offset detection,
per-run error handling, and CSV append behaviour without making any API
requests.
"""
import csv

import grading_context
import reliability_test


def _make_student_submission(base_dir, folder_name: str, lab_number: int = 9):
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


def test_get_run_offset_returns_zero_for_missing_csv(tmp_path):
    assert reliability_test._get_run_offset(tmp_path / "missing.csv") == 0


def test_get_run_offset_returns_highest_existing_run_number(tmp_path):
    csv_path = tmp_path / "runs.csv"
    csv_path.write_text("Run,Total\n1,10\n3,11\n2,9\n", encoding="utf-8")

    assert reliability_test._get_run_offset(csv_path) == 3


def test_grade_n_times_records_error_rows_without_aborting(tmp_path, monkeypatch):
    student_path = tmp_path / "lab-9.qmd"
    student_path.write_text("# Submission", encoding="utf-8")

    calls = {"count": 0}

    def fake_grade_student_qmd(_path):
        calls["count"] += 1
        if calls["count"] == 2:
            raise RuntimeError("simulated API failure")
        return _mock_grade_payload(27)

    monkeypatch.setattr(reliability_test, "grade_student_qmd", fake_grade_student_qmd)

    rows = reliability_test.grade_n_times(student_path, n_runs=3, run_offset=4)

    assert [row["Run"] for row in rows] == [5, 6, 7]
    assert rows[0]["Total"] == 27
    assert rows[1]["Total"] is None
    assert rows[1]["OverallComment"] == "Error: simulated API failure"
    assert rows[2]["Total"] == 27


def test_main_appends_runs_with_continuous_numbering(tmp_path, monkeypatch):
    base_dir = tmp_path / "assignment"
    _make_student_submission(base_dir, "lab-9_student_alpha")

    monkeypatch.setattr(grading_context, "BASE_LAB_DIR", base_dir)
    monkeypatch.setattr(reliability_test.grading_context, "BASE_LAB_DIR", base_dir)
    monkeypatch.setattr(
        reliability_test,
        "grade_student_qmd",
        lambda _path: _mock_grade_payload(19),
    )

    reliability_test.main(n_runs=2, lab_number=9)
    reliability_test.main(n_runs=2, lab_number=9)

    output_csv = base_dir / "lab-9" / "lab-9_student_alpha_grades.csv"
    with output_csv.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    assert [row["Run"] for row in rows] == ["1", "2", "3", "4"]
    assert all(row["Total"] == "19" for row in rows)
    assert all(row["Q1_feedback"] == "Feedback for Q1" for row in rows)
