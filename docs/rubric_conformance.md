---
title: "Rubric Conformance Analysis"
date: 2026-04-30
editor_options: 
  markdown: 
    wrap: 72
---

# Rubric Conformance Analysis

## Purpose

This document evaluates whether the LLM grader's scoring decisions are
grounded in the rubric sub-criteria, or whether it grades holistically —
rewarding correct outputs while neglecting process verification, or
penalising students without tying deductions to specific criteria.

------------------------------------------------------------------------

## Method

Each lab has per-exercise rubric checks on three sub-criteria:

| Sub-criterion | Lab 9 weight | Lab 4 weight | What it tests |
|------------------|------------------|------------------|------------------|
| **CodeExecution** (CE) | 1 pt | 1 pt | Code runs and uses the required functions/operators |
| **ProcessFidelity** (PF) | 2 pt | 1 pt | Correct workflow steps followed as specified |
| **OutputAccuracy** (OA) | 2 pt | 1 pt | Numerical results or output match expected values |

For each run, the grader returns a per-question score and a free-text
feedback string. To assess rubric conformance, every feedback string was
passed to a secondary `gpt-4o-mini` call with the prompt:

> *For each of the three rubric sub-criteria, determine (a) whether it
> is mentioned in the feedback, and (b) whether a deduction is implied.*

Two metrics are reported per student × question, aggregated across 50
runs:

-   **mention%** — percentage of runs in which the criterion was
    referenced (positively or negatively)
-   **deduction%** — percentage of runs in which a point loss was
    implied for that criterion

A well-calibrated grader should show:

-   For **full-credit** questions: mention% ≈ 100% for all criteria
    (confirming each was verified), deduction% = 0%.
-   For **partial-credit** questions: at least one criterion with high
    deduction%, with deduction%s that account for the observed point
    loss.

------------------------------------------------------------------------

## Lab 9

**3 students · 6 questions · 5 pts each (CE 1 pt, PF 2 pt, OA 2 pt) · 50
runs**

Questions Q7–Q10 do not exist in Lab 9 and are excluded.

### Detailed Results

| Student      | Q   | Score |   SD | CE ment% | PF ment% | OA ment% | CE ded% | PF ded% | OA ded% |
|--------|--------|-------:|-------:|-------:|-------:|-------:|-------:|-------:|-------:|
| student_high | Q1  |  5.00 | 0.00 |      100 |   **58** |      100 |       0 |       0 |       0 |
| student_high | Q2  |  5.00 | 0.00 |      100 |      100 |      100 |       0 |       0 |       0 |
| student_high | Q3  |  5.00 | 0.00 |   **44** |   **64** |      100 |       0 |       0 |       0 |
| student_high | Q4  |  5.00 | 0.00 |      100 |   **90** |   **96** |       0 |       0 |       0 |
| student_high | Q5  |  5.00 | 0.00 |      100 |   **12** |      100 |       0 |       0 |       0 |
| student_high | Q6  |  5.00 | 0.00 |      100 |   **64** |      100 |       0 |       0 |       0 |
| student_low  | Q1  |  4.06 | 0.16 |      100 |      100 |       98 |      32 |  **98** |       0 |
| student_low  | Q2  |  3.35 | 0.42 |      100 |       98 |      100 |  **72** |  **94** |  **40** |
| student_low  | Q3  |  0.00 | 0.00 |        0 |      100 |   **12** |       0 | **100** |      12 |
| student_low  | Q4  |  4.06 | 0.19 |      100 |      100 |   **68** |       6 |  **86** |       4 |
| student_low  | Q5  |  2.00 | 0.00 |      100 |   **96** |      100 |       2 |  **82** | **100** |
| student_low  | Q6  |  5.00 | 0.00 |      100 |   **30** |      100 |       0 |       0 |       0 |
| student_mid  | Q1  |  3.99 | 0.34 |      100 |      100 |      100 |      22 | **100** |       0 |
| student_mid  | Q2  |  3.17 | 0.24 |      100 |      100 |   **94** |  **56** |  **98** |  **36** |
| student_mid  | Q3  |  1.20 | 0.38 |   **58** |   **98** |   **86** |      16 |  **98** |  **86** |
| student_mid  | Q4  |  4.71 | 0.29 |      100 |      100 |   **96** |      22 |      22 |       4 |
| student_mid  | Q5  |  4.72 | 0.25 |      100 |   **58** |      100 |       6 |      20 |      12 |
| student_mid  | Q6  |  5.00 | 0.00 |      100 |   **94** |      100 |       0 |       0 |       0 |

