---
title: "Rubric Conformance Analysis"
date: 2026-05-15
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
|----|----|----|----|
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
|--------------|-----|------:|-----:|---------:|---------:|---------:|--------:|--------:|--------:|
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

**10 students · 10 questions · 3 pts each (CE 1 pt, PF 1 pt, OA 1 pt)**

Results are reported separately for gpt-5.1 (50 runs) and
qwen/qwen3.6-27b (50 runs).

### gpt-5.1 Results

#### Summary by Question (averaged across all students)

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

#### Detailed Results by Student

| Student   | Q   | Score |   SD | CE ment% | PF ment% | OA ment% | CE ded% | PF ded% | OA ded% |
|-----------|-----|------:|-----:|---------:|---------:|---------:|--------:|--------:|--------:|
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

### qwen/qwen3.6-27b Results

#### Summary by Question (averaged across all students)

| Q   | Avg score | CE ment% | PF ment% | OA ment% | CE ded% | PF ded% | OA ded% |
|-----|----------:|---------:|---------:|---------:|--------:|--------:|--------:|
| Q1  |       2.1 |     99.0 |  **37.0** |     69.8 |    48.4 |    36.8 |     26.4 |
| Q2  |       2.1 |     98.6 |  **57.4** | **45.6** |    26.6 |    34.2 |     60.4 |
| Q3  |       2.0 |     92.4 |     97.6 | **17.6** |    36.4 |    54.6 |     17.2 |
| Q4  |       3.0 |     98.8 |  **42.0** |  **1.8** |     0.2 |     0.0 |      0.0 |
| Q5  |       3.0 |     99.0 |  **18.8** | **27.4** |     0.2 |     0.0 |      0.2 |
| Q6  |       2.8 |     98.2 |     66.2 | **16.0** |     1.8 |    19.2 |      2.8 |
| Q7  |       2.3 |  **72.6** |     96.1 | **17.4** |    31.8 |    36.9 |     12.6 |
| Q8  |       2.1 |     87.2 |     77.8 | **13.0** |    18.0 |    45.6 |      5.6 |
| Q9  |       2.4 |     96.6 |  **51.9** | **36.8** |    10.2 |    31.3 |     15.8 |
| Q10 |       1.6 |  **78.4** |     95.0 |     61.8 |    45.8 |    72.0 |     42.4 |

*Bold PF ment% values highlight the new under-verification pattern (below
60%) compared to gpt-5.1. Bold OA ment% and CE ment% values mark the
same systematic under-mention found in gpt-5.1.*

#### Detailed Results by Student

