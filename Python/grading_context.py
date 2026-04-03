import os
from pathlib import Path
from dotenv import load_dotenv

# Single authoritative load of .env — all other modules import from here
load_dotenv()

BASE_DIR     = Path(__file__).parent   # Python/ directory

BASE_LAB_DIR = os.getenv("BASE_LAB_DIR")
if BASE_LAB_DIR is None:
    raise ValueError(
        "Environment variable BASE_LAB_DIR is not set. "
        "Please define BASE_LAB_DIR in your .env file."
    )
BASE_LAB_DIR = Path(BASE_LAB_DIR)

INSTRUCTIONS_PATH = BASE_DIR / "grader_instructions.txt"

MODEL   = "gpt-5.1"
Q_COUNT = 10   # number of graded questions per lab

# Set by configure() before grading begins; None until then.
LAB_NUMBER    = None
RUBRIC_PATH   = None
STARTER_PATH  = None
SOLUTION_PATH = None


def configure(lab_number: int) -> None:
    """Set the lab number and recompute all lab-specific file paths.

    Must be called once before any grading functions are invoked.
    Subsequent calls update the module globals in place, allowing the
    same process to grade a different lab without restarting.

    :param lab_number: Integer lab number (e.g. ``4`` or ``9``).
    :type lab_number: int
    """
    global LAB_NUMBER, RUBRIC_PATH, STARTER_PATH, SOLUTION_PATH
    LAB_NUMBER    = int(lab_number)
    RUBRIC_PATH   = BASE_LAB_DIR / f"lab_{LAB_NUMBER}_rubric.json"
    STARTER_PATH  = BASE_LAB_DIR / f"lab_{LAB_NUMBER}_starter.qmd"
    SOLUTION_PATH = BASE_LAB_DIR / f"lab_{LAB_NUMBER}_solutions.qmd"


def load_text(path) -> str:
    """Read a file and return its full contents as a UTF-8 string.

    Accepts either a :class:`pathlib.Path` object or a plain string path,
    coercing the argument to :class:`pathlib.Path` before reading.

    :param path: Path to the file to read.
    :type path: pathlib.Path or str
    :returns: The complete text content of the file decoded as UTF-8.
    :rtype: str
    :raises FileNotFoundError: If *path* does not exist on the filesystem.
    """
    path = Path(path)
    return path.read_text(encoding="utf-8")


def build_system_message() -> dict:
    """Build the OpenAI system message containing the grader instructions.

    Reads ``grader_instructions.txt`` (resolved via :data:`INSTRUCTIONS_PATH`)
    and wraps its content in an OpenAI-compatible message dict with
    ``role="system"``. This message should be placed first in the message
    list passed to the Chat Completions API.

    :returns: A message dict of the form
        ``{"role": "system", "content": "<instructions text>"}``.
    :rtype: dict
    :raises FileNotFoundError: If :data:`INSTRUCTIONS_PATH` does not exist.
    """
    instructions_text = load_text(INSTRUCTIONS_PATH)
    return {
        "role": "system",
        "content": instructions_text
    }


def build_cached_context_messages() -> list:
    """Build the three shared context messages with ephemeral prompt caching.

    Loads the rubric JSON, starter ``.qmd`` template, and instructor solution
    (resolved via :data:`RUBRIC_PATH`, :data:`STARTER_PATH`, and
    :data:`SOLUTION_PATH`) and wraps each in an OpenAI user message tagged
    with ``"cache_control": {"type": "ephemeral"}``. This instructs the
    OpenAI API to cache the key-value representation of this shared prefix
    and reuse it across the full student batch, reducing both latency and
    token cost.

    :func:`configure` must be called before this function to set the
    lab-specific paths.

    :returns: A list of three OpenAI message dicts — rubric, starter, and
        solution — each marked for ephemeral caching. Intended to be
        positioned after the system message and before the per-student
        user message.
    :rtype: list[dict]
    :raises FileNotFoundError: If any of :data:`RUBRIC_PATH`,
        :data:`STARTER_PATH`, or :data:`SOLUTION_PATH` do not exist.
    """
    rubric_text   = load_text(RUBRIC_PATH)
    starter_text  = load_text(STARTER_PATH)
    solution_text = load_text(SOLUTION_PATH)

    context_msgs = [
        {
            "role": "user",
            "cache_control": {"type": "ephemeral"},
            "content": [
                {
                    "type": "text",
                    "text": f"Rubric JSON for BSMM 8740 lab {LAB_NUMBER}:\n\n" + rubric_text
                }
            ]
        },
        {
            "role": "user",
            "cache_control": {"type": "ephemeral"},
            "content": [
                {
                    "type": "text",
                    "text": f"Starter .qmd template for lab {LAB_NUMBER}:\n\n" + starter_text
                }
            ]
        },
        {
            "role": "user",
            "cache_control": {"type": "ephemeral"},
            "content": [
                {
                    "type": "text",
                    "text": f"Solution .qmd for lab {LAB_NUMBER}:\n\n" + solution_text
                }
            ]
        }
    ]

    return context_msgs