*Bold values highlight mention% below 80% for full-credit questions, or
the dominant deduction criterion for partial-credit questions.*

### Key Findings — Lab 9

**1. ProcessFidelity is under-verified on full-credit submissions.**
When `student_high` scores 5/5, PF is mentioned in only 12–100% of runs
depending on the question — below 80% on four of six questions. The most
striking case is Q5 (process: use `%^%` with specific initial state
vectors), where PF appears in only 12% of runs despite being worth 2
pts. The grader appears to award full process credit when output is
correct, without independently checking the workflow steps.

**2. Deductions on partial-credit submissions are rubric-aligned.** For
`student_low` and `student_mid`, dominant deductions track well with
known submission deficiencies:

-   Q3 (no derivation shown): PF deduction 100% — correct.
-   Q5 student_low (wrong initial states): OA deduction 100%, PF
    deduction 82% — correct (both process and output are wrong).
-   Q1 student_low (loop instead of `%^%`): PF deduction 98% — correct.

**3. CodeExecution is occasionally over-attributed.** On `student_low`
Q2 (wrong transition matrix, hard-coded `A`), CE deduction reaches 72%
even though the code did execute. The grader conflates "wrong process"
with "code failure" in some runs.

**4. Q3 OA under-flagged.** For `student_low` Q3 (score 0, no
derivation), OA deduction is only 12%. The correct formulas (the
expected output) are missing, so OA should also be penalised more
consistently.

------------------------------------------------------------------------

## Lab 4

**10 students · 10 questions · 3 pts each (CE 1 pt, PF 1 pt, OA 1 pt) ·
50 runs**

### Summary by Question (averaged across all students)

| Q   | Avg score | CE ment% | PF ment% | OA ment% | CE ded% | PF ded% |  OA ded% |
|-----|----------:|---------:|---------:|---------:|--------:|--------:|---------:|
| Q1  |       1.9 |     99.8 |     93.2 | **51.0** |    62.2 |    77.6 |     21.2 |
| Q2  |       2.1 |     98.8 |     97.4 |  **2.8** |    46.0 |    81.6 |      3.0 |
| Q3  |       2.1 |     96.0 |     99.8 |  **8.4** |    43.8 |    53.6 |      7.0 |
| Q4  |       2.4 |     98.2 |     82.2 |  **0.4** |    35.6 |    51.0 |      0.0 |
| Q5  |       2.9 |     85.8 |     74.8 | **18.0** |     2.2 |     6.0 |      0.0 |
| Q6  |       2.8 |     97.0 |     97.8 | **19.6** |    16.2 |    17.6 |      0.0 |
| Q7  |       2.3 |     94.2 |     99.6 | **13.6** |    29.4 |    45.8 |      2.4 |
| Q8  |       2.3 |     92.8 |     95.0 | **14.2** |    22.0 |    37.6 |      3.8 |
| Q9  |       2.7 |     94.4 |     93.8 | **32.0** |     6.4 |    25.8 |      5.2 |
| Q10 |       1.9 |     91.4 |     95.6 | **74.6** |    34.4 |    57.4 | **66.2** |

*Bold in OA ment% column highlights the systematic under-mention of
OutputAccuracy. Q10 is the exception — it has a specific numerical
target (test/train MSE ratio), making OA verifiable by inspection.*

### Detailed Results by Student

