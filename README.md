# LLM-Based Automated Grading System for Quarto Lab Submissions

An automated grading pipeline that uses a large language model (LLM) to evaluate student `.qmd` (Quarto) lab submissions against a structured rubric. Implemented in both **Python** and **R**, the two pipelines share the same goal and grading materials but differ in their API strategy, execution model, and configuration approach. Designed for use in graduate-level quantitative methods courses.

---

## Overview

Both pipelines read each student's Quarto lab file, supply the model with the grading rubric, the starter template, and the instructor solution, and return a structured JSON grade with per-question scores and feedback. Results are written to a CSV file for easy import into a gradebook.

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
├── batch_grade.py                        # Python: entry point — grades all students
├── grade_student.py                      # Python: grades a single student .qmd
├── grading_context.py                    # Python: loads rubric, templates, builds API messages
├── grader_instructions.txt               # Python: system prompt for the LLM grader
│
├── R/
│   ├── oaii_grading_assistant.R          # R: one-time setup — uploads files, creates assistant
│   └── oaii_grading_assistant_runner.R   # R: batch grading loop
│
├── assignment/
│   ├── rubric_lab_<N>.json               # Shared: per-question rubric
│   ├── BSMM_8740_lab_<N>_solutions.qmd   # Shared: instructor solution
│   ├── BSMM_8740_lab_<N>_starter.qmd     # Shared: starter template
│   └── assistant_config.json             # R only: persisted assistant and file IDs
│
├── docs/
│   ├── r_pipeline_overview.md            # Technical overview of the R pipeline
│   ├── python_pipeline_overview.md       # Technical overview of the Python pipeline
│   └── pipeline_comparison.md           # Side-by-side comparison with table
│
├── .env.example                          # Python: template for environment variables
└── .gitignore
```

> `assignment/` holds the shared grading materials for both pipelines. Student submission folders and generated CSV files are excluded from version control via `.gitignore`.

---

## Shared Grading Materials

Both pipelines require the same three files per lab, placed in `assignment/`:

| File | Description |
|---|---|
| `rubric_lab_<N>.json` | Per-question rubric with point values and grading criteria |
| `BSMM_8740_lab_<N>_solutions.qmd` | Instructor solution for the lab |
| `BSMM_8740_lab_<N>_starter.qmd` | Starter template distributed to students |

Student submissions are organized in subfolders:
```
assignment/
└── 2025-lab-<N>_<StudentID>/
    └── 2025-lab-<N>.qmd
