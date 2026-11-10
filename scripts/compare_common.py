"""
Shared compiler and interpreter calls for example comparisons.
"""

import csv
import re
import subprocess
from collections.abc import Callable, Hashable, Iterable, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Generic, Literal, TypeVar

ROOT = Path(__file__).resolve().parents[1]
COMPILER = "lambda-compiler"
INTERPRETER = "ski-interpreter"
LIMIT_ERROR = "reduction exceeded step limit"
STEPS_PATTERN = r"^steps: (\d+)$"


Point = TypeVar("Point")
Key = TypeVar("Key", bound=Hashable)
Result = tuple[int, str] | None


@dataclass(frozen=True)
class MethodSpec(Generic[Point]):
    """Describe one method for ``measure_methods``.

    ``probe`` takes an input and step limit, returning (steps, value) or None.
    ``label`` formats that input for progress output.
    """

    name: str
    probe: Callable[[Point, int], Result]
    label: Callable[[Point], str]


@dataclass(frozen=True)
class Measurement(Generic[Point]):
    """Hold one result; steps and value are None when the limit was reached."""

    method: str
    input: Point
    steps: int | None
    value: str | None


def executable(name: str) -> str:
    """Find the built Cabal executable named by ``name``."""

    result = subprocess.run(
        ["cabal", "list-bin", f"exe:{name}"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def compile_example(
    compiler: str,
    source: str,
    context: str,
    encode: str | None = None,
) -> str:
    """Compile source text, using ``context`` to identify failures."""

    options = [compiler]
    if encode is not None:
        options.append(f"--encode={encode}")
    result = subprocess.run(
        options,
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
    """Decode a graph and return (steps, value), or None at the step limit.

    ``precision`` sets real-number decoding precision.
    ``context`` labels errors.
    """

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
    """List the directory's .lambda files, failing if there are none."""

    sources = sorted(directory.glob("*.lambda"))
    if not sources:
        raise ValueError(f"no .lambda algorithms in {directory}")
    return sources


def entry_source(source: Path, function: str, arguments: list[int]) -> str:
    """Build a source entry that imports and applies ``function``."""

    resolved = source.resolve()
    try:
        import_path = "./" + resolved.relative_to(ROOT).as_posix()
    except ValueError:
        import_path = resolved.as_posix()
    args = " ".join(map(str, arguments))
    return f'@< "{import_path}" ({function}); @! {function} {args};'


def measure_methods(
    methods: Iterable[MethodSpec[Point]],
    inputs: Sequence[Point],
    max_steps: int,
    *,
    on_limit: Literal["stop", "record"],
) -> list[Measurement[Point]]:
    """Measure every method over ``inputs`` in order and print each outcome.

    The same input sequence is reused for each method.
    ``on_limit="stop"`` skips the failed input and stops that method.
    ``on_limit="record"`` keeps a failed sample and continues to the next input.
    """

    samples: list[Measurement[Point]] = []
    for method in methods:
        for point in inputs:
            label = method.label(point)
            result = method.probe(point, max_steps)
            if result is None:
                print(f"{label}: exceeded {max_steps} steps")
                if on_limit == "stop":
                    break
                samples.append(Measurement(method.name, point, None, None))
            else:
                steps, value = result
                print(f"{label}: {steps} steps, {value}")
                samples.append(Measurement(method.name, point, steps, value))
    return samples


def check_agreement(
    results: Iterable[Measurement[Key]], context: str, input_label: Callable[[Key], str]
) -> None:
    """Require successful methods to decode each input to the same value.

    Limit results have no value and are skipped.
    ``input_label`` formats the input coordinates for a disagreement error.
    """

    values: dict[Key, Measurement[Key]] = {}
    for result in results:
        if result.value is None:
            continue
        previous = values.get(result.input)
        if previous is not None and previous.value != result.value:
            raise ValueError(
                f"{context}: methods disagree at {input_label(result.input)}: "
                f"{previous.method}={previous.value}, "
                f"{result.method}={result.value}"
            )
        values[result.input] = result


def write_csv_rows(
    path: Path, fields: tuple[str, ...], rows: Iterable[Sequence[str | int]]
) -> None:
    """Write a CSV header and rows, creating the output directory if needed."""

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(fields)
        writer.writerows(rows)
