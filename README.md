# LLM-Based Automated Grading System for Quarto Lab Submissions

An automated grading pipeline that uses a large language model (LLM) to evaluate student `.qmd` (Quarto) lab submissions against a structured rubric. Designed for use in graduate-level quantitative methods courses.

---

## Overview

This system reads each student's Quarto lab file, supplies the model with the grading rubric, the starter template, and the instructor solution, then returns a structured JSON grade with per-question scores and feedback. Results are written to a CSV file for easy import into a gradebook.

```
Student .qmd  ─┐
Rubric JSON   ─┤──▶  LLM (OpenAI)  ──▶  JSON grade  ──▶  grades.csv
Starter .qmd  ─┤
Solution .qmd ─┘
```

---

## Repository Structure

```
.
├── batch_grade.py                   # Entry point — grades all students for a lab
├── grade_student.py                 # Grades a single student .qmd file
├── grading_context.py               # Loads rubric, templates, and builds API messages
├── grader_instructions.txt          # System prompt for the LLM grader
├── rubric_lab_<N>.json              # Per-question rubric (one file per lab)
├── BSMM_8740_lab_<N>_starter.qmd   # Starter template distributed to students
├── BSMM_8740_lab_<N>_solutions.qmd # Instructor solution
├── 2025-lab-9.qmd                  # Sample anonymized student submission (Lab 9)
├── .env.example                    # Template for required environment variables
└── .gitignore
```

> `2025-lab-9.qmd` is an **anonymized sample student submission** included to illustrate the expected input format for the grader. It is not tied to any real student and can be used to test the pipeline end-to-end.

> Student submission folders and generated CSV files are excluded from version control via `.gitignore`.

---

## Prerequisites

- Python 3.10+
- An [OpenAI API key](https://platform.openai.com/api-keys)

Install dependencies:

```bash
pip install openai python-dotenv
```

---

## Configuration

1. Copy the example environment file:

   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your values:

   ```ini
   OPENAI_API_KEY=sk-proj-...      # Your OpenAI API key
   LAB_NUMBER=9                    # Which lab to grade
   BASE_LAB_DIR=C:\Users\yourname\Desktop\University\TA
   ```

   `BASE_LAB_DIR` should be the parent folder that contains a subdirectory named `lab-<LAB_NUMBER>`.

---

## Expected Directory Layout

The script expects student submissions to be organized as follows:

```
<BASE_LAB_DIR>/
└── lab-9/
    ├── 2025-lab-9_StudentID1/
    │   └── 2025-lab-9.qmd
    ├── 2025-lab-9_StudentID2/
    │   └── 2025-lab-9.qmd
    └── ...
```

Each student folder is named `2025-lab-<N>_<StudentID>`. The script extracts the student ID from the part after the first underscore.

---

## Usage

Run the batch grader from the project root:

```bash
python batch_grade.py
```

This will:
1. Recursively find every `2025-lab-<N>.qmd` file under `<BASE_LAB_DIR>/lab-<N>/`.
2. Send each file to the LLM along with the rubric, starter, and solution.
3. Parse the returned JSON grade.
4. Write all results to `<BASE_LAB_DIR>/lab-<N>/lab<N>_grades.csv`.

Progress is printed to the console as each student is graded.

---

## Output Format

The generated CSV contains one row per student with the following columns:

| Column | Description |
|---|---|
| `Student` | Student ID extracted from the folder name |
| `Total` | Sum of all question grades |
| `OverallComment` | 2–3 sentence summary from the LLM |
| `Q1` … `Q10` | Numeric grade for each question |
| `Q1_feedback` … `Q10_feedback` | Per-question feedback from the LLM |

---

## Adding a New Lab

To grade a different lab, update your `.env`:

```ini
LAB_NUMBER=10
```

Then add the corresponding files to the project directory:

- `rubric_lab_10.json`
- `BSMM_8740_lab_10_starter.qmd`
- `BSMM_8740_lab_10_solutions.qmd`

No code changes are required.

---

## Rubric Format

Each rubric file (`rubric_lab_<N>.json`) follows this schema:

```json
{
  "GlobalScoring": {
    "PerExercisePoints": 5,
    "Breakdown": ["CodeExecution (1 pt)", "ProcessFidelity (2 pt)", "OutputAccuracy (2 pt)"],
    "Rules": [ "..." ]
  },
  "Ex1": {
    "Points": 5,
    "Criteria": "Description of what is being tested",
    "Checks": {
      "CodeExecution (1 pt)": "...",
      "ProcessFidelity (2 pt)": "...",
      "OutputAccuracy (2 pt)": "..."
    },
    "DiscretionaryPenalty (up to -1 pt)": "..."
  }
}
```

---

## Grader Instructions

The file `grader_instructions.txt` is used as the LLM system prompt. It instructs the model to:

- Grade only what appears in the student's `.qmd` source (not assumed execution output).
- Return a strictly structured JSON object.
- Keep feedback concise and rubric-aligned.

Modify this file to adjust grading behavior without changing any Python code.

---

## Security Note

Your `.env` file contains your API key and must never be committed to version control. The `.gitignore` in this repository already excludes it. Always use `.env.example` as the template when sharing this project.

---

## Citation

If you use this system in your research, please cite the associated paper:

```
[Citation to be added upon publication]
```