| Student   | Q   | Score |   SD | CE ment% | PF ment% | OA ment% | CE ded% | PF ded% | OA ded% |
|-----------|-----|------:|-----:|---------:|---------:|---------:|--------:|--------:|--------:|
| student_a | Q1  |  1.98 | 0.14 |      100 |      100 |       94 |       0 |     100 |      64 |
| student_a | Q2  |  2.00 | 0.00 |      100 |       48 |      100 |       0 |      48 |     100 |
| student_a | Q3  |  1.00 | 0.00 |      100 |      100 |       96 |       0 |     100 |      96 |
| student_a | Q4  |  3.00 | 0.00 |      100 |       98 |       12 |       0 |       0 |       0 |
| student_a | Q5  |  3.00 | 0.00 |      100 |       24 |       32 |       0 |       0 |       0 |
| student_a | Q6  |  3.00 | 0.00 |      100 |       56 |       16 |       0 |       0 |       0 |
| student_a | Q7  |  2.92 | 0.27 |       96 |      100 |       32 |       0 |       4 |      20 |
| student_a | Q8  |  2.96 | 0.20 |      100 |       96 |       16 |       0 |       4 |       4 |
| student_a | Q9  |  2.98 | 0.14 |      100 |       42 |       22 |       0 |       0 |       2 |
| student_a | Q10 |  2.44 | 0.54 |       86 |       96 |       92 |       6 |      36 |      44 |
| student_b | Q1  |  2.00 | 0.00 |      100 |       50 |       22 |     100 |      50 |       0 |
| student_b | Q2  |  2.00 | 0.00 |      100 |       34 |       40 |      60 |      12 |      40 |
| student_b | Q3  |  2.92 | 0.27 |      100 |      100 |        4 |       8 |       8 |       4 |
| student_b | Q4  |  3.00 | 0.00 |      100 |        2 |        0 |       0 |       0 |       0 |
| student_b | Q5  |  3.00 | 0.00 |      100 |        2 |        0 |       0 |       0 |       0 |
| student_b | Q6  |  2.00 | 0.00 |       96 |      100 |       24 |      14 |      96 |      24 |
| student_b | Q7  |  1.80 | 0.40 |       90 |       98 |       20 |      78 |      74 |      20 |
| student_b | Q8  |  1.00 | 0.00 |       86 |      100 |        2 |      40 |     100 |       2 |
| student_b | Q9  |  1.22 | 0.42 |       98 |       94 |       16 |      58 |      94 |      16 |
| student_b | Q10 |  0.98 | 0.14 |       92 |      100 |       54 |      88 |     100 |      54 |
| student_c | Q1  |  2.00 | 0.00 |      100 |        4 |      100 |       6 |       4 |     100 |
| student_c | Q2  |  3.00 | 0.00 |      100 |      100 |        0 |       0 |       0 |       0 |
| student_c | Q3  |  2.32 | 0.47 |       80 |      100 |       16 |      44 |      60 |      12 |
| student_c | Q4  |  3.00 | 0.00 |      100 |       24 |        0 |       0 |       0 |       0 |
| student_c | Q5  |  3.00 | 0.00 |      100 |        2 |       16 |       0 |       0 |       0 |
| student_c | Q6  |  3.00 | 0.00 |      100 |       96 |        0 |       0 |       0 |       0 |
| student_c | Q7  |  2.00 | 0.00 |       64 |      100 |       28 |      46 |     100 |      28 |
| student_c | Q8  |  2.04 | 0.20 |       86 |      100 |       10 |      12 |      96 |       6 |
| student_c | Q9  |  2.24 | 0.43 |       98 |       94 |       20 |       8 |      74 |      14 |
| student_c | Q10 |  1.12 | 0.33 |       52 |      100 |       50 |      30 |     100 |      46 |
| student_d | Q1  |  1.98 | 0.14 |      100 |        0 |      100 |       2 |       0 |     100 |
| student_d | Q2  |  2.00 | 0.00 |       98 |      100 |       14 |       2 |      98 |      90 |
| student_d | Q3  |  1.24 | 0.43 |       80 |       94 |       26 |      72 |      92 |      26 |
| student_d | Q4  |  2.98 | 0.14 |      100 |       70 |        2 |       2 |       0 |       0 |
| student_d | Q5  |  3.00 | 0.00 |      100 |       58 |       54 |       2 |       0 |       0 |
| student_d | Q6  |  2.98 | 0.14 |      100 |       62 |       54 |       2 |       0 |       0 |
| student_d | Q7  |  0.00 | 0.00 |      100 |       81 |        4 |     100 |      81 |       4 |
| student_d | Q8  |  0.00 | 0.00 |      100 |       62 |        6 |     100 |      62 |       6 |
| student_d | Q9  |  1.14 | 0.79 |      100 |       51 |       76 |      14 |      49 |      76 |
| student_d | Q10 |  0.00 | 0.00 |       98 |       70 |        0 |     100 |      70 |       0 |
| student_e | Q1  |  2.00 | 0.00 |      100 |       32 |       92 |      96 |      32 |       0 |
| student_e | Q2  |  2.00 | 0.00 |      100 |       52 |       42 |      56 |      28 |      42 |
| student_e | Q3  |  1.00 | 0.00 |       88 |      100 |        8 |      66 |      94 |       8 |
| student_e | Q4  |  3.00 | 0.00 |      100 |       98 |        0 |       0 |       0 |       0 |
| student_e | Q5  |  3.00 | 0.00 |      100 |       26 |       82 |       0 |       0 |       2 |
| student_e | Q6  |  3.00 | 0.00 |      100 |       90 |       38 |       0 |       0 |       0 |
| student_e | Q7  |  3.00 | 0.00 |       78 |       98 |       20 |       0 |       0 |       0 |
| student_e | Q8  |  3.00 | 0.00 |       94 |       98 |       32 |       0 |       2 |      14 |
| student_e | Q9  |  3.00 | 0.00 |      100 |       32 |       90 |       0 |       0 |      34 |
| student_e | Q10 |  1.18 | 0.39 |       92 |       94 |       90 |      60 |      84 |      90 |
| student_f | Q1  |  2.00 | 0.00 |      100 |       46 |       72 |      94 |      44 |       0 |
| student_f | Q2  |  2.00 | 0.00 |      100 |       58 |       16 |      80 |      56 |      16 |
| student_f | Q3  |  1.16 | 0.37 |       96 |       96 |       10 |      80 |      94 |      10 |
| student_f | Q4  |  3.00 | 0.00 |       98 |       48 |        4 |       0 |       0 |       0 |
| student_f | Q5  |  3.00 | 0.00 |      100 |       22 |       28 |       0 |       0 |       0 |
| student_f | Q6  |  3.00 | 0.00 |      100 |       40 |       12 |       0 |       0 |       0 |
| student_f | Q7  |  2.98 | 0.14 |       78 |       98 |       10 |       2 |       4 |       0 |
| student_f | Q8  |  3.00 | 0.00 |       98 |       78 |       10 |       0 |       0 |       0 |
| student_f | Q9  |  3.00 | 0.00 |      100 |       76 |       82 |       0 |       0 |       0 |
| student_f | Q10 |  2.00 | 0.00 |       80 |      100 |       34 |      56 |      92 |      10 |
| student_g | Q1  |  2.00 | 0.00 |       92 |        0 |       28 |      92 |       0 |       0 |
| student_g | Q2  |  2.00 | 0.00 |       92 |       48 |       52 |      40 |       4 |      52 |
| student_g | Q3  |  3.00 | 0.00 |       82 |       92 |        0 |       0 |       0 |       0 |
| student_g | Q4  |  3.00 | 0.00 |       92 |       12 |        0 |       0 |       0 |       0 |
| student_g | Q5  |  3.00 | 0.00 |       92 |        2 |        2 |       0 |       0 |       0 |
| student_g | Q6  |  3.00 | 0.00 |       92 |       88 |        2 |       0 |       0 |       0 |
| student_g | Q7  |  2.65 | 0.48 |       86 |       92 |        8 |      54 |      18 |       8 |
| student_g | Q8  |  1.65 | 0.48 |       64 |       92 |       22 |       0 |      92 |       0 |
| student_g | Q9  |  3.00 | 0.00 |       92 |       10 |        2 |       0 |       0 |       0 |
| student_g | Q10 |  2.02 | 0.15 |       62 |       92 |       52 |      42 |      68 |      38 |
| student_h | Q1  |  2.00 | 0.00 |      100 |       84 |       14 |      18 |      84 |       0 |
| student_h | Q2  |  2.00 | 0.00 |       98 |       94 |       20 |       4 |      82 |      92 |
| student_h | Q3  |  2.94 | 0.24 |      100 |      100 |        0 |       6 |       6 |       0 |
| student_h | Q4  |  3.00 | 0.00 |      100 |        2 |        0 |       0 |       0 |       0 |
| student_h | Q5  |  3.00 | 0.00 |      100 |       36 |       48 |       0 |       0 |       0 |
| student_h | Q6  |  2.02 | 0.14 |       96 |       96 |        4 |       2 |      96 |       4 |
| student_h | Q7  |  1.80 | 0.40 |       54 |       98 |       44 |      38 |      88 |      46 |
| student_h | Q8  |  1.00 | 0.00 |       46 |      100 |       24 |      28 |     100 |      24 |
| student_h | Q9  |  1.36 | 0.48 |       80 |       96 |       18 |      22 |      96 |      16 |
| student_h | Q10 |  0.98 | 0.14 |       72 |      100 |       52 |      56 |     100 |      48 |
| student_i | Q1  |  2.00 | 0.00 |       98 |       54 |       76 |      76 |      54 |       0 |
| student_i | Q2  |  2.00 | 0.00 |       98 |       36 |       72 |      24 |      12 |      72 |
| student_i | Q3  |  1.00 | 0.00 |       98 |       94 |       16 |      88 |      92 |      16 |
| student_i | Q4  |  3.00 | 0.00 |       98 |       40 |        0 |       0 |       0 |       0 |
| student_i | Q5  |  3.00 | 0.00 |       98 |       16 |       12 |       0 |       0 |       0 |
| student_i | Q6  |  3.00 | 0.00 |       98 |       34 |       10 |       0 |       0 |       0 |
| student_i | Q7  |  3.00 | 0.00 |       36 |       96 |        8 |       0 |       0 |       0 |
| student_i | Q8  |  3.00 | 0.00 |       98 |       50 |        8 |       0 |       0 |       0 |
| student_i | Q9  |  3.00 | 0.00 |       98 |       20 |       10 |       0 |       0 |       0 |
| student_i | Q10 |  2.00 | 0.00 |       50 |       98 |       94 |      20 |      70 |      94 |
| student_j | Q1  |  3.00 | 0.00 |      100 |        0 |      100 |       0 |       0 |       0 |
| student_j | Q2  |  2.00 | 0.00 |      100 |        4 |      100 |       0 |       2 |     100 |
| student_j | Q3  |  3.00 | 0.00 |      100 |      100 |        0 |       0 |       0 |       0 |
| student_j | Q4  |  3.00 | 0.00 |      100 |       26 |        0 |       0 |       0 |       0 |
| student_j | Q5  |  3.00 | 0.00 |      100 |        0 |        0 |       0 |       0 |       0 |
| student_j | Q6  |  3.00 | 0.00 |      100 |        0 |        0 |       0 |       0 |       0 |
| student_j | Q7  |  3.00 | 0.00 |       44 |      100 |        0 |       0 |       0 |       0 |
| student_j | Q8  |  3.00 | 0.00 |      100 |        2 |        0 |       0 |       0 |       0 |
| student_j | Q9  |  3.00 | 0.00 |      100 |        4 |       32 |       0 |       0 |       0 |
| student_j | Q10 |  3.00 | 0.00 |      100 |      100 |      100 |       0 |       0 |       0 |

