"""
Root conftest.py — loaded by pytest before any test module.

Sets the environment variables that grading_context.py and batch_grade.py
validate at import time.  Using os.environ.setdefault ensures user-supplied
values (e.g. from a real .env) are not overwritten when running locally.
"""
import os

os.environ.setdefault("LAB_NUMBER", "9")
os.environ.setdefault("OPENAI_API_KEY", "sk-test-dummy-key-for-ci")
os.environ.setdefault("BASE_LAB_DIR", "/tmp/test_lab")
