#!/usr/bin/env python3
"""
summarize_criterion_coverage.py — Direct rubric criterion coverage summary.

For grader outputs that include per-criterion ``met``/``evidence`` fields
(Intervention B and later), coverage can be read directly from the grade
CSV without a secondary LLM meta-evaluation step.

Two metrics are reported per student × question, matching the column layout
of ``evaluate_rubric_coverage.py`` for direct comparison:

* **mention%** — percentage of runs in which the criterion block was present
  and non-null.  Will be ~100% for all criteria when the grader is required
  to fill in every block (Intervention B), confirming the structural fix
  worked.
* **deduction%** — percentage of runs in which the criterion was judged
  ``met: false``, implying a point loss.

Output:
    assignment/lab_{N}_rubric_coverage_summary_{grading_model}_direct.csv

Usage::

    python Python/summarize_criterion_coverage.py -n 4 --grading-model gpt-5.1_intervention-b
    python Python/summarize_criterion_coverage.py -n 9 --grading-model gpt-5.1_intervention-b -y
"""

import argparse
import json
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "Python"))
import grading_context  # noqa: E402

# Ordered criterion names: long form (in rubric/JSON) → short form (column suffix)
CRIT_MAP = {
    "CodeExecution":   "CE",
    "ProcessFidelity": "PF",
    "OutputAccuracy":  "OA",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def active_questions(rubric_path: Path) -> list[str]:
    """Return sorted question labels derived from the rubric JSON.

    :param rubric_path: Path to the lab rubric JSON file.
    :type rubric_path: pathlib.Path
    :returns: Sorted list of question labels (e.g. ``["Q1", "Q2", ...]``).
    :rtype: list[str]
    """
    with open(rubric_path, encoding="utf-8") as fh:
        rubric = json.loads(fh.read(), strict=False)
    return sorted(
        [f"Q{key[2:]}" for key in rubric if key.startswith("Ex")],
        key=lambda q: int(q[1:]),
    )


def _to_bool_series(series: pd.Series) -> pd.Series:
    """Normalise a Series that may contain Python booleans or their string
    representations (``"True"`` / ``"False"``) to a nullable boolean Series.

    :param series: Raw Series from :func:`pandas.read_csv`.
    :type series: pandas.Series
    :returns: Series of ``True`` / ``False`` / ``pd.NA``.
    :rtype: pandas.Series
    """
    mapping = {True: True, False: False,
               "True": True, "False": False,
               "true": True, "false": False}
    return series.map(mapping)


def summarize_student(csv_path: Path, questions: list[str]) -> list[dict]:
    """Read one per-student grade CSV and return one summary row per question.

    :param csv_path: Path to a per-student grades CSV containing
        ``Q{n}_CE_met``, ``Q{n}_PF_met``, and ``Q{n}_OA_met`` columns.
    :type csv_path: pathlib.Path
    :param questions: Ordered list of question labels to process.
    :type questions: list[str]
    :returns: List of summary row dicts, one per question.
    :rtype: list[dict]
    """
    df = pd.read_csv(csv_path)
    stem = csv_path.stem   # e.g. "lab-4_student_a_grades_gpt-5.1_intervention-b"

    grading_model = stem.split("_grades_", 1)[1] if "_grades_" in stem else "unknown"
    folder_part   = stem.split("_grades_")[0]      # e.g. "lab-4_student_a"
    student       = folder_part.split("_", 1)[1]   # e.g. "student_a"

    rows = []
    for q in questions:
        rec = {
            "grading_model": grading_model,
            "student":       student,
            "question":      q,
            "n_runs":        len(df),
            "mean_score":    round(df[q].mean(), 3) if q in df.columns else None,
            "score_sd":      round(df[q].std(),  3) if q in df.columns else None,
        }

        for full, short in CRIT_MAP.items():
            met_col = f"{q}_{short}_met"
            if met_col not in df.columns:
                rec[f"{full}_mention_pct"]   = None
                rec[f"{full}_deduction_pct"] = None
            else:
                met = _to_bool_series(df[met_col])
                rec[f"{full}_mention_pct"]   = round(met.notna().mean() * 100, 1)
                rec[f"{full}_deduction_pct"] = round((met == False).mean() * 100, 1)  # noqa: E712

        rows.append(rec)

    return rows


def print_table(summary_df: pd.DataFrame) -> None:
    """Print a formatted console table matching the style of
    :mod:`evaluate_rubric_coverage`.

    :param summary_df: Summary DataFrame with one row per
        grading_model × student × question.
    :type summary_df: pandas.DataFrame
    """
    sep = "─" * 90
    header = (
        f"{'Student':<18} {'Q':<5} {'Score':>6} {'SD':>5}  "
        f"{'CE':>5} {'PF':>5} {'OA':>5}  "
        f"{'CE-':>5} {'PF-':>5} {'OA-':>5}"
    )
    subhdr = (
        f"{'':<18} {'':<5} {'mean':>6} {'':>5}  "
        f"{'ment%':>5} {'ment%':>5} {'ment%':>5}  "
        f"{'ded%':>5} {'ded%':>5} {'ded%':>5}"
    )

    def fmt(v):
        return f"{v:>5.0f}" if (v is not None and not pd.isna(v)) else f"{'—':>5}"

    for model, grp in summary_df.groupby("grading_model"):
        print(f"\nGrading model: {model}")
        print(sep)
        print(header)
        print(subhdr)
        print(sep)
        for _, row in grp.iterrows():
            print(
                f"{row['student']:<18} {row['question']:<5} "
                f"{row['mean_score']:>6.2f} {row['score_sd']:>5.2f}  "
                f"{fmt(row['CodeExecution_mention_pct'])} "
                f"{fmt(row['ProcessFidelity_mention_pct'])} "
                f"{fmt(row['OutputAccuracy_mention_pct'])}  "
                f"{fmt(row['CodeExecution_deduction_pct'])} "
                f"{fmt(row['ProcessFidelity_deduction_pct'])} "
                f"{fmt(row['OutputAccuracy_deduction_pct'])}"
            )
        print(sep)
        print("CE = CodeExecution  |  PF = ProcessFidelity  |  OA = OutputAccuracy")
        print("ment% = % of runs with non-null met field  |  ded% = % of runs where met = false")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(lab_number: int, grading_model: str,
         output_dir: Path, yes: bool = False) -> None:
    """Summarise criterion coverage for one grading model's output CSVs.

    :param lab_number: Lab number to analyse.
    :type lab_number: int
    :param grading_model: Model slug used to filter grade CSV filenames
        (e.g. ``"gpt-5.1_intervention-b"``).
    :type grading_model: str
    :param output_dir: Directory where the summary CSV is written.
    :type output_dir: pathlib.Path
    :param yes: If ``True``, skip the confirmation prompt.
    :type yes: bool
    """
    grading_context.configure(lab_number)
    base_dir = grading_context.BASE_LAB_DIR / f"lab-{lab_number}"

    student_csvs = sorted(base_dir.glob(f"*_grades_{grading_model}.csv"))
    if not student_csvs:
        print(f"No files matching *_grades_{grading_model}.csv found in {base_dir}")
        sys.exit(1)

    questions = active_questions(grading_context.RUBRIC_PATH)

    print(f"Reading grades from : {base_dir}  (BASE_LAB_DIR/lab-{lab_number} — set in .env)")
    print(f"Grading model       : {grading_model}")
    print(f"Student file(s)     : {len(student_csvs)}")
    print(f"Questions           : {', '.join(questions)}")
    print("Coverage method     : direct (reads _CE_met / _PF_met / _OA_met columns)")
    print(f"Output directory    : {output_dir}")

    if not yes:
        print("\nProceed?\n  1. Yes\n  2. No")
        choice = input("> ").strip()
        if choice not in ("1", "y", "Y", "yes", "Yes"):
            print("Aborted.")
            sys.exit(0)

    all_rows = []
    for csv_path in student_csvs:
        all_rows.extend(summarize_student(csv_path, questions))

    summary_df = pd.DataFrame(all_rows)

    output_dir.mkdir(parents=True, exist_ok=True)
    slug     = grading_model.replace("/", "_").replace(" ", "_")
    out_path = output_dir / f"lab_{lab_number}_rubric_coverage_summary_{slug}_direct.csv"
    summary_df.to_csv(out_path, index=False)
    print(f"\nSummary → {out_path}")

    print_table(summary_df)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Summarise rubric criterion coverage directly from met/evidence fields."
    )
    parser.add_argument(
        "--lab-number", "-n", type=int, required=True,
        help="Lab number (e.g. 4 or 9)",
    )
    parser.add_argument(
        "--grading-model", required=True,
        help="Grading model slug to filter files (e.g. gpt-5.1_intervention-b)",
    )
    parser.add_argument(
        "--output-dir", type=Path,
        default=Path(__file__).resolve().parent.parent / "assignment",
        help="Directory for output CSV (default: assignment/)",
    )
    parser.add_argument(
        "--yes", "-y", action="store_true",
        help="Skip confirmation prompt",
    )
    args = parser.parse_args()
    main(
        lab_number=args.lab_number,
        grading_model=args.grading_model,
        output_dir=args.output_dir,
        yes=args.yes,
    )