------------------------------------------------------------------------

### Key Findings — Lab 4

#### Findings consistent across both models

**1. OutputAccuracy is systematically under-verified for Q2–Q9.** OA
mention% averages 0–32% (gpt-5.1) and 2–37% (qwen) across these
questions, despite OA being worth one third of the points. The pattern
is structurally identical across both models. The difference from Lab 9
reflects the nature of the outputs: Lab 9 exercises produce specific
numerical answers that are easy to verify by inspection, while Lab 4
exercises produce R model objects and workflow sets whose correctness
cannot readily be confirmed from a text description.

**2. Q10 is the exception for both models.** Q10 asks for final model
extraction and comparison of test/train MSE ratios — a specific
numerical target. OA mention% reaches 74.6% (gpt-5.1) and 61.8%
(qwen), confirming that both models check OutputAccuracy when the
expected output is a concrete number.

**3. Deduction attribution is well-calibrated for both models.** When
either grader penalises a student, the identified criterion corresponds
to the known deficiency: student_d Q7 and Q8 (both scored 0) attract
near-100% CE and PF deductions from both models.

#### New finding: ProcessFidelity under-verification with qwen

**4. qwen substantially under-verifies ProcessFidelity in Lab 4.** With
gpt-5.1, PF is mentioned in 74–100% of runs across all questions — the
dominant and well-verified criterion. With qwen, PF mention% drops to
19–66% on six of ten questions (Q1, Q2, Q4, Q5, Q6, Q9), with Q5
falling to just 19%. This mirrors the PF under-verification finding from
Lab 9 (where qwen PF mention% on full-credit runs averaged 39% vs 65%
for gpt-5.1) and suggests qwen systematically skips process verification
more than gpt-5.1 across both lab types.

