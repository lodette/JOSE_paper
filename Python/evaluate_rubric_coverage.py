#!/usr/bin/env python3
"""
evaluate_rubric_coverage.py — Phase 1 rubric conformance analysis.

Reads per-student per-run grade CSVs (produced by reliability_test.py) and
uses a lightweight LLM meta-evaluation call to classify which rubric
sub-criteria (CodeExecution, ProcessFidelity, OutputAccuracy) are referenced
in each per-question feedback string.

Produces two CSVs in the output directory:
  lab_{N}_rubric_coverage_raw_{grading_model}_meta_{meta_model}.csv
      — one row per (grading_model, student, run, question)
  lab_{N}_rubric_coverage_summary_{grading_model}_meta_{meta_model}.csv
      — aggregated mention/deduction rates per grading_model × student × question

When --grading-model is omitted all per-student CSVs in the lab folder are
processed together and "all" is used in place of the grading model in output
filenames.  The grading_model column in both CSVs always identifies which
grading model produced each row.

Usage:
    python Python/evaluate_rubric_coverage.py -n 9
    python Python/evaluate_rubric_coverage.py -n 9 --grading-model gpt-5.1
    python Python/evaluate_rubric_coverage.py -n 9 --grading-model qwen_qwen3.6-27b
    python Python/evaluate_rubric_coverage.py -n 9 --model gpt-4o-mini
    python Python/evaluate_rubric_coverage.py -n 9 --output-dir /tmp/results
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

import pandas as pd
from openai import OpenAI
from tqdm import tqdm

# ── project root ─────────────────────────────────────────────────────────────
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "Python"))
import grading_context  # noqa: E402  (also loads .env and sets BASE_LAB_DIR)

# ── constants ─────────────────────────────────────────────────────────────────
CRITERIA = ["CodeExecution", "ProcessFidelity", "OutputAccuracy"]
DEFAULT_MODEL = "gpt-4o-mini"
DEFAULT_OUTPUT_DIR = ROOT / "assignment"

# Phrases that flag a feedback string as a 'no exercise N' placeholder.
BOILERPLATE_PHRASES = [
    "no exercise",
    "no content",
    "no work",
    "not applicable",
    "does not exist",
    "no response",
    "no q",
    "not exist",
]

META_SYSTEM_PROMPT = """\
You are an expert grading auditor. Your task is to analyse a single grader
feedback comment for one student exercise and determine which rubric
sub-criteria were addressed.

Every exercise is graded on three sub-criteria:
  CodeExecution   – whether the student's code runs and uses the required
                    functions/operators
  ProcessFidelity – whether the student followed the correct workflow and
                    process steps specified in the rubric
  OutputAccuracy  – whether the student's numerical results or written output
                    match the expected answers

For each criterion respond with:
  "mentioned" : true if the criterion is referenced (even implicitly) in
                the feedback; false if it is not discussed at all
  "deducted"  : true if the feedback indicates points were (or should be)
                lost for that criterion; false if the criterion was met or
                not evaluated

