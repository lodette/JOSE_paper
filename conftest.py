"""
Root conftest.py — loaded by pytest before any test module.

Sets the environment variables that grading_context.py validates at import
time, then calls grading_context.configure() so that lab-specific paths are
resolved before any test runs. Using os.environ.setdefault ensures
user-supplied values (e.g. from a real .env) are not overwritten when running
locally.

Also adds the Python/ subdirectory to sys.path so that test modules can
import grading_context, grade_student, and batch_grade without a package
prefix, mirroring the runtime behaviour of running the scripts directly
from the Python/ directory.
"""
import os
import sys
from pathlib import Path

import pytest

# Make the Python/ source directory importable from the test suite
sys.path.insert(0, str(Path(__file__).parent / "Python"))

os.environ.setdefault("OPENAI_API_KEY", "sk-test-dummy-key-for-ci")
# Point at the repo's assignment/ folder so grading_context.py can find
# lab_9_rubric.json, lab_9_starter.qmd, and lab_9_solutions.qmd during tests.
os.environ.setdefault(
    "BASE_LAB_DIR",
    str(Path(__file__).parent / "assignment")
)

import grading_context  # noqa: E402 — must come after env vars are set
grading_context.configure(9)


@pytest.fixture(autouse=True)
def reset_grading_context():
    """Restore the default repo-backed grading context after each test."""
    grading_context.BASE_LAB_DIR = Path(os.environ["BASE_LAB_DIR"])
    grading_context.configure(9)
    yield
    grading_context.BASE_LAB_DIR = Path(os.environ["BASE_LAB_DIR"])
    grading_context.configure(9)