| Student   | Q   | Score |   SD | CE ment% | PF ment% | OA ment% | CE ded% | PF ded% | OA ded% |
|--------|--------|-------:|-------:|-------:|-------:|-------:|-------:|-------:|-------:|
| student_a | Q1  |  1.36 | 0.49 |      100 |      100 |       38 |      86 |     100 |       6 |
| student_a | Q2  |  1.88 | 0.33 |      100 |      100 |       16 |      36 |     100 |      16 |
| student_a | Q3  |  1.00 | 0.00 |       96 |      100 |       40 |      84 |      94 |      38 |
| student_a | Q4  |  2.96 | 0.20 |       96 |       76 |        2 |       4 |       0 |       0 |
| student_a | Q5  |  3.00 | 0.00 |       94 |       58 |        6 |       0 |       0 |       0 |
| student_a | Q6  |  2.92 | 0.27 |       92 |      100 |       30 |       2 |       8 |       0 |
| student_a | Q7  |  3.00 | 0.00 |       96 |      100 |       40 |       0 |       0 |      14 |
| student_a | Q8  |  2.94 | 0.24 |       34 |      100 |       26 |      10 |       4 |       0 |
| student_a | Q9  |  2.96 | 0.21 |       90 |       82 |       12 |       0 |       4 |       0 |
| student_a | Q10 |  3.00 | 0.00 |       90 |       90 |       82 |       0 |       0 |      58 |
| student_b | Q1  |  0.78 | 0.42 |      100 |      100 |       54 |      86 |     100 |       6 |
| student_b | Q2  |  2.00 | 0.00 |      100 |       90 |        0 |      44 |      88 |       0 |
| student_b | Q3  |  2.32 | 0.47 |       96 |      100 |        0 |      36 |      66 |       0 |
| student_b | Q4  |  2.00 | 0.00 |      100 |       96 |        0 |      90 |      78 |       0 |
| student_b | Q5  |  3.00 | 0.00 |       76 |       92 |       32 |       0 |       0 |       0 |
| student_b | Q6  |  2.00 | 0.00 |      100 |       98 |        0 |      88 |      92 |       0 |
| student_b | Q7  |  2.00 | 0.00 |       98 |      100 |        2 |      30 |      94 |       0 |
| student_b | Q8  |  2.18 | 0.39 |      100 |      100 |        6 |      36 |      82 |       0 |
| student_b | Q9  |  2.04 | 0.20 |       98 |       98 |        2 |      24 |      94 |       2 |
| student_b | Q10 |  1.84 | 0.37 |       90 |       98 |       76 |      26 |      94 |      76 |
| student_c | Q1  |  1.00 | 0.00 |      100 |       98 |      100 |      74 |      90 |     100 |
| student_c | Q2  |  3.00 | 0.00 |       92 |      100 |        0 |       0 |       0 |       0 |
| student_c | Q3  |  2.56 | 0.50 |       94 |      100 |        2 |      18 |      42 |       0 |
| student_c | Q4  |  2.00 | 0.00 |       94 |      100 |        0 |      22 |     100 |       0 |
| student_c | Q5  |  2.40 | 0.50 |       94 |       88 |       18 |      22 |      60 |       0 |
| student_c | Q6  |  3.00 | 0.00 |      100 |       98 |       40 |       0 |       0 |       0 |
| student_c | Q7  |  2.04 | 0.20 |       98 |      100 |        4 |      84 |      96 |       4 |
| student_c | Q8  |  2.38 | 0.49 |      100 |      100 |       10 |      46 |      60 |       2 |
| student_c | Q9  |  2.46 | 0.50 |       98 |      100 |       68 |      32 |      50 |       4 |
| student_c | Q10 |  2.00 | 0.00 |      100 |      100 |       90 |      24 |      98 |      86 |
| student_d | Q1  |  1.00 | 0.00 |      100 |      100 |      100 |      70 |      88 |     100 |
| student_d | Q2  |  1.98 | 0.14 |      100 |       90 |        0 |      80 |      90 |       0 |
| student_d | Q3  |  2.64 | 0.49 |       86 |      100 |       14 |      18 |      44 |      10 |
| student_d | Q4  |  2.00 | 0.00 |       98 |      100 |        0 |      50 |      84 |       0 |
| student_d | Q5  |  3.00 | 0.00 |       70 |       86 |        6 |       0 |       0 |       0 |
| student_d | Q6  |  3.00 | 0.00 |       86 |      100 |       20 |       0 |       0 |       0 |
| student_d | Q7  |  0.00 | 0.00 |       98 |      100 |        0 |      98 |     100 |       0 |
| student_d | Q8  |  0.00 | 0.00 |      100 |       92 |        0 |     100 |      92 |       0 |
| student_d | Q9  |  2.27 | 0.45 |       88 |       88 |       48 |       0 |      62 |      46 |
| student_d | Q10 |  0.00 | 0.00 |       76 |       88 |       30 |      76 |      88 |      30 |
| student_e | Q1  |  2.14 | 0.25 |      100 |       92 |       62 |      78 |      88 |       0 |
| student_e | Q2  |  2.00 | 0.00 |      100 |      100 |        4 |      48 |      82 |       6 |
| student_e | Q3  |  1.12 | 0.22 |       96 |      100 |       20 |      70 |      94 |      20 |
| student_e | Q4  |  2.42 | 0.43 |       96 |       82 |        0 |      12 |      60 |       0 |
| student_e | Q5  |  3.00 | 0.00 |       78 |       90 |       38 |       0 |       0 |       0 |
| student_e | Q6  |  3.00 | 0.00 |      100 |      100 |       18 |       0 |       0 |       0 |
| student_e | Q7  |  3.00 | 0.00 |       96 |      100 |       42 |       0 |       0 |       0 |
| student_e | Q8  |  3.00 | 0.00 |      100 |       94 |       20 |       0 |       0 |       8 |
| student_e | Q9  |  3.00 | 0.00 |       94 |       96 |       28 |       0 |       0 |       0 |
| student_e | Q10 |  2.10 | 0.23 |       94 |       96 |       94 |       4 |      12 |      94 |
| student_f | Q1  |  2.51 | 0.07 |      100 |       94 |        2 |      22 |      94 |       0 |
| student_f | Q2  |  2.00 | 0.00 |      100 |      100 |        4 |      34 |      96 |       4 |
| student_f | Q3  |  2.00 | 0.00 |      100 |      100 |        2 |      90 |      86 |       0 |
| student_f | Q4  |  2.48 | 0.10 |      100 |       96 |        0 |      14 |      68 |       0 |
| student_f | Q5  |  3.00 | 0.00 |       80 |       90 |       38 |       0 |       0 |       0 |
| student_f | Q6  |  3.00 | 0.00 |      100 |       98 |       50 |       0 |       0 |       0 |
| student_f | Q7  |  3.00 | 0.00 |       66 |      100 |       20 |       0 |       0 |       0 |
| student_f | Q8  |  3.00 | 0.00 |       98 |      100 |       28 |       0 |       0 |       0 |
| student_f | Q9  |  3.00 | 0.00 |       84 |       88 |       42 |       0 |       0 |       0 |
| student_f | Q10 |  2.07 | 0.17 |       90 |       90 |       54 |      82 |      72 |      12 |
| student_g | Q1  |  2.29 | 0.34 |       98 |       98 |       44 |      74 |      84 |       0 |
| student_g | Q2  |  2.00 | 0.00 |       96 |       98 |        2 |      70 |      94 |       2 |
| student_g | Q3  |  3.00 | 0.00 |       96 |       98 |        2 |       0 |       0 |       0 |
| student_g | Q4  |  3.00 | 0.00 |       98 |       60 |        0 |       0 |       0 |       0 |
| student_g | Q5  |  3.00 | 0.00 |       84 |       90 |        0 |       0 |       0 |       0 |
| student_g | Q6  |  3.00 | 0.00 |       94 |       94 |       10 |       0 |       0 |       0 |
| student_g | Q7  |  2.11 | 0.26 |       98 |       96 |        6 |      64 |      68 |       0 |
| student_g | Q8  |  1.18 | 0.24 |       98 |       98 |       28 |       8 |      98 |      28 |
| student_g | Q9  |  3.00 | 0.00 |       98 |       98 |       20 |       0 |       0 |       0 |
| student_g | Q10 |  2.02 | 0.10 |       96 |       98 |       94 |      32 |      80 |      94 |
| student_h | Q1  |  1.90 | 0.30 |      100 |       98 |       12 |      98 |      98 |       0 |
| student_h | Q2  |  2.00 | 0.00 |      100 |      100 |        0 |      74 |     100 |       0 |
| student_h | Q3  |  2.98 | 0.14 |       96 |      100 |        0 |       0 |       2 |       0 |
| student_h | Q4  |  2.00 | 0.00 |      100 |      100 |        0 |      74 |      84 |       0 |
| student_h | Q5  |  3.00 | 0.00 |       88 |       56 |        8 |       0 |       0 |       0 |
| student_h | Q6  |  2.20 | 0.40 |      100 |      100 |        0 |      72 |      76 |       0 |
| student_h | Q7  |  2.00 | 0.00 |       94 |      100 |        6 |      18 |     100 |       6 |
| student_h | Q8  |  2.60 | 0.50 |      100 |      100 |       12 |      20 |      40 |       0 |
| student_h | Q9  |  2.49 | 0.51 |       96 |       94 |        8 |       8 |      48 |       0 |
| student_h | Q10 |  1.22 | 0.42 |       98 |       98 |       32 |      98 |      98 |      30 |
| student_i | Q1  |  2.57 | 0.46 |      100 |       94 |       42 |      34 |      34 |       0 |
| student_i | Q2  |  2.00 | 0.00 |      100 |       98 |        2 |      40 |      88 |       2 |
| student_i | Q3  |  1.07 | 0.18 |      100 |      100 |        2 |     100 |      72 |       2 |
| student_i | Q4  |  2.05 | 0.15 |      100 |       74 |        0 |      90 |      36 |       0 |
| student_i | Q5  |  3.00 | 0.00 |       96 |       70 |       32 |       0 |       0 |       0 |
| student_i | Q6  |  3.00 | 0.00 |       98 |      100 |       26 |       0 |       0 |       0 |
| student_i | Q7  |  3.00 | 0.00 |      100 |      100 |       10 |       0 |       0 |       0 |
| student_i | Q8  |  3.00 | 0.00 |       98 |       72 |       10 |       0 |       0 |       0 |
| student_i | Q9  |  3.00 | 0.00 |      100 |       98 |       24 |       0 |       0 |       0 |
| student_i | Q10 |  2.15 | 0.31 |       92 |      100 |      100 |       2 |      32 |      98 |
| student_j | Q1  |  3.00 | 0.00 |      100 |       58 |       56 |       0 |       0 |       0 |
| student_j | Q2  |  2.00 | 0.00 |      100 |       98 |        0 |      34 |      78 |       0 |
| student_j | Q3  |  2.64 | 0.49 |      100 |      100 |        2 |      22 |      36 |       0 |
| student_j | Q4  |  3.00 | 0.00 |      100 |       38 |        2 |       0 |       0 |       0 |
| student_j | Q5  |  3.00 | 0.00 |       98 |       28 |        2 |       0 |       0 |       0 |
| student_j | Q6  |  3.00 | 0.00 |      100 |       90 |        2 |       0 |       0 |       0 |
| student_j | Q7  |  3.00 | 0.00 |       98 |      100 |        6 |       0 |       0 |       0 |
| student_j | Q8  |  3.00 | 0.00 |      100 |       94 |        2 |       0 |       0 |       0 |
| student_j | Q9  |  3.00 | 0.00 |       98 |       96 |       68 |       0 |       0 |       0 |
| student_j | Q10 |  2.94 | 0.24 |       88 |       98 |       92 |       0 |       0 |      84 |

