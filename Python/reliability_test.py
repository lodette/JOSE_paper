"""Reliability test for the Chat Completions grading pipeline (Python).

Runs ``grade_student_qmd()`` N times for every student submission and
writes one CSV per student with one row per run. Re-running appends to
existing CSVs with continuous run numbering, so 10 invocations of N=10
accumulate to 100 rows per student.

Output files are written beside the student submission folders::

    {BASE_DIR}/{folder_name}_grades.csv
    e.g. "lab-9_student_high_grades.csv"

Columns: ``Run``, ``Total``, ``OverallComment``,
``Q1``–``Q{Q_COUNT}``, ``Q1_feedback``–``Q{Q_COUNT}_feedback``.

Usage::

    python Python/reliability_test.py                    # lab 9, 10 runs (defaults)
    python Python/reliability_test.py --lab-number 4     # lab 4, 10 runs
    python Python/reliability_test.py -L 4 --n 25        # lab 4, 25 runs
"""

import argparse
import csv
import os
from pathlib import Path

import grading_context
from grade_student import grade_student_qmd

Q_COLS          = [f"Q{i}" for i in range(1, grading_context.Q_COUNT + 1)]
Q_FEEDBACK_COLS = [f"Q{i}_feedback" for i in range(1, grading_context.Q_COUNT + 1)]
FIELDNAMES      = ["Run", "Total", "OverallComment"] + Q_COLS + Q_FEEDBACK_COLS


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_run_offset(csv_path: Path) -> int:
    """Return the highest Run number already recorded in *csv_path*, or 0.

    Used to derive the starting offset for a new batch of runs so that
    run numbers continue from where a previous invocation left off.

    :param csv_path: Path to an existing per-student grades CSV.
    :type csv_path: pathlib.Path
    :returns: Maximum value of the ``Run`` column, or ``0`` if the file
        does not exist or contains no valid run numbers.
    :rtype: int
    """
    if not csv_path.exists():
        return 0
    with csv_path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        runs = []
        for row in reader:
            try:
                runs.append(int(row["Run"]))
            except (KeyError, ValueError):
                pass
    return max(runs, default=0)


def grade_n_times(student_path: Path, n_runs: int, run_offset: int) -> list[dict]:
    """Grade one student submission *n_runs* times and return a list of row dicts.

    Each dict contains a ``Run`` key (offset-adjusted) plus all grade and
    feedback fields. Per-run exceptions are caught and stored as error rows
    so a single API failure does not abort the student's batch.

    :param student_path: Path to the student's ``.qmd`` file.
    :type student_path: pathlib.Path
    :param n_runs: Number of grading runs to perform.
    :type n_runs: int
    :param run_offset: Added to each run index so numbering continues from
        the last row of an existing CSV.
    :type run_offset: int
    :returns: List of *n_runs* row dicts ready for :class:`csv.DictWriter`.
    :rtype: list[dict]
    """
    rows = []
    for i in range(1, n_runs + 1):
        run_number = run_offset + i
        print(f"  Run {run_number} ({i}/{n_runs}) ...")

        try:
            result    = grade_student_qmd(student_path)
            questions = result.get("questions", {})
            row = {
                "Run":            run_number,
                "Total":          result.get("total"),
                "OverallComment": result.get("overall_comment", ""),
            }
            for q in Q_COLS:
                qinfo         = questions.get(q, {})
                row[q]        = qinfo.get("grade")
                row[f"{q}_feedback"] = qinfo.get("feedback")

        except Exception as e:
            print(f"    ERROR on run {run_number}: {e}")
            row = {"Run": run_number, "Total": None,
                   "OverallComment": f"Error: {e}"}
            for q in Q_COLS:
                row[q]               = None
                row[f"{q}_feedback"] = None

        rows.append(row)
    return rows


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(n_runs: int = 10, lab_number: int = 9) -> None:
    """Run the reliability test across all student submissions.

    Calls :func:`grading_context.configure` to set lab-specific paths, then
    walks the lab submission folder for student submission files, grades each
    student :data:`n_runs` times, and writes (or appends to) a per-student
    CSV beside the submission folder.

    :param n_runs: Number of grading runs per student per invocation.
    :type n_runs: int
    :param lab_number: Lab number to test.
    :type lab_number: int
    :returns: None
    :rtype: None
    :raises FileNotFoundError: If the lab submission folder does not exist.
    """
    grading_context.configure(lab_number)
    base_dir = grading_context.BASE_LAB_DIR / f"lab-{lab_number}"

    student_paths = sorted(base_dir.rglob(f"lab-{lab_number}.qmd"))
    if not student_paths:
        raise FileNotFoundError(
            f"No lab-{lab_number}.qmd files found under {base_dir}"
        )

    print(f"Starting reliability test: {n_runs} runs x "
          f"{len(student_paths)} students\n")

    for path in student_paths:
        folder_name = path.parent.name          # e.g. "lab-9_student_high"
        output_csv  = base_dir / f"{folder_name}_grades.csv"

        run_offset  = _get_run_offset(output_csv)
        start, end  = run_offset + 1, run_offset + n_runs
        print(f"Grading {folder_name} (runs {start}–{end}) ...")

        rows = grade_n_times(path, n_runs, run_offset)

        write_header = not output_csv.exists()
        with output_csv.open("a", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
            if write_header:
                writer.writeheader()
            writer.writerows(rows)

        print(f"  Saved: {output_csv}\n")

    print("Reliability test complete.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Run the grading pipeline N times per student."
    )
    parser.add_argument(
        "--n", type=int, default=10,
        help="Number of grading runs per student (default: 10)"
    )
    parser.add_argument(
        "--lab-number", "-L",
        type=int,
        default=int(os.getenv("LAB_NUMBER", 9)),
        help="Lab number to test (default: %(default)s)",
    )
    args = parser.parse_args()
    main(n_runs=args.n, lab_number=args.lab_number)
