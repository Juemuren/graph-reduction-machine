"""Shared compiler and interpreter calls for example comparisons."""

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPILER = "lambda-compiler"
INTERPRETER = "ski-interpreter"
LIMIT_ERROR = "reduction exceeded step limit"
STEPS_PATTERN = r"^steps: (\d+)$"


def executable(name: str) -> str:
    result = subprocess.run(
        ["cabal", "list-bin", f"exe:{name}"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def compile_example(compiler: str, source: str, context: str) -> str:
    result = subprocess.run(
        [compiler],
        cwd=ROOT,
        input=source,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode:
        raise RuntimeError(f"{context}: {result.stderr.strip()}")
    return result.stdout


def decode(
    interpreter: str,
    graph: str,
    mode: str,
    max_steps: int,
    context: str,
    precision: int | None = None,
) -> tuple[int, str] | None:
    options = [interpreter, f"--decode={mode}"]
    if precision is not None:
        options.append(f"--precision-real={precision}")
    options.extend((f"--max-steps={max_steps}", "--show-steps"))
    result = subprocess.run(
        options,
        cwd=ROOT,
        input=graph,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode:
        if LIMIT_ERROR in result.stderr:
            return None
        raise RuntimeError(f"{context}: {result.stderr.strip()}")
    match = re.search(STEPS_PATTERN, result.stderr, re.MULTILINE)
    if match is None:
        raise RuntimeError(f"{context}: missing step count in {result.stderr!r}")
    return int(match.group(1)), result.stdout.strip()


def sources_in(directory: Path) -> list[Path]:
    sources = sorted(directory.glob("*.lambda"))
    if not sources:
        raise ValueError(f"no .lambda algorithms in {directory}")
    return sources
