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
