# /// script
# requires-python = ">=3.11"
# dependencies = ["matplotlib>=3.10,<4"]
# ///
"""Measure real-number examples and plot their accuracy against reduction steps."""

import argparse
import csv
import re
import subprocess
from collections import defaultdict
from dataclasses import dataclass
from decimal import Decimal, localcontext
from fractions import Fraction
from pathlib import Path

import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ("method", "n", "steps", "value", "abs_error")
LIMIT_ERROR = "reduction exceeded step limit"
STEPS_PATTERN = r"^steps: (\d+)$"
COMPILER = "lambda-to-graph"
INTERPRETER = "ski-interpreter"


@dataclass(frozen=True)
class Sample:
    method: str
    index: int
    steps: int
    value: str
    error: Decimal


def executable(name: str) -> str:
    result = subprocess.run(
        ["cabal", "list-bin", f"exe:{name}"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def compile_example(compiler: str, source: Path) -> str:
    result = subprocess.run(
        [compiler],
        cwd=ROOT,
        input=source.read_text(encoding="utf-8"),
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode:
        raise RuntimeError(f"{source}: {result.stderr.strip()}")
    return result.stdout


def decode(
    interpreter: str, graph: str, index: int, max_steps: int
) -> tuple[int, str] | None:
    result = subprocess.run(
        [
            interpreter,
            "--decode=real",
            f"--precision-real={index}",
            f"--max-steps={max_steps}",
            "--show-steps",
        ],
        cwd=ROOT,
        input=graph,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode:
        if LIMIT_ERROR in result.stderr:
            return None
        raise RuntimeError(f"n={index}: {result.stderr.strip()}")
    match = re.search(STEPS_PATTERN, result.stderr, re.MULTILINE)
    if match is None:
        raise RuntimeError(f"n={index}: missing step count in {result.stderr!r}")
    return int(match.group(1)), result.stdout.strip()


def measure(directory: Path, max_index: int, max_steps: int) -> list[dict[str, str]]:
    sources = sorted(directory.glob("*.lambda"))
    if not sources:
        raise ValueError(f"no .lambda algorithms in {directory}")
    compiler = executable(COMPILER)
    interpreter = executable(INTERPRETER)
    rows = []
    for source in sources:
        graph = compile_example(compiler, source)
        for index in range(max_index + 1):
            result = decode(interpreter, graph, index, max_steps)
            if result is None:
                print(f"{source.stem} n={index}: exceeded {max_steps} steps")
                break
            steps, value = result
            print(f"{source.stem} n={index}: {steps} steps, {value}")
            rows.append(
                {
                    "method": source.stem,
                    "n": str(index),
                    "steps": str(steps),
                    "value": value,
                }
            )
    return rows


def write_csv(path: Path, samples: list[Sample]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(
            {
                "method": sample.method,
                "n": sample.index,
                "steps": sample.steps,
                "value": sample.value,
                "abs_error": str(sample.error),
            }
            for sample in samples
        )


def make_samples(rows: list[dict[str, str]], exact: Decimal) -> list[Sample]:
    samples = []
    for row in rows:
        value = Fraction(row["value"])
        with localcontext() as context:
            context.prec = max(50, len(exact.as_tuple().digits) + 20)
            approximation = Decimal(value.numerator) / Decimal(value.denominator)
            error = abs(approximation - exact)
        samples.append(
            Sample(
                row["method"],
                int(row["n"]),
                int(row["steps"]),
                row["value"],
                error,
            )
        )
    if not samples:
        raise ValueError("no successful measurements")
    return samples


def pareto_frontier(samples: list[Sample]) -> list[Sample]:
    frontier = []
    best_error = Decimal("Infinity")
    for sample in sorted(samples, key=lambda item: (item.steps, item.error)):
        if sample.error < best_error:
            frontier.append(sample)
            best_error = sample.error
    return frontier


def plot(samples: list[Sample], output: Path) -> None:
    grouped: dict[str, list[Sample]] = defaultdict(list)
    for sample in samples:
        grouped[sample.method].append(sample)

    positive_errors = [float(sample.error) for sample in samples if sample.error > 0]
    zero_floor = min(positive_errors) / 10 if positive_errors else 1e-12

    def y(sample: Sample) -> float:
        return float(sample.error) if sample.error > 0 else zero_floor

    figure, axis = plt.subplots(figsize=(11, 7))
    colors = plt.get_cmap("tab10")
    for number, (method, points) in enumerate(sorted(grouped.items())):
        points.sort(key=lambda item: item.index)
        color = colors(number % 10)
        axis.plot(
            [point.steps for point in points],
            [y(point) for point in points],
            color=color,
            alpha=0.65,
            linewidth=1.5,
        )
        axis.scatter(
            [point.steps for point in points],
            [y(point) for point in points],
            color=color,
            s=55,
            label=method,
            zorder=3,
        )
        for point in points:
            axis.annotate(
                f"n={point.index}",
                (point.steps, y(point)),
                xytext=(5, 5),
                textcoords="offset points",
            )

    frontier = pareto_frontier(samples)
    axis.plot(
        [point.steps for point in frontier],
        [y(point) for point in frontier],
        color="black",
        linestyle="--",
        linewidth=2,
        marker="x",
        markersize=8,
        label="Pareto frontier",
        zorder=4,
    )
    axis.set(
        xscale="log",
        yscale="log",
        xlabel="Reduction steps",
        ylabel="Absolute error",
    )
    axis.set_title("Real-number approximation: steps vs error")
    axis.grid(True, which="both", alpha=0.25)
    axis.legend()
    figure.tight_layout()
    output.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(output, dpi=180)
    plt.close(figure)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "directory",
        type=Path,
        help="directory containing .lambda algorithms",
    )
    parser.add_argument(
        "--exact-value",
        required=True,
        type=Decimal,
    )
    parser.add_argument(
        "--max-steps",
        type=int,
        default=10_000_000,
        help="maximum reduction steps",
    )
    parser.add_argument(
        "--max-index",
        type=int,
        default=10,
        help="maximum index",
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=argparse.SUPPRESS,
        help="output CSV",
    )
    parser.add_argument(
        "--plot",
        type=Path,
        default=argparse.SUPPRESS,
        help="output PNG",
    )
    args = parser.parse_args()
    if args.max_steps <= 0:
        parser.error("--max-steps must be positive")
    if args.max_index < 0:
        parser.error("--max-index must be nonnegative")
    return args


def main() -> None:
    args = parse_args()
    csv_path = getattr(args, "csv", args.directory / "steps-vs-error.csv")
    plot_path = getattr(args, "plot", args.directory / "steps-vs-error.png")

    rows = measure(args.directory, args.max_index, args.max_steps)
    samples = make_samples(rows, args.exact_value)
    write_csv(csv_path, samples)
    plot(samples, plot_path)
    print(f"Saved {csv_path} and {plot_path}")


if __name__ == "__main__":
    main()
