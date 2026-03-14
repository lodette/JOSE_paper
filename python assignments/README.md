This folder contains an anonymized three-student Lab 9 subset prepared for the Python grading pipeline.

Layout:
- `lab_9_solutions.qmd`, `lab_9_starter.qmd`, `rubric_lab_9.json`: copied grading materials
- `lab-9/`: student submissions arranged for `Python/batch_grade.py`
- `lab-9/selected_students.csv`: anonymized score-band manifest

Expected run command once `OPENAI_API_KEY` is set:

```powershell
$env:LAB_NUMBER="9"
$env:BASE_LAB_DIR=(Resolve-Path ".\python assignments").Path
python .\Python\batch_grade.py
```

The output CSV will be written to `python assignments/lab-9/lab9_grades.csv`.