**5. CodeExecution coverage is similar but qwen drops on Q7 and Q10.**
gpt-5.1 CE mention% is 86–100% across questions. qwen CE mention% is
comparable for most questions but falls to 72.6% on Q7 and 78.4% on
Q10, suggesting slightly weaker code-execution checking on the more
complex later exercises.

------------------------------------------------------------------------

## Interventions to Improve Rubric Conformance

### Motivation

The Lab 4 baseline results documented a structural gap: OutputAccuracy was
mentioned in only 0–32% of grading runs for Q2–Q9, despite accounting for one
third of each question's points. The cause is that Lab 4 exercises produce
complex R objects — fitted workflows, recipe objects, tuned model specifications
— whose correctness cannot be verified by reading source code alone. The
baseline grader was awarding OA credit by default whenever CodeExecution and
ProcessFidelity criteria were met.

A series of prompt interventions was developed to address this, evaluated on the
Lab 4 gpt-5.1 results (10 students, 50 runs per intervention).

### Intervention A: Structured Sub-criterion Output

The first intervention required the grader to produce a `{met, evidence}` block
for each sub-criterion before assigning a grade. Explicitly attesting every
criterion in the output substantially raised OA mention rates; subsequent
interventions built on this format.

### Intervention B: Inline OA Verification Instruction

