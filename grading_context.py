import os
from pathlib import Path
from dotenv import load_dotenv

# Single authoritative load of .env — all other modules import from here
load_dotenv()

LAB_NUMBER = os.getenv("LAB_NUMBER")
if LAB_NUMBER is None:
    raise ValueError("Environment variable LAB_NUMBER is not set. Please define LAB_NUMBER in your .env file.")

BASE_DIR = Path(__file__).parent

# Dynamic file names
RUBRIC_PATH       = BASE_DIR / f"assignment/rubric_lab_{LAB_NUMBER}.json"
STARTER_PATH      = BASE_DIR / f"assignment/BSMM_8740_lab_{LAB_NUMBER}_starter.qmd"
SOLUTION_PATH     = BASE_DIR / f"assignment/BSMM_8740_lab_{LAB_NUMBER}_solutions.qmd"
INSTRUCTIONS_PATH = BASE_DIR / "grader_instructions.txt"

MODEL   = "gpt-5.1"
Q_COUNT = 10   # number of graded questions per lab


def load_text(path) -> str:
    """Accept either a Path object or a string file path."""
    path = Path(path)
    return path.read_text(encoding="utf-8")



def build_system_message() -> dict:
    """Return the system message with your grader instructions."""
    instructions_text = load_text(INSTRUCTIONS_PATH)
    return {
        "role": "system",
        "content": instructions_text
    }


def build_cached_context_messages() -> list:
    """
    Build the rubric + starter + solution messages,
    marked with cache_control so the API can reuse them across calls.
    """
    rubric_text = load_text(RUBRIC_PATH)
    starter_text = load_text(STARTER_PATH)
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