Return ONLY valid JSON, exactly this structure — no prose, no markdown:
{
  "CodeExecution":   {"mentioned": <bool>, "deducted": <bool>},
  "ProcessFidelity": {"mentioned": <bool>, "deducted": <bool>},
  "OutputAccuracy":  {"mentioned": <bool>, "deducted": <bool>}
}\
"""


# ── helpers ───────────────────────────────────────────────────────────────────

def is_boilerplate(text: str) -> bool:
    """Return True if *text* is a placeholder comment (no real exercise content).

    :param text: Feedback string to test.
    :type text: str
    :returns: True when *text* matches a known placeholder phrase.
    :rtype: bool
    """
    lowered = text.lower()
    return any(phrase in lowered for phrase in BOILERPLATE_PHRASES)


def active_questions(rubric_path: Path) -> list[str]:
    """Return sorted question labels (e.g. ``['Q1', 'Q2', ...]``) from the rubric.

    Rubric keys for exercises are ``Ex1``, ``Ex2``, etc.; this maps them to the
    ``Q*`` column names used in the grade CSVs.

    :param rubric_path: Path to the lab rubric JSON file.
    :type rubric_path: Path
    :returns: Sorted list of question labels present in the rubric.
    :rtype: list[str]
    """
    with open(rubric_path, encoding="utf-8") as fh:
        rubric = json.load(fh)
    return sorted(
        [f"Q{key[2:]}" for key in rubric if key.startswith("Ex")],
        key=lambda q: int(q[1:]),
    )


def extract_student_label(csv_path: Path) -> str:
    """Derive a short human-readable label from a per-student CSV filename.

    Handles both plain and model-slug filename formats::

        lab-9_student_low_grades.csv                    →  student_low
        lab-9_student_mid_grades_qwen_qwen3.6-27b.csv   →  student_mid
        lab-4_student_b_grades.csv                      →  student_b

    :param csv_path: Path to the per-student grade CSV.
    :type csv_path: Path
    :returns: Label string starting at the ``student_`` token, ending before
              the ``_grades`` suffix.
    :rtype: str
    """
    stem = csv_path.stem  # e.g. 'lab-9_student_mid_grades_qwen_qwen3.6-27b'
    m = re.search(r"(student_.+?)_grades", stem)
    if m:
        return m.group(1)
    # fallback for unexpected format
    idx = stem.find("student_")
    return stem[idx:] if idx >= 0 else stem


def extract_grading_model(csv_path: Path) -> str:
    """Extract the grading-model slug from a per-student CSV filename.

    The slug is the portion of the stem that follows ``_grades_``::

        lab-9_student_mid_grades_gpt-5.1.csv            →  gpt-5.1
        lab-9_student_mid_grades_qwen_qwen3.6-27b.csv   →  qwen_qwen3.6-27b

    Returns ``"unknown"`` when no model suffix is present (old-format files).

    :param csv_path: Path to the per-student grade CSV.
    :type csv_path: Path
    :returns: Model slug string.
    :rtype: str
    """
    m = re.search(r"_grades_(.+)$", csv_path.stem)
    return m.group(1) if m else "unknown"


def classify_feedback(client: OpenAI, feedback: str, model: str) -> dict | None:
    """Call the LLM to classify which rubric criteria are addressed in *feedback*.

    Makes a single Chat Completions call with ``response_format="json_object"``
    and temperature 0 to ensure deterministic structured output.

    :param client: Initialised :class:`openai.OpenAI` client.
    :param feedback: The grader's feedback string for one exercise.
    :param model: Chat Completions model name (e.g. ``"gpt-4o-mini"``).
    :returns: Mapping of criterion name → ``{"mentioned": bool, "deducted": bool}``,
              or ``None`` if the API call or JSON parsing fails.
    :rtype: dict or None
    """
    try:
        response = client.chat.completions.create(
            model=model,
            temperature=0,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": META_SYSTEM_PROMPT},
                {"role": "user",   "content": f"Feedback:\n{feedback}"},
            ],
        )
        return json.loads(response.choices[0].message.content)
    except Exception as exc:
        print(f"  [warning] classify_feedback failed: {exc}", file=sys.stderr)
        return None


# ── main ──────────────────────────────────────────────────────────────────────

def main(lab_number: int, model: str, output_dir: Path,
         grading_model: str | None = None, yes: bool = False) -> None:
    """Run Phase 1 rubric coverage analysis for *lab_number*.

    Iterates over per-student reliability CSVs found in
    ``BASE_LAB_DIR/lab-{lab_number}/``.  When *grading_model* is supplied
    only CSVs whose filename slug matches are processed; otherwise all
    matching CSVs are processed together.  Each row in the output CSVs
    carries a ``grading_model`` column identifying which grading model
    produced the feedback.

    :param lab_number: Lab number to analyse (e.g. ``9``).
    :type lab_number: int
    :param model: OpenAI model for meta-evaluation calls.
    :type model: str
    :param output_dir: Directory in which to write output CSVs.
    :type output_dir: Path
    :param grading_model: If set, restrict input to CSVs whose model slug
        matches this string exactly.  ``None`` processes all CSVs.
    :type grading_model: str or None
    :param yes: When ``True``, skip the interactive confirmation prompt.
    :type yes: bool
    """
    grading_context.configure(lab_number)

    # Meta-evaluation always uses OpenAI directly (response_format=json_object
    # is required and is not supported by local providers without structured
    # output enabled).  Read OPENAI_API_KEY explicitly so that a local-provider
    # environment (LLM_PROVIDER=local) does not redirect these calls to LM Studio.
    api_key = os.environ.get("OPENAI_API_KEY", "")
    if not api_key:
        print("Error: OPENAI_API_KEY is not set (required for meta-evaluation).",
              file=sys.stderr)
        sys.exit(1)
    client = OpenAI(api_key=api_key)   # always routes to api.openai.com

    rubric_path = grading_context.RUBRIC_PATH
    if not rubric_path.exists():
        print(f"Error: rubric not found at {rubric_path}", file=sys.stderr)
        sys.exit(1)

    questions = active_questions(rubric_path)

    base_dir = grading_context.BASE_LAB_DIR / f"lab-{lab_number}"
    all_csvs = sorted(base_dir.glob("*student*grades*.csv"))
    if grading_model:
        student_csvs = [p for p in all_csvs
                        if extract_grading_model(p) == grading_model]
    else:
        student_csvs = all_csvs
    if not student_csvs:
        msg = (f"Error: no per-student grade CSVs"
               f"{f' for grading model {grading_model!r}' if grading_model else ''}"
               f" found in {base_dir}")
        print(msg, file=sys.stderr)
        sys.exit(1)

    found_models = sorted({extract_grading_model(p) for p in student_csvs})

    # Count rows up front so we can show a realistic API-call estimate
    dfs = {p: pd.read_csv(p) for p in student_csvs}
    est_calls = sum(len(df) * len(questions) for df in dfs.values())

    print(f"Reading grades from : {base_dir}  (BASE_LAB_DIR/lab-{lab_number} — set in .env)")
    print(f"Grading model(s)    : {', '.join(found_models)}")
    print(f"Student file(s)     : {len(student_csvs)}")
    print(f"Questions           : {', '.join(questions)}")
    print(f"Meta-eval model     : {model}")
    print(f"Estimated API calls : {est_calls} (upper bound)")
    print(f"Output directory    : {output_dir}")

    if not yes:
        print("\nProceed?")
        print("  1. Yes")
        print("  2. No")
        choice = input("> ").strip()
        if choice not in ("1", "y", "Y", "yes", "Yes"):
            print("Aborted.")
            sys.exit(0)
    print()

    raw_rows: list[dict] = []

    for csv_path, df in dfs.items():
        student_label       = extract_student_label(csv_path)
        grading_model_label = extract_grading_model(csv_path)

        for _, row in tqdm(df.iterrows(), total=len(df), desc=student_label):
            run_id = row.get("Run", row.get("Student", "?"))

            for q in questions:
                feedback_col = f"{q}_feedback"
                if feedback_col not in df.columns:
                    continue

                feedback = str(row.get(feedback_col, "")).strip()
                score    = row.get(q, None)

                if not feedback or is_boilerplate(feedback):
                    continue

                result = classify_feedback(client, feedback, model)
                if result is None:
                    continue

                rec: dict = {
                    "grading_model": grading_model_label,
                    "student":       student_label,
                    "run":           run_id,
                    "question":      q,
                    "score":         score,
                }
                for criterion in CRITERIA:
                    entry = result.get(criterion, {})
                    rec[f"{criterion}_mentioned"] = bool(entry.get("mentioned", False))
                    rec[f"{criterion}_deducted"]  = bool(entry.get("deducted",  False))

                raw_rows.append(rec)

    if not raw_rows:
        print("No feedback entries classified — nothing to write.", file=sys.stderr)
        sys.exit(1)

    raw_df = pd.DataFrame(raw_rows)

    output_dir.mkdir(parents=True, exist_ok=True)
    meta_slug    = re.sub(r"[ /]", "_", model)
    grading_slug = grading_model if grading_model else "all"
    raw_path = output_dir / (
        f"lab_{lab_number}_rubric_coverage_raw_{grading_slug}_meta_{meta_slug}.csv"
    )
    raw_df.to_csv(raw_path, index=False)
    print(f"\nRaw classifications  →  {raw_path}")

    # ── aggregate: mean rates per grading_model × student × question ───────
    agg_rows: list[dict] = []
    for (gm, student, question), grp in raw_df.groupby(
            ["grading_model", "student", "question"]):
        agg: dict = {
            "grading_model": gm,
            "student":       student,
            "question":      question,
            "n_runs":        len(grp),
            "mean_score":    round(grp["score"].mean(), 3),
            "score_sd":      round(grp["score"].std(),  3),
        }
        for criterion in CRITERIA:
            agg[f"{criterion}_mention_pct"]   = round(
                grp[f"{criterion}_mentioned"].mean() * 100, 1
            )
            agg[f"{criterion}_deduction_pct"] = round(
                grp[f"{criterion}_deducted"].mean() * 100, 1
            )
        agg_rows.append(agg)

    summary_df = pd.DataFrame(agg_rows)
    summary_path = output_dir / (
        f"lab_{lab_number}_rubric_coverage_summary_{grading_slug}_meta_{meta_slug}.csv"
    )
    summary_df.to_csv(summary_path, index=False)
    print(f"Summary              →  {summary_path}\n")

    # ── print human-readable table (one section per grading model) ───────────
    sep  = "─" * 94
    hdr1 = (f"{'Student':<18} {'Q':<4} {'Score':>6} {'SD':>5}  "
            f"{'CE':>5} {'PF':>5} {'OA':>5}   "
            f"{'CE-':>5} {'PF-':>5} {'OA-':>5}")
    hdr2 = (f"{'':18} {'':4} {'mean':>6} {'':>5}  "
            f"{'ment%':>5} {'ment%':>5} {'ment%':>5}   "
            f"{'ded%':>5} {'ded%':>5} {'ded%':>5}")

    for gm, gm_df in summary_df.groupby("grading_model"):
        print(f"\nGrading model: {gm}")
        print(sep)
        print(hdr1)
        print(hdr2)
        print(sep)
        prev_student = None
        for _, r in gm_df.iterrows():
            if prev_student and r["student"] != prev_student:
                print()  # blank line between students
            prev_student = r["student"]
            print(
                f"{r['student']:<18} {r['question']:<4} "
                f"{r['mean_score']:>6.2f} {r['score_sd']:>5.2f}  "
                f"{r['CodeExecution_mention_pct']:>5.0f} "
                f"{r['ProcessFidelity_mention_pct']:>5.0f} "
                f"{r['OutputAccuracy_mention_pct']:>5.0f}   "
                f"{r['CodeExecution_deduction_pct']:>5.0f} "
                f"{r['ProcessFidelity_deduction_pct']:>5.0f} "
                f"{r['OutputAccuracy_deduction_pct']:>5.0f}"
            )
        print(sep)

    print("CE = CodeExecution  |  PF = ProcessFidelity  |  OA = OutputAccuracy")
    print("ment% = % of runs mentioning criterion  |  ded% = % of runs deducting for it")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Evaluate rubric sub-criterion coverage in LLM grader feedback.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--lab-number", "-n",
        type=int, default=9,
        help="Lab number to analyse",
    )
    parser.add_argument(
        "--model",
        type=str, default=DEFAULT_MODEL,
        help="OpenAI model for meta-evaluation calls",
    )
    parser.add_argument(
        "--output-dir",
        type=str, default=str(DEFAULT_OUTPUT_DIR),
        help="Directory for output CSVs",
    )
    parser.add_argument(
        "--grading-model",
        type=str, default=None,
        help=(
            "Model slug to filter input CSVs (e.g. gpt-5.1 or "
            "qwen_qwen3.6-27b).  Must match the suffix in the filename "
            "exactly.  Omit to process all per-student CSVs together."
        ),
    )
    parser.add_argument(
        "--yes", "-y",
        action="store_true",
        help="Skip the interactive confirmation prompt (for scripted use).",
    )
    args = parser.parse_args()

    main(args.lab_number, args.model, Path(args.output_dir),
         args.grading_model, args.yes)