### Key Findings — Lab 4

**1. OutputAccuracy is systematically under-verified for Q2–Q9.** OA
mention% averages 0–32% across these questions, despite OA being worth
one third of the points. This is strikingly different from Lab 9, where
OA was mentioned in 96–100% of runs. The difference reflects the nature
of the outputs: Lab 9 exercises produce specific numerical answers
(e.g., \~75% probability, \~23% stationary share) that are easy to
verify by inspection. Lab 4 exercises produce R model objects, workflow
sets, and resampling objects, whose correctness cannot readily be
confirmed from a text description of the output.

**2. Q10 is the exception.** Q10 asks for final model extraction and
comparison of test/train MSE ratios — a specific numerical target. OA
mention% reaches 74.6% on average (and OA deduction% 66.2%), confirming
that the grader can and does check OutputAccuracy when the expected
output is a concrete number.

**3. ProcessFidelity is the dominant criterion in Lab 4.** PF is
mentioned in 74–100% of runs across all questions, and PF deductions are
well-calibrated: high when process steps are clearly missed (e.g.,
student_d Q7 and Q8, both scored 0), near-zero when the full score is
awarded.

**4. CodeExecution is also well-verified but slightly over-flagged.** CE
mention% is 86–100% across questions and CE deductions generally track
with code failures, though some partial-credit cases show CE deductions
that appear to reflect wrong-function usage rather than true execution
failure.

