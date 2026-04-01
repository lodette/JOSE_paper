"""
Root conftest.py — loaded by pytest before any test module.

Sets the environment variables that grading_context.py and batch_grade.py
validate at import time.  Using os.environ.setdefault ensures user-supplied
values (e.g. from a real .env) are not overwritten when running locally.

Also adds the Python/ subdirectory to sys.path so that test modules can
import grading_context, grade_student, and batch_grade without a package
prefix, mirroring the runtime behaviour of running the scripts directly
from the Python/ directory.
"""
import os
import sys
from pathlib import Path

# Make the Python/ source directory importable from the test suite
sys.path.insert(0, str(Path(__file__).parent / "Python"))

os.environ.setdefault("LAB_NUMBER", "9")
os.environ.setdefault("OPENAI_API_KEY", "sk-test-dummy-key-for-ci")
# Point at the repo's assignment/ folder so grading_context.py can find
# rubric_lab_9.json, lab_9_starter.qmd, and lab_9_solutions.qmd during tests.
os.environ.setdefault(
    "BASE_LAB_DIR",
    str(Path(__file__).parent / "assignment")
)
