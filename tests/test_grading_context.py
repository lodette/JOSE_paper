"""
Unit tests for grading_context.py.

These tests exercise file-loading helpers and message-builder functions
without making any API calls.  The assignment fixture files that already
exist in the repository (assignment/lab_9_rubric.json, etc.) are used
directly so tests remain self-contained.
"""
import pytest
from grading_context import (
    build_cached_context_messages,
    build_system_message,
    load_text,
)


# ---------------------------------------------------------------------------
# load_text
# ---------------------------------------------------------------------------

def test_load_text_reads_utf8_file(tmp_path):
    f = tmp_path / "sample.txt"
    f.write_text("hello world", encoding="utf-8")
    assert load_text(f) == "hello world"


def test_load_text_accepts_string_path(tmp_path):
    f = tmp_path / "sample.txt"
    f.write_text("content", encoding="utf-8")
    assert load_text(str(f)) == "content"


def test_load_text_raises_for_missing_file():
    with pytest.raises(FileNotFoundError):
        load_text("/nonexistent/path/file.txt")


# ---------------------------------------------------------------------------
# build_system_message
# ---------------------------------------------------------------------------

def test_build_system_message_returns_dict():
    msg = build_system_message()
    assert isinstance(msg, dict)


def test_build_system_message_role_is_system():
    msg = build_system_message()
    assert msg.get("role") == "system"


def test_build_system_message_content_is_nonempty_string():
    msg = build_system_message()
    content = msg.get("content")
    assert isinstance(content, str) and len(content) > 0


# ---------------------------------------------------------------------------
# build_cached_context_messages
# ---------------------------------------------------------------------------

def test_build_cached_context_messages_returns_three_messages():
    msgs = build_cached_context_messages()
    assert len(msgs) == 3


def test_build_cached_context_messages_all_user_role():
    msgs = build_cached_context_messages()
    assert all(m["role"] == "user" for m in msgs)


def test_build_cached_context_messages_have_ephemeral_cache_control():
    msgs = build_cached_context_messages()
    for msg in msgs:
        assert msg.get("cache_control") == {"type": "ephemeral"}


def test_build_cached_context_messages_content_is_single_text_block():
    msgs = build_cached_context_messages()
    for msg in msgs:
        content = msg.get("content", [])
        assert isinstance(content, list) and len(content) == 1
        block = content[0]
        assert block.get("type") == "text"
        assert isinstance(block.get("text"), str) and len(block["text"]) > 0
