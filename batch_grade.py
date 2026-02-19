import os
import csv
from pathlib import Path
from dotenv import load_dotenv

from grade_student import grade_student_qmd

load_dotenv()

LAB_NUMBER = os.getenv("LAB_NUMBER")
if LAB_NUMBER is None:
    raise ValueError("Environment variable LAB_NUMBER is not set. Please define LAB_NUMBER in your .env file.")

BASE_LAB_DIR = os.getenv("BASE_LAB_DIR", r"C:\Users\muham\Desktop\University\TA")

# Root folder that contains all the student folders for this lab
BASE_DIR = Path(BASE_LAB_DIR) / f"lab-{LAB_NUMBER}"
OUTPUT_CSV = BASE_DIR / f"lab{LAB_NUMBER}_grades.csv"



def main():
    rows = []

    # Look for the common file name inside all student folders
    # If the actual name is "2025-lab-5.qmd", change it here.
    for path in sorted(BASE_DIR.rglob(f"2025-lab-{LAB_NUMBER}.qmd")):
        # path.parent is e.g. C:\...\lab-5\2025-lab-5_Ama8777
        student_folder = path.parent
        folder_name = student_folder.name          # "2025-lab-5_Ama8777"

        # Extract the part after the underscore -> "Ama8777"
        if "_" in folder_name:
            student_id = folder_name.split("_", 1)[1]
        else:
            # Fallback: if format is different, just use folder name

            student_id = folder_name

        print(f"Grading {student_id} from {path} ...")

        # IMPORTANT: pass a Path object into grade_student_qmd
        result = grade_student_qmd(path)

        total = result.get("total")
        questions = result.get("questions", {})

        row = {
            "Student": student_id,
            "Total": total,
            "OverallComment": result.get("overall_comment", ""),
        }

        # Flatten Q1–Q10 grades + feedback
        for q in range(1, 11):
            qk = f"Q{q}"
            qinfo = questions.get(qk, {})
            row[qk] = qinfo.get("grade")
            row[f"{qk}_feedback"] = qinfo.get("feedback")

        rows.append(row)

    fieldnames = (
        ["Student", "Total", "OverallComment"]
        + [f"Q{i}" for i in range(1, 11)]
        + [f"Q{i}_feedback" for i in range(1, 11)]
    )

    with OUTPUT_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Saved grades to {OUTPUT_CSV}")


if __name__ == "__main__":
    main()
