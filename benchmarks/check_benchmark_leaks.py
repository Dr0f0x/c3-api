#!/usr/bin/env python3
import argparse
import csv
import os
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_CSV = Path(__file__).resolve().parent.parent / "out" / "routing_benchmarks_memory.csv"
REQUIRED_COLUMNS = {"benchmark", "label", "leaked_allocs", "leaked_bytes"}

RESET = "\033[0m"
RED = "\033[31m"
GREEN = "\033[32m"
BOLD = "\033[1m"


@dataclass
class LeakStats:
    samples: int = 0
    max_allocs: int = 0
    max_bytes: int = 0
    labels: set[str] = field(default_factory=set)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Highlight benchmark functions that report allocation leaks."
    )
    parser.add_argument(
        "csv_file",
        nargs="?",
        type=Path,
        default=DEFAULT_CSV,
        help=f"Benchmark memory CSV to inspect (default: {DEFAULT_CSV}).",
    )
    parser.add_argument(
        "--no-color",
        action="store_true",
        help="Disable ANSI colors.",
    )
    parser.add_argument(
        "--fail-on-leak",
        action="store_true",
        help="Exit with status 1 when any leak is found.",
    )
    return parser.parse_args()


def paint(text: str, color: str, enabled: bool) -> str:
    return f"{color}{text}{RESET}" if enabled else text


def heading(text: str, color: str, enabled: bool) -> str:
    return paint(text, BOLD + color, enabled)


def parse_int(value: str | None) -> int:
    try:
        return int(value or 0)
    except ValueError:
        return 0


def read_leaks(csv_path: Path) -> dict[str, LeakStats]:
    leaks: dict[str, LeakStats] = defaultdict(LeakStats)

    with csv_path.open(newline="", encoding="utf-8-sig") as file:
        reader = csv.DictReader(file)
        missing = REQUIRED_COLUMNS - set(reader.fieldnames or [])
        if missing:
            columns = ", ".join(sorted(missing))
            raise ValueError(f"missing required column(s): {columns}")

        for row in reader:
            benchmark = (row.get("benchmark") or "").strip()
            if not benchmark:
                continue

            stats = leaks[benchmark]
            stats.samples += 1
            label = (row.get("label") or "").strip()
            if label:
                stats.labels.add(label)
            stats.max_allocs = max(stats.max_allocs, parse_int(row.get("leaked_allocs")))
            stats.max_bytes = max(stats.max_bytes, parse_int(row.get("leaked_bytes")))

    return leaks


def print_leaks(leaks: list[tuple[str, LeakStats]], color: bool) -> None:
    print(heading(f"LEAKS ({len(leaks)})", RED, color))
    print("  Worst leak observed per benchmark (max across samples):")
    for benchmark, stats in leaks:
        name = paint(f"{benchmark:<32}", RED, color)
        print(
            f"  {name} {stats.max_allocs:>10,} allocs "
            f"{stats.max_bytes:>14,} bytes "
            f"({stats.samples} sample{'s' if stats.samples != 1 else ''})"
        )


def main() -> int:
    args = parse_args()
    color = not args.no_color and "NO_COLOR" not in os.environ and sys.stdout.isatty()

    try:
        leaks = read_leaks(args.csv_file)
    except OSError as error:
        print(f"error: cannot read {args.csv_file}: {error}", file=sys.stderr)
        return 2
    except (csv.Error, ValueError) as error:
        print(f"error: invalid CSV {args.csv_file}: {error}", file=sys.stderr)
        return 2

    leaky = sorted(
        (
            (benchmark, stats)
            for benchmark, stats in leaks.items()
            if stats.max_allocs > 0 or stats.max_bytes > 0
        ),
        key=lambda item: (-item[1].max_bytes, -item[1].max_allocs, item[0]),
    )
    clean = sorted(
        benchmark
        for benchmark, stats in leaks.items()
        if stats.max_allocs == 0 and stats.max_bytes == 0
    )

    print(f"Leak report: {args.csv_file}")
    print()

    if leaky:
        print_leaks(leaky, color)
    else:
        print(paint("No leaks detected.", GREEN, color))

    if clean:
        print()
        print(heading(f"CLEAN ({len(clean)})", GREEN, color))
        for benchmark in clean:
            print(f"  {paint(benchmark, GREEN, color)}")

    if args.fail_on_leak and leaky:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