The second intervention added an explicit instruction to `grader_instructions.txt`
directing the grader to verify OutputAccuracy independently of the other two
criteria, even when the expected output is a complex R object. OA mention%
reached ≈ 100% across all questions. Mean per-question scores shifted slightly
downward (avg ≈ 1.62/3 vs baseline), and score variability increased modestly on
questions where student code was partially correct (Q8 SD = 0.227;
Q9 SD = 0.377).

### Intervention C: Formalised OA Proxy in Rubric Schema

The third intervention introduced an `OA_proxy` field to the rubric JSON schema.
For exercises whose expected output is a complex R object, the rubric includes a
single source-checkable proxy condition that the grader uses as its primary OA
check. Example proxies:

-   Q3: "Check that `recipes::recipe(` is called with formula
    `Sale_Price ~ Longitude + Latitude + Lot_Area + Neighborhood + Year_Sold`."
-   Q8: "Check that `dplyr::group_by(wflow_id)` is followed by
    `dplyr::slice(1)` to produce one row per workflow."

A companion `rubric_instructions.txt` prompt was used with `json_build.R` to
generate proxies for all exercises. However, several generated proxies contained
multiple conditions joined by "and" — effectively re-testing CodeExecution or
ProcessFidelity properties rather than introducing a novel OA check. OA mention%
remained ≈ 100%, but score stability worsened on questions with ambiguous student
code: Q8 SD rose to 0.335 and Q9 SD to 0.482.

### Intervention C2: Single-condition Proxy Rule

The fourth intervention refined the proxy authoring rules in
`rubric_instructions.txt` to enforce a single-condition constraint with explicit
separation-of-concerns guidance and annotated bad-proxy examples. The Q8 and Q9
proxies were manually trimmed:

-   Q8 final proxy: the `group_by(wflow_id)` → `slice(1)` chain only (removing
    conditions that re-tested CE/PF steps).
-   Q9 final proxy: `rank_metric = 'rmse'` only (removing the optional
    `select_best = TRUE` check).

Score stability partially recovered (Q8 SD = 0.268; Q9 SD = 0.417) but remained
above Intervention B levels. Residual variance reflects genuine ambiguity in
those student submissions — any binary proxy check on partially correct code
produces some run-to-run variance. Further proxy refinement cannot eliminate
this; it is a ceiling effect for source-code-only grading.

