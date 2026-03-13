import os
import csv
from pathlib import Path

from grading_context import LAB_NUMBER, Q_COUNT
from grade_student import grade_student_qmd

BASE_LAB_DIR = os.getenv("BASE_LAB_DIR")
if BASE_LAB_DIR is None:
    raise ValueError(
        "Environment variable BASE_LAB_DIR is not set. "
        "Please define BASE_LAB_DIR in your .env file."
    )

# Root folder that contains all the student folders for this lab
BASE_DIR   = Path(BASE_LAB_DIR) / f"lab-{LAB_NUMBER}"
OUTPUT_CSV = BASE_DIR / f"lab{LAB_NUMBER}_grades.csv"

Q_COLS          = [f"Q{i}" for i in range(1, Q_COUNT + 1)]
Q_FEEDBACK_COLS = [f"Q{i}_feedback" for i in range(1, Q_COUNT + 1)]
FIELDNAMES      = ["Student", "Total", "OverallComment"] + Q_COLS + Q_FEEDBACK_COLS


def main():
    """Grade all student submissions for the configured lab and write results to CSV.

    Recursively searches :data:`BASE_DIR` for every file matching
    ``lab-{LAB_NUMBER}.qmd``, extracts the student ID from the
    containing folder name (the portion after the first underscore), and
    calls :func:`grade_student.grade_student_qmd` for each submission.
    Per-student exceptions are caught and recorded as an error row so that
    a single failure does not abort the batch.

    Results are written to :data:`OUTPUT_CSV` as a UTF-8 CSV with the
    following columns: ``Student``, ``Total``, ``OverallComment``,
    ``Q1``–``Q{Q_COUNT}``, and ``Q1_feedback``–``Q{Q_COUNT}_feedback``.
    Progress and any per-student errors are printed to stdout.

    :returns: None. Writes :data:`OUTPUT_CSV` as a side effect.
    :rtype: None
    :raises FileNotFoundError: If :data:`BASE_DIR` does not exist or
        contains no matching student submission files.
    """
    rows = []

    for path in sorted(BASE_DIR.rglob(f"lab-{LAB_NUMBER}.qmd")):
        student_folder = path.parent
        folder_name    = student_folder.name   # e.g. "lab-9_Ama8777"

        student_id = folder_name.split("_", 1)[1] if "_" in folder_name else folder_name
        print(f"Grading {student_id} from {path} ...")

        try:
            result    = grade_student_qmd(path)
            questions = result.get("questions", {})

            row = {
                "Student":        student_id,
                "Total":          result.get("total"),
                "OverallComment": result.get("overall_comment", ""),
            }
            for q in Q_COLS:
                qinfo    = questions.get(q, {})
                row[q]            = qinfo.get("grade")
                row[f"{q}_feedback"] = qinfo.get("feedback")

        except Exception as e:
            print(f"  ERROR grading {student_id}: {e}")
            row = {"Student": student_id, "Total": None, "OverallComment": f"Error: {e}"}
            for q in Q_COLS:
                row[q]            = None
                row[f"{q}_feedback"] = None

        rows.append(row)

    with OUTPUT_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Saved grades to {OUTPUT_CSV}")


if __name__ == "__main__":
    main()
