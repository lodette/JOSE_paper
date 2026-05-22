This folder contains the same anonymized three-student Lab 9 subset prepared for the R grading pipeline.

Layout:
- `assistant_config.json`, `lab_9_solutions.qmd`, `lab_9_starter.qmd`, `rubric_lab_9.json`: copied grading materials
- `lab-9_student_high`, `lab-9_student_mid`, `lab-9_student_low`: anonymized student submissions
- `selected_students.csv`: anonymized score-band manifest

The checked-in R runner does not point at this folder by default; it hardcodes `assignment/`.
To grade this subset, run a custom R session that sets `CONFIG_JSON`, `directory_path`, and `output_csv` against this folder after sourcing `R/oaii_grading_assistant_runner.R`.

An OpenAI API key is still required before any rerun can complete.
