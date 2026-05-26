import os
from pathlib import Path
from dotenv import load_dotenv

# Single authoritative load of .env — all other modules import from here
load_dotenv()

BASE_DIR = Path(__file__).parent   # Python/anthropic/ directory

BASE_LAB_DIR = os.getenv("BASE_LAB_DIR")
if BASE_LAB_DIR is None:
    raise ValueError(
        "Environment variable BASE_LAB_DIR is not set. "
        "Please define BASE_LAB_DIR in your .env file."
    )
BASE_LAB_DIR = Path(BASE_LAB_DIR)

INSTRUCTIONS_PATH = BASE_DIR / "grader_instructions.txt"

MODEL      = "claude-opus-4-7"
MAX_TOKENS = 16000
Q_COUNT    = 10   # number of graded questions per lab

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


def build_system_blocks() -> list:
    """Build the Anthropic ``system`` parameter as a list of cached text blocks.

    Reads ``grader_instructions.txt`` (resolved via :data:`INSTRUCTIONS_PATH`)
    and wraps its content in a single text block tagged with
    ``"cache_control": {"type": "ephemeral"}``. The Anthropic Messages API
    accepts ``system`` either as a string or as a list of content blocks;
    the list form is required to attach cache breakpoints. Caching the
    grader instructions allows the prompt prefix to be reused across the
    full student batch, reducing both latency and token cost.

    :returns: A list with a single text block of the form
        ``[{"type": "text", "text": "<instructions>",
            "cache_control": {"type": "ephemeral"}}]``.
    :rtype: list[dict]
    :raises FileNotFoundError: If :data:`INSTRUCTIONS_PATH` does not exist.
    """
    instructions_text = load_text(INSTRUCTIONS_PATH)
    return [
        {
            "type": "text",
            "text": instructions_text,
            "cache_control": {"type": "ephemeral"},
        }
    ]


def build_cached_context_message() -> dict:
    """Build the shared rubric/starter/solution user message with caching.

    Loads the rubric JSON, starter ``.qmd`` template, and instructor
    solution (resolved via :data:`RUBRIC_PATH`, :data:`STARTER_PATH`, and
    :data:`SOLUTION_PATH`) and packs them as three text content blocks
    inside a single user message. Each block is tagged with
    ``"cache_control": {"type": "ephemeral"}`` so the Anthropic API can
    cache the shared prefix and reuse it across all student calls in the
    batch.

    Anthropic supports up to four cache breakpoints per request; using
    one breakpoint per file produces a monotonically growing cached
    prefix and matches the per-file structure of the OpenAI Python
    pipeline (which uses one cached message per file).

    :func:`configure` must be called before this function to set the
    lab-specific paths.

    :returns: A single user message dict whose ``content`` list contains
        three cached text blocks (rubric, starter, solution). Intended
        to be the first message in the request, before the per-student
        user message.
    :rtype: dict
    :raises FileNotFoundError: If any of :data:`RUBRIC_PATH`,
        :data:`STARTER_PATH`, or :data:`SOLUTION_PATH` do not exist.
    """
    rubric_text   = load_text(RUBRIC_PATH)
    starter_text  = load_text(STARTER_PATH)
    solution_text = load_text(SOLUTION_PATH)

    return {
        "role": "user",
        "content": [
            {
                "type": "text",
                "text": f"Rubric JSON for BSMM 8740 lab {LAB_NUMBER}:\n\n{rubric_text}",
                "cache_control": {"type": "ephemeral"},
            },
            {
                "type": "text",
                "text": f"Starter .qmd template for lab {LAB_NUMBER}:\n\n{starter_text}",
                "cache_control": {"type": "ephemeral"},
            },
            {
                "type": "text",
                "text": f"Solution .qmd for lab {LAB_NUMBER}:\n\n{solution_text}",
                "cache_control": {"type": "ephemeral"},
            },
        ],
    }


def build_grade_tool() -> dict:
    """Build the ``submit_grade`` tool schema used to enforce structured output.

    The Anthropic Messages API does not have a native ``json_object``
    response format. The recommended pattern for schema-constrained JSON
    output is forced tool use: define a tool whose ``input_schema`` is
    the desired output schema, then set ``tool_choice`` to require that
    tool. The model's tool call ``input`` is guaranteed to match the
    schema, eliminating the need for post-hoc JSON parsing or repair.

    :returns: A tool definition dict whose schema matches the grader
        instructions' required output (``questions``, ``total``,
        ``overall_comment``).
    :rtype: dict
    """
    return {
        "name": "submit_grade",
        "description": (
            "Submit the structured grade for the student's lab .qmd file. "
            "Call this tool exactly once with the per-question grades, "
            "the arithmetic total, and a 2-3 sentence overall comment."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "questions": {
                    "type": "object",
                    "description": (
                        "Map of question key (e.g. 'Q1') to a "
                        "{grade, feedback} object. Include one entry "
                        "per Ex<N> in the rubric."
                    ),
                    "additionalProperties": {
                        "type": "object",
                        "properties": {
                            "grade":    {"type": "number"},
                            "feedback": {"type": "string"},
                        },
                        "required": ["grade", "feedback"],
                    },
                },
                "total": {
                    "type": "number",
                    "description": "Arithmetic sum of the per-question grades.",
                },
                "overall_comment": {
                    "type": "string",
                    "description": "2-3 sentence summary of the submission.",
                },
            },
            "required": ["questions", "total", "overall_comment"],
        },
    }