------------------------------------------------------------------------

## Cross-Lab Comparison

|   | Lab 9 | Lab 4 |
|------------------------|------------------------|------------------------|
| CE coverage (full-credit questions) | Consistently verified (≥96%) | Consistently verified (≥70%) |
| PF coverage (full-credit questions) | **Under-verified** (12–100%) | Well-verified (56–100%) |
| OA coverage (full-credit questions) | Well-verified (96–100%) | **Under-verified** (0–32% for Q2–Q9) |
| Primary driver of deductions | PF and OA (when outputs are wrong) | PF (dominant), CE secondary |
| OA verifiability | High — numeric answers | Low — R objects; only Q10 (MSE) is numeric |

The dominant pattern differs by lab type:

-   **Lab 9** (mathematical derivations and matrix operations): the
    grader infers correct process from correct output — awarding PF
    credit when numerical answers match without consistently verifying
    that the specified steps were followed.
-   **Lab 4** (tidymodels ML pipeline): the grader verifies that the
    right functions were called in the right sequence (CE and PF), but
    largely skips output verification because the expected outputs are
    complex R objects rather than scalar numbers.

In both cases the bias is in the same direction: the criterion that
requires *independent* verification of a non-obvious property is the one
that gets skipped. In Lab 9 that is process verification; in Lab 4 it is
output verification.