```

---

## Python Pipeline

### How It Works

The Python pipeline uses the **OpenAI Chat Completions API** and is fully stateless — no setup step is required. For each student, a single synchronous API call is made containing the rubric, solution, starter, and submission all inlined in the message list. Ephemeral prompt caching (`"cache_control": {"type": "ephemeral"}`) is applied to the shared context so that the rubric, solution, and starter prefix is reused across the full student batch, reducing both latency and token cost. `response_format={"type": "json_object"}` is set on every call to enforce valid JSON output.

### Prerequisites

- Python 3.10+
- An [OpenAI API key](https://platform.openai.com/api-keys)

```bash
pip install openai python-dotenv
```

### Configuration

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your values:
   ```ini
   OPENAI_API_KEY=sk-proj-...      # Your OpenAI API key
   LAB_NUMBER=9                    # Which lab to grade
   BASE_LAB_DIR=/path/to/your/lab/folder
   ```
   `BASE_LAB_DIR` should be the parent folder containing a subdirectory named `lab-<LAB_NUMBER>`. Student submission folders are expected inside `lab-<N>/`.

### Usage

```bash
python batch_grade.py
```

This will:
1. Recursively find every `2025-lab-<N>.qmd` file under `<BASE_LAB_DIR>/lab-<N>/`.
2. Send each file to the LLM along with the rubric, starter, and solution.
3. Parse the returned JSON grade.
4. Write all results to `<BASE_LAB_DIR>/lab-<N>/lab<N>_grades.csv`.

### Output Format (Python)

| Column | Description |
|---|---|
| `Student` | Student ID extracted from the folder name |
| `Total` | Sum of all question grades |
| `OverallComment` | 2–3 sentence summary from the LLM |
| `Q1` … `Q10` | Numeric grade for each question |
| `Q1_feedback` … `Q10_feedback` | Per-question feedback from the LLM |

CSV encoding: **UTF-8**.

---

## R Pipeline

### How It Works

The R pipeline uses the **OpenAI Assistants API v2** and is stateful. It runs in two phases: a one-time **setup** that uploads grading materials and creates a persistent Assistant, and a **grading loop** that creates an isolated thread per student, attaches the uploaded files for `file_search` retrieval, and polls each run to completion. `response_format = list(type = "json_object")` is set on every run to enforce valid JSON output, allowing the reply to be parsed directly with `jsonlite::fromJSON()`.

### Prerequisites

- R 4.1+ with the following packages (installed automatically via `librarian`):
  `tidyverse`, `rmarkdown`, `httr2`, `jsonlite`, `fs`, `quarto`, `cezarykuran/oaii`
- [Quarto CLI](https://quarto.org/docs/get-started/) (for rendering `.qmd` files during setup)
- An [OpenAI API key](https://platform.openai.com/api-keys)

### Configuration

Add your API key to `~/.Renviron`:
```
OPENAI_API_KEY=sk-proj-...
```
After editing, restart your R session or run `readRenviron("~/.Renviron")`.

The lab number is set at the top of `oaii_grading_assistant_runner.R`:
```r
LAB_NUMBER <- 9   # change this to target a different lab
```

### Phase 1 — One-Time Setup

Run once per lab to upload grading materials and create the persistent Assistant:

```r
LAB_NUMBER <- 9
source("./R/oaii_grading_assistant.R")
```

This renders the solution and starter `.qmd` files to GitHub Flavored Markdown, uploads the rubric JSON and rendered files to the OpenAI Files API, creates an Assistants v2 assistant with the `file_search` tool, and writes `assignment/assistant_config.json` containing the assistant and file IDs. Skip this step if `assistant_config.json` already exists for the lab.

### Phase 2 — Batch Grading

```r
source("./R/oaii_grading_assistant_runner.R")
```

Or use the **Source** button in RStudio. The script will:
1. Read `assistant_config.json` for the assistant and file IDs.
2. Walk every student subfolder in `assignment/`.
3. Create an isolated thread per student, attach the rubric/solution/starter, and send the submission with the grading prompt.
4. Poll until each run completes (up to 180 s at 0.7 s intervals).
5. Parse the JSON response directly via `jsonlite::fromJSON()`.
6. Write results to `assignment/r_lab<N>_grades.csv`.

### Output Format (R)

| Column | Description |
|---|---|
| `Student` | Student ID extracted from the folder name |
| `Q1` … `Q10` | Numeric grade for each question |
| `Total` | Sum of all question grades |
| `Comments` | Per-question feedback concatenated as `Q1: <text> | Q2: <text> | …` |

CSV encoding: **UTF-8 BOM** (Excel compatible).

---

## Pipeline Comparison

| Aspect | Python | R |
|---|---|---|
| **API** | Chat Completions (`POST /chat/completions`) | Assistants v2 (`/assistants`, `/threads`, `/runs`) |
| **Execution model** | Synchronous — one HTTP call per student | Asynchronous — thread created, run started, then polled |
| **Setup required** | None — stateless, run directly | One-time setup script creates a persistent Assistant and uploads files |
| **Context delivery** | Rubric, solution, and starter inlined in every request | Files uploaded once; model retrieves relevant chunks via `file_search` |
| **Caching** | Ephemeral prompt caching on the shared prefix | Persistent file storage on OpenAI servers |
| **Structured output** | `response_format={"type": "json_object"}` | `response_format = list(type = "json_object")` on each run |
| **Output parsing** | `json.loads()` | `jsonlite::fromJSON()` |
| **Model** | `gpt-5.1` | `gpt-4.1-mini` |
| **Scripts** | 3 modules at project root | 2 scripts in `R/` |
| **CSV encoding** | UTF-8 | UTF-8 BOM (Excel compatible) |
| **Feedback columns** | Separate `Q1_feedback` … `Q10_feedback` | Single concatenated `Comments` column |

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

`grader_instructions.txt` is used by the **Python** pipeline as the LLM system prompt. It instructs the model to:

- Grade only what appears in the student's `.qmd` source (not assumed execution output).
- Return a single JSON object with `questions`, `total`, and `overall_comment`.
- Keep feedback concise and rubric-aligned.

The **R** pipeline embeds a briefer set of instructions inline in the runner's grading prompt, with the assistant configured at creation time to search the uploaded rubric and solution files for relevant content.

Modify `grader_instructions.txt` to adjust Python grading behaviour without changing any Python code.

---

## Adding a New Lab

**Python** — update `.env`:
```ini
LAB_NUMBER=10
```

**R** — update the top of `oaii_grading_assistant_runner.R`:
```r
LAB_NUMBER <- 10
```
Then re-run Phase 1 (setup) to upload the new lab's materials and create a fresh Assistant.

For both pipelines, add the corresponding files to `assignment/`:
- `rubric_lab_10.json`
- `BSMM_8740_lab_10_starter.qmd`
- `BSMM_8740_lab_10_solutions.qmd`

---

## Security Note

Your `.env` (Python) and `~/.Renviron` (R) files contain your OpenAI API key and must never be committed to version control. The `.gitignore` in this repository already excludes `.env`. Always use `.env.example` as the sharing template.

---

## Citation

If you use this system in your research, please cite the associated paper:

```
[Citation to be added upon publication]
```
