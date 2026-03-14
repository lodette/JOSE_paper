This folder summarizes the comparison between the Python grading pipeline and the R/Assistants grading pipeline on the anonymized three-student Lab 9 subset.

## Selected students

The anonymized students were sampled from `research/lab9_grades.csv` by score band. The original identities are intentionally omitted from the repository copy to keep this artifact anonymized.

| Alias | Score band |
| --- | --- |
| `student_high` | above 83% |
| `student_mid` | 66% to 83% |
| `student_low` | below 66% |

## Score comparison

| Alias | Original | Python rerun | R rerun | Python abs. error | R abs. error |
| --- | ---: | ---: | ---: | ---: | ---: |
| `student_high` | 30.0 | 30.0 | 30.0 | 0.0 | 0.0 |
| `student_mid` | 23.0 | 22.5 | 28.0 | 0.5 | 5.0 |
| `student_low` | 17.5 | 18.0 | 24.0 | 0.5 | 6.5 |

## Summary

On this three-student sample, the Python pipeline matches the original grading much more closely than the R pipeline.

- The Python rerun exactly matched the high-scoring submission and was within 0.5 points on the mid and low submissions.
- The R rerun matched the high-scoring submission but overscored the mid submission by 5.0 points and the low submission by 6.5 points.
- Measured against the original `lab9_grades.csv`, the Python pipeline is the better fit on this sample.

## Manual judgment from file review

I also reviewed the three anonymized `.qmd` files directly against the rubric and solution instead of treating the original CSV as ground truth.

Manual conclusion:

- `student_high`: tie. Both pipelines are acceptable; this submission is effectively full credit.
- `student_mid`: Python is better. The submission has real issues in Q2, Q3, and Q4, and the R pipeline is too generous at `28`.
- `student_low`: Python is better. Q3 is missing from the `.qmd`, Q5 is clearly wrong on the 20-year state interpretation, and the R pipeline over-credits this work at `24`.

Why Python looks better on manual review:

- It penalizes missing or non-compliant derivation work more appropriately.
- It tracks process-fidelity failures more closely when the student gets a final number right but does not follow the requested method.
- It is less lenient on weaker submissions where the file contains clear rubric violations.

Why R looks weaker on manual review:

- It appears to reward partial conceptual correctness too heavily even when the file does not satisfy the requested workflow.
- It overstates the quality of the mid and low submissions, especially around missing derivation work and incorrect state-transition interpretation.

Bottom line from manual assessment:

- `student_high`: tie
- `student_mid`: Python better
- `student_low`: Python better

## Interpretation

This does not prove the Python pipeline is universally better. It only shows that, for these three anonymized Lab 9 submissions and this set of model/configuration choices:

- Python was more consistent with the original benchmark grades.
- R/Assistants was noticeably more lenient on the weaker two submissions.

## Related outputs

- Python results: `../python assignments/lab-9/lab9_grades.csv`
- R results: `../R assignments/r_lab9_grades.csv`
- R assistant config used for the rerun: `../R assignments/assistant_config.json`
