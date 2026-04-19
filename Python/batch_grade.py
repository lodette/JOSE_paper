import argparse
import csv
import os

import grading_context
from grade_student import grade_student_qmd


def main(lab_number: int) -> None:
    """Grade all student submissions for the given lab and write results to CSV.

    Calls :func:`grading_context.configure` to set lab-specific paths, then
    recursively searches the lab submission folder for every file matching
    ``lab-{lab_number}.qmd``, extracts the student ID from the containing
    folder name (the portion after the first underscore), and calls
    :func:`grade_student.grade_student_qmd` for each submission.
    Per-student exceptions are caught and recorded as an error row so that
    a single failure does not abort the batch.

    Results are written to ``{BASE_LAB_DIR}/lab-{lab_number}/lab{lab_number}_grades.csv``
    as a UTF-8 CSV with columns: ``Student``, ``Total``, ``OverallComment``,
    ``Q1``–``Q{Q_COUNT}``, and ``Q1_feedback``–``Q{Q_COUNT}_feedback``.
    Progress and any per-student errors are printed to stdout.

    :param lab_number: Lab number to grade.
    :type lab_number: int
    :returns: None. Writes the output CSV as a side effect.
    :rtype: None
    :raises FileNotFoundError: If the lab submission folder does not exist or
        contains no matching student submission files.
    """
    grading_context.configure(lab_number)

    base_dir   = grading_context.BASE_LAB_DIR / f"lab-{lab_number}"
    output_csv = base_dir / f"lab{lab_number}_grades.csv"
    q_count    = grading_context.Q_COUNT

    q_cols          = [f"Q{i}" for i in range(1, q_count + 1)]
    q_feedback_cols = [f"Q{i}_feedback" for i in range(1, q_count + 1)]
    fieldnames      = ["Student", "Total", "Model_Total", "OverallComment"] + q_cols + q_feedback_cols

    rows = []

    for path in sorted(base_dir.rglob(f"lab-{lab_number}.qmd")):
        student_folder = path.parent
        folder_name    = student_folder.name   # e.g. "lab-9_Ama8777"

        student_id = folder_name.split("_", 1)[1] if "_" in folder_name else folder_name
        print(f"Grading {student_id} from {path} ...")

        try:
            result    = grade_student_qmd(path)
            questions = result.get("questions", {})

            row = {
                "Student":        student_id,
                "OverallComment": result.get("overall_comment", ""),
                "Model_Total":    result.get("total"),
            }
            for q in q_cols:
                qinfo             = questions.get(q, {})
                row[q]            = qinfo.get("grade")
                row[f"{q}_feedback"] = qinfo.get("feedback")

            # Recompute Total from per-question grades rather than trusting the
            # model-returned total, which can drift (see issue #11).
            row["Total"] = sum(row[q] for q in q_cols if isinstance(row[q], (int, float)))

        except Exception as e:
            print(f"  ERROR grading {student_id}: {e}")
            row = {"Student": student_id, "Total": None, "Model_Total": None,
                   "OverallComment": f"Error: {e}"}
            for q in q_cols:
                row[q]               = None
                row[f"{q}_feedback"] = None

        rows.append(row)

    with output_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Saved grades to {output_csv}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Grade all student submissions for a lab."
    )
    parser.add_argument(
        "--lab-number", "-n",
        type=int,
        default=int(os.getenv("LAB_NUMBER", 9)),
        help="Lab number to grade (default: %(default)s)",
    )
    args = parser.parse_args()
    main(args.lab_number)
