"""Shared compiler and interpreter calls for example comparisons."""

import csv
import re
import subprocess
from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPILER = "lambda-compiler"
INTERPRETER = "ski-interpreter"
LIMIT_ERROR = "reduction exceeded step limit"
STEPS_PATTERN = r"^steps: (\d+)$"


@dataclass(frozen=True)
class Measurement:
    method: str
    index: int
    steps: int
    value: str


Probe = Callable[[int, int], tuple[int, str] | None]
Prepare = Callable[[Path, str, str], Probe]


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


def measure_algorithms(
    directory: Path, max_index: int, max_steps: int, prepare: Prepare
) -> list[Measurement]:
    sources = sources_in(directory)
    compiler = executable(COMPILER)
    interpreter = executable(INTERPRETER)
    samples = []
    for source in sources:
        probe = prepare(source, compiler, interpreter)
        for index in range(max_index + 1):
            result = probe(index, max_steps)
            if result is None:
                print(f"{source.stem} n={index}: exceeded {max_steps} steps")
                break
            steps, value = result
            print(f"{source.stem} n={index}: {steps} steps, {value}")
            samples.append(Measurement(source.stem, index, steps, value))
    if not samples:
        raise ValueError("no successful measurements")
    return samples


def write_csv_rows(
    path: Path, fields: tuple[str, ...], rows: Iterable[Mapping[str, str | int]]
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