| Intervention | OA ment% (avg Q2–Q9) | Q8 SD | Q9 SD |
|---|---|---|---|
| Baseline | ≈ 14% | — | — |
| B (inline instruction) | ≈ 100% | 0.227 | 0.377 |
| C (OA proxy, multi-condition) | ≈ 100% | 0.335 | 0.482 |
| C2 (OA proxy, single-condition) | ≈ 100% | 0.268 | 0.417 |

### Structural Limitation: Semantic Equivalence

Manual review of Intervention C2 grades identified a constraint that no prompt
intervention can resolve. In Q3, the rubric specifies `step_center()` followed
by `step_scale()` to normalise numeric predictors. Some students used
`step_normalize()` instead — a single function that applies the same
transformation. The two approaches are semantically equivalent and produce
identical output. A grader reading source code must choose one interpretation or
the other, but cannot verify equivalence without executing the code.

The same pattern applies elsewhere in Lab 4: multiple valid tidymodels function
sequences produce identical pipeline outputs, and source-code grading cannot
distinguish them. This is the fundamental boundary for instruction-based prompt
interventions — no prompt change can supply information that is not present in
the source.

Code execution is the principled solution. Rendering the student's `.qmd` and
comparing the resulting R objects against the solution would resolve both the OA
under-verification problem and the semantic equivalence problem simultaneously.
Implementation requires a clean R environment with all required packages and
data, plus per-student error isolation. This is left as future work.

### Proxy Authoring Guidance

When writing an `OA_proxy` for a rubric exercise:

1.  **One condition only.** If the proxy requires "and" to connect two checks,
    keep only the most discriminating one.
2.  **Test output properties, not implementation steps.** CodeExecution already
    checks that the right functions were called; ProcessFidelity already checks
    the step sequence. The proxy should test a different property — the formula
    passed to a model, the grouping variable that determines output dimensions,
    or the column used for a join.
3.  **Source-checkable only.** The proxy must be verifiable by reading the
    `.qmd` source. Do not reference expected numeric values or runtime object
    states.
4.  **Leave it empty when unnecessary.** If the expected output is a scalar or
    simple transformation verifiable by inspection, set `OA_proxy` to `""`.

------------------------------------------------------------------------

## Cross-Lab Comparison

|   | Lab 9 (gpt-5.1) | Lab 4 (gpt-5.1) | Lab 4 (qwen) |
|----|----|----|----|
| CE coverage | Consistently verified (≥96%) | Consistently verified (≥86%) | Mostly verified; drops to 73% on Q7 |
| PF coverage | **Under-verified** (12–100%) | Well-verified (74–100%) | **Under-verified** (19–97%) |
| OA coverage | Well-verified (96–100%) | **Under-verified** (0–32% for Q2–Q9) | **Under-verified** (2–37% for Q2–Q9) |
| Primary driver of deductions | PF and OA (when outputs wrong) | PF (dominant), CE secondary | PF (dominant), CE secondary |
| OA verifiability | High — numeric answers | Low — R objects; only Q10 (MSE) numeric | Low — R objects; only Q10 (MSE) numeric |

The dominant pattern differs by lab type:

-   **Lab 9** (mathematical derivations and matrix operations): the
    grader infers correct process from correct output — awarding PF
    credit when numerical answers match without consistently verifying
    that the specified steps were followed. This PF gap is larger for
    qwen (~39% mention on full-credit runs) than for gpt-5.1 (~65%).
-   **Lab 4** (tidymodels ML pipeline): both models verify that the
    right functions were called in the right sequence (CE and PF for
    gpt-5.1; CE for qwen), but largely skip output verification because
    the expected outputs are complex R objects. qwen additionally
    under-verifies PF on most Lab 4 questions, a gap absent from
    gpt-5.1.

In all cases the bias is in the same direction: the criterion that
requires *independent* verification of a non-obvious property is the one
that gets skipped. For gpt-5.1, that is PF in Lab 9 and OA in Lab 4.
For qwen, both PF (across both labs) and OA (in Lab 4) are
under-verified.

------------------------------------------------------------------------

## Summary of Findings