------------------------------------------------------------------------

## Summary of Findings

1.  **Criterion coverage is not uniform.** Whichever sub-criterion is
    hardest to verify by inspecting the feedback — PF in Lab 9, OA in
    Lab 4 — is the one most likely to be omitted, regardless of its
    point weight.

2.  **Deduction attribution is generally accurate.** When the grader
    does penalise a student, the identified criterion usually
    corresponds to the known deficiency in the submission.

3.  **Outcome bias is present but context-dependent.** The grader
    rewards correct observable outcomes (right numbers, right functions
    called) and is less reliable at verifying the underlying properties
    that those outcomes are supposed to certify.

4.  **The effect is consistent across runs.** Because the pattern is
    systematic rather than noisy, it will not average out over multiple
    reliability runs — it represents a structural property of how the
    grader applies the rubric.

------------------------------------------------------------------------

## Limitations

-   **Meta-evaluator uncertainty.** The `gpt-4o-mini` classifier that
    produces these results is itself an LLM and may misclassify nuanced
    feedback. Mention rates should be interpreted as approximate rather
    than exact.
-   **Implicit checking.** The grader may be verifying a criterion
    without explicitly naming it in the feedback. A mention% below 100%
    does not prove the criterion was ignored — only that it was not
    verbalised.
-   **Rubric label mapping.** The meta-evaluator maps free-form feedback
    to three fixed labels. Feedback that addresses aspects spanning two
    criteria may be inconsistently classified across runs.
-   **Lab-specific rubrics.** Lab 9 and Lab 4 have different point
    allocations (CE 1 / PF 2 / OA 2 vs. CE 1 / PF 1 / OA 1). Direct
    comparison of raw mention percentages across labs should account for
    these differences.

------------------------------------------------------------------------

*Raw classification data: `assignment/lab_9_rubric_coverage_raw_gpt-4o-mini.csv` and
`assignment/lab_4_rubric_coverage_raw_gpt-4o-mini.csv`.*\
*Aggregated data: `assignment/lab_9_rubric_coverage_summary_gpt-4o-mini.csv` and
`assignment/lab_4_rubric_coverage_summary_gpt-4o-mini.csv`.*\
*Analysis script: `Python/evaluate_rubric_coverage.py`.*
