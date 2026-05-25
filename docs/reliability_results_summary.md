---
editor_options: 
  markdown: 
    wrap: 72
---

# Reliability Test Results: Python vs R (Chat Completions)

Both pipelines use the **Chat Completions API** (`gpt-5.1`,
`temperature = 0.1`) with identical context delivery (rubric, starter,
and solution inlined with ephemeral prompt caching). Results are based
on **50 runs per pipeline per student** across three student profiles.
The assignment contains **6 questions** (Q1–Q6); Q7–Q10 entries in the
CSV are an artifact of the column layout and are excluded from this
analysis.

------------------------------------------------------------------------

## Student-level results

### `student_high` — ceiling performance

|           | Python  | R       |
|-----------|---------|---------|
| **Total** | 30 (±0) | 30 (±0) |
| Q1        | 5 (±0)  | 5 (±0)  |
| Q2        | 5 (±0)  | 5 (±0)  |
| Q3        | 5 (±0)  | 5 (±0)  |
| Q4        | 5 (±0)  | 5 (±0)  |
| Q5        | 5 (±0)  | 5 (±0)  |
| Q6        | 5 (±0)  | 5 (±0)  |

Both pipelines awarded perfect scores with zero variance across all 50
runs. This student's submission left no room for grading ambiguity.

------------------------------------------------------------------------

### `student_low` — most variability; small pipeline divergence

|           | Python        | R             |
|-----------|---------------|---------------|
| **Total** | 18.47 (±0.48) | 18.92 (±0.74) |
| Q1        | 4.06 (±0.16)  | 4.14 (±0.29)  |
| Q2        | 3.35 (±0.42)  | 3.52 (±0.45)  |
| Q3        | 0 (±0)        | 0 (±0)        |
| Q4        | 4.06 (±0.19)  | 4.25 (±0.34)  |
| Q5        | 2.00 (±0)     | 2.01 (±0.07)  |
| Q6        | 5 (±0)        | 5 (±0)        |

The R pipeline awards this student approximately **0.45 points more on
average** and with **greater spread** (SD 0.74 vs 0.48). Q1, Q2, and Q4
each trend slightly higher under R, and their SDs are roughly double
those of Python. Q3 and Q6 are deterministic across both pipelines.

------------------------------------------------------------------------

### `student_mid` — closest pipeline agreement

|           | Python        | R             |
|-----------|---------------|---------------|
| **Total** | 22.79 (±0.78) | 22.83 (±0.66) |
| Q1        | 3.99 (±0.34)  | 4.12 (±0.36)  |
| Q2        | 3.17 (±0.24)  | 3.15 (±0.23)  |
| Q3        | 1.20 (±0.38)  | 1.19 (±0.33)  |
| Q4        | 4.71 (±0.29)  | 4.69 (±0.32)  |
| Q5        | 4.72 (±0.25)  | 4.68 (±0.24)  |
| Q6        | 5 (±0)        | 5 (±0)        |

Pipeline totals differ by only 0.04 points and SDs are comparable. At
the question level, all differences are within noise (\< 0.15 points).

------------------------------------------------------------------------

## Cross-cutting inferences

**1. Both pipelines are highly reliable on unambiguous submissions.**
`student_high` demonstrates zero variance across all 50 runs in both
pipelines. When a submission is clearly correct (or clearly wrong, as
with Q3 for `student_low`), both pipelines converge deterministically.

**2. Grading variability scales with submission quality, not pipeline.**
SD on the total rises from 0 (`student_high`) to \~0.5–0.8
(`student_low` / `student_mid`). Ambiguous partial-credit judgements are
the primary driver of variance — not which pipeline is used.

**3. The R pipeline is marginally more generous and more variable on
weaker submissions.** For `student_low`, R awards \~0.45 more points
with \~55% higher SD than Python. This is the most notable pipeline
difference in the dataset. Since both pipelines use the same API, model,
temperature, and context, the difference most likely reflects minor
non-determinism in how the model interprets partial-credit criteria when
applied through an R-constructed message payload vs the Python
implementation.

**4. The pipelines converge on mid-range submissions.** For
`student_mid`, the 0.04-point total difference is negligible, suggesting
the divergence seen in `student_low` is specific to cases with harder
partial-credit boundaries rather than a systematic upward bias in R.

**5. Q6 is deterministic for all students.** Q6 = 5 with SD = 0 across
all three students and both pipelines, suggesting the rubric criterion
for this question has a clear binary outcome that all three submissions
satisfy fully.

------------------------------------------------------------------------

## Summary

The Python and R Chat Completions pipelines produce **substantively
equivalent grades** across all three student profiles. The only
meaningful difference is that R is marginally more generous (\< 0.5
points on average) with slightly higher variance on the weakest
submission. With n = 50 runs each, this is a stable finding, but the
effect size is small enough that it would not materially change a
student's grade in practice. The results support the conclusion that
both pipelines are interchangeable for operational grading, and that
residual variability in LLM grading is driven by submission ambiguity
rather than implementation choice.

------------------------------------------------------------------------

# Lab 4 Reliability Results: Python vs R (Chat Completions)