1.  **Criterion coverage is not uniform, but responds to targeted
    intervention.** Whichever sub-criterion is hardest to verify by
    inspecting source code — PF in Lab 9, OA in Lab 4 — is the one most
    likely to be omitted. Source-checkable OA proxies raised OA mention%
    from ≈ 14% to ≈ 100% in Lab 4, but the deeper constraint remains:
    source-code-only grading cannot distinguish semantically equivalent
    implementations.

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

### Comparison with Human Grading

The two behaviours most prominent in these results — inferring process
credit from correct output, and skipping output verification when the
expected result is not a concrete scalar — are not unique to LLM
graders. A human TA reading the same `.qmd` source file faces identical
epistemic constraints: they cannot execute the code, cannot inspect R
objects, and will reasonably award process credit when a student's
numerical answer is correct, without tracing every intermediate step.
The criterion-coverage patterns documented here are therefore better
understood as a property of the grading task than as a flaw specific to
the LLM.

The run-to-run score variability is similarly worth contextualising. The
analysis here measures *intra-rater* reliability — the same grader, the
same submission, repeated independently. The more practically relevant
comparison is *inter-rater* reliability: what variation would arise if
two different human TAs graded the same assignment independently?
Inter-rater disagreement on individual questions is a well-documented
phenomenon in educational assessment, and the magnitudes reported here
(SD typically below 0.3 pts on a 3–5 pt scale, with isolated cases
reaching 0.5) are plausibly consistent with the range observed in human
grading studies. What distinguishes the LLM is not that variability
exists, but that it can be measured systematically and cheaply through
repeated runs — a diagnostic capability that is rarely applied to human
graders in practice.

The more substantive concern is not variability but the *structural*
nature of the criterion-coverage gaps. Because the pattern is consistent
across runs and models, it will not average out with more repetitions.
This makes it a property of how the rubric criteria interact with the
grading task rather than random noise, and it applies equally — if less
visibly — to human graders working under the same constraints.

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
-   **Semantic equivalence.** Source-code grading cannot distinguish
    implementations that produce identical outputs by different code
    paths (e.g., `step_normalize()` vs `step_center()` + `step_scale()`).
    This is a structural property of source-code-only grading — not a
    prompt failure — and requires code execution to resolve.

------------------------------------------------------------------------

*Raw classification data:*\
*`assignment/lab_9_rubric_coverage_raw_gpt-5.1_meta_gpt-4o-mini.csv`*\
*`assignment/lab_9_rubric_coverage_raw_qwen_qwen3.6-27b_meta_gpt-4o-mini.csv`*\
*`assignment/lab_4_rubric_coverage_raw_gpt-5.1_meta_gpt-4o-mini.csv`*\
*`assignment/lab_4_rubric_coverage_raw_gpt-5.1_intervention-a_meta_gpt-4o-mini.csv`*\
*`assignment/lab_4_rubric_coverage_raw_qwen_qwen3.6-27b_meta_gpt-4o-mini.csv`*

*Aggregated data (baseline):*\
*`assignment/lab_9_rubric_coverage_summary_gpt-5.1_meta_gpt-4o-mini.csv`*\
*`assignment/lab_9_rubric_coverage_summary_qwen_qwen3.6-27b_meta_gpt-4o-mini.csv`*\
*`assignment/lab_4_rubric_coverage_summary_gpt-5.1_meta_gpt-4o-mini.csv`*\
*`assignment/lab_4_rubric_coverage_summary_qwen_qwen3.6-27b_meta_gpt-4o-mini.csv`*

*Aggregated data (interventions — Lab 4 gpt-5.1 only):*\
*`assignment/lab_4_rubric_coverage_summary_gpt-5.1_intervention-a_meta_gpt-4o-mini.csv`*\
*`assignment/lab_4_rubric_coverage_summary_gpt-5.1_intervention-b_direct.csv`*\
*`assignment/lab_4_rubric_coverage_summary_gpt-5.1_intervention-c_direct.csv`*\
*`assignment/lab_4_rubric_coverage_summary_gpt-5.1_intervention-c2_direct.csv`*

*Analysis script: `Python/evaluate_rubric_coverage.py`.*