Lab 4 uses the same pipeline configuration as Lab 9 (**Chat Completions
API**, `gpt-5.1`, `temperature = 0.1`, ephemeral prompt caching) but
covers **10 students** (a–j) and **10 questions** (Q1–Q10, 3 points
each, 30 points total), providing a larger and more varied cohort for
assessing reliability and pipeline agreement.

------------------------------------------------------------------------

## Student-level results

| Student | Python | R | Diff (R − Python) |
|---------|--------|---|-------------------|
| student_a | 24.02 (±1.82) | 24.02 (±2.04) | 0.00 |
| student_b | 18.34 (±1.14) | 18.54 (±1.78) | +0.20 |
| student_c | 21.74 (±2.20) | 21.24 (±2.40) | −0.50 |
| student_d | 15.62 (±1.10) | 15.86 (±0.86) | +0.24 |
| student_e | 23.74 (±1.86) | 24.07 (±1.38) | +0.33 |
| student_f | 24.15 (±1.40) | 24.46 (±1.55) | +0.31 |
| student_g | 24.42 (±0.96) | 23.28 (±2.28) | −1.14 |
| student_h | 20.64 (±1.87) | 20.58 (±1.74) | −0.06 |
| student_i | 24.80 (±0.63) | 25.27 (±0.82) | +0.47 |
| student_j | 28.16 (±1.49) | 27.92 (±1.53) | −0.24 |

Mean ± SD across 50 runs. Max total = 30.

### Notable students

**student_g** is the largest outlier: Python scores 1.14 points higher
on average (24.42 vs 23.28) and is substantially more stable (SD 0.96
vs 2.28). This is the only student where the pipeline difference exceeds
1 point and R is both lower and more variable — a reversal of the
pattern observed in Lab 9.

**student_i** is the most stable Python grading in the dataset (SD
0.63). Q1 illustrates an interesting divergence: Python gives 2.57
(±0.46) while R gives 2.99 (±0.07) — R is simultaneously more generous
and more consistent on this question.

**student_d** (the lowest scorer, 15.6/30) has deterministic zeros on
Q7, Q8, and Q10 in both pipelines, and the two pipelines agree closely
on total (±0.24 points). Severely incorrect or missing responses appear
as robust to pipeline choice as perfect responses.

------------------------------------------------------------------------

## Question-level patterns

**Most variable questions (both pipelines):**

- **Q3** — variable for students b, c, d, and j, with SDs reaching 0.50
  in both pipelines. This question involves a normalisation pipeline
  step where semantically equivalent implementations (e.g.
  `step_normalize()` vs `step_center()` + `step_scale()`) receive
  inconsistent partial credit — a structural grading ambiguity
  documented in the rubric conformance analysis.
- **Q10** — variable for students b, c, g, h, and i (SDs up to 0.51).

**Most stable questions:**

- **Q2** is deterministic at 2.0 (±0) for 8 of 10 students in both
  pipelines.
- **Q5** is deterministic at 3.0 (±0) for 7 of 10 students in both
  pipelines.
- **Q7** and **Q8** are deterministic at 3.0 for high scorers and at 0.0
  for student_d — no intermediate variance.

------------------------------------------------------------------------

## Cross-cutting inferences

**1. The Lab 9 R-generosity finding does not replicate consistently.**
In Lab 9, R was marginally more generous on every student. In Lab 4, R
is higher for 5 students, Python is higher for 4, and one is identical.
The differences are small (under 0.5 points) in 9 of 10 cases, with
student_g as the sole exception. There is no consistent directional bias
attributable to the pipeline.

**2. Both pipelines are highly reliable within each run.** Total SDs
range from 0.63 to 2.40 across the cohort. The higher end of this range
(students c, g) reflects question-level ambiguity in Q3 and Q10 rather
than pipeline instability — the same questions drive variance in both
Python and R.

**3. Pipeline differences scale with submission ambiguity, not
performance level.** The lowest scorer (student_d, 15.6/30) and the
highest scorer (student_j, 28.0/30) both show small pipeline differences
(0.24 points each). The largest divergence (student_g, 1.14 points)
occurs in the mid-to-high range, suggesting that ambiguity in specific
partial-credit boundaries — rather than overall submission quality — is
the primary driver.

**4. Deterministic extremes are robust across both pipelines.** Full
marks (3.0, SD=0) and zero marks (0.0, SD=0) occur consistently in
both pipelines for the same students on the same questions. Clear
binary outcomes are immune to pipeline choice.

------------------------------------------------------------------------

## Summary

Across 10 students and 10 questions, the Python and R Chat Completions
pipelines produce **substantively equivalent grades**. Nine of ten
students receive means within 0.5 points of each other; the one
exception (student_g, 1.14-point difference) is an isolated case with
no clear structural explanation. Unlike Lab 9, there is no consistent
directional bias favouring R. Taken together, the Lab 9 and Lab 4
results reinforce the conclusion that pipeline choice (Python vs R Chat
Completions) does not materially affect grading outcomes, and that
residual variability is driven by rubric ambiguity rather than
implementation.
