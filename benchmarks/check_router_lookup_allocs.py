#!/usr/bin/env python3
"""Check that router route+handler lookup benchmarks allocate nothing.

The C3 routing benchmarks write one memory row per sample to the routing
memory CSV. This script selects the focused ``router_resolve_*`` benchmarks
and fails when any sample reports an allocation on the lookup path.
"""

import argparse
import csv
import os
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_CSV = Path(__file__).resolve().parent.parent / "out" / "routing_benchmarks_memory.csv"
BENCHMARK_PREFIX = "router_resolve_"
REQUIRED_COLUMNS = {
    "benchmark",
    "label",
    "allocs",
    "bytes",
    "allocs_per_op",
    "bytes_per_op",
}

RESET = "\033[0m"
RED = "\033[31m"
GREEN = "\033[32m"
BOLD = "\033[1m"


@dataclass
class LookupStats:
    samples: int = 0
    max_allocs: int = 0
    max_bytes: int = 0
    max_allocs_per_op: float = 0.0
    labels: set[str] = field(default_factory=set)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Verify that focused router route+handler lookup benchmarks "
            "report zero allocations."
        )
    )
    parser.add_argument(
        "csv_file",
        nargs="?",
        type=Path,
        default=DEFAULT_CSV,
        help=f"Routing benchmark memory CSV to inspect (default: {DEFAULT_CSV}).",
    )
    parser.add_argument(
        "--no-color",
        action="store_true",
        help="Disable ANSI colors.",
    )
    parser.add_argument(
        "--report-only",
        action="store_true",
        help="Report results but exit successfully even when allocations are found.",
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


def parse_float(value: str | None) -> float:
    try:
        return float(value or 0.0)
    except ValueError:
        return 0.0


def read_lookup_stats(csv_path: Path) -> dict[str, LookupStats]:
    stats: dict[str, LookupStats] = defaultdict(LookupStats)

    with csv_path.open(newline="", encoding="utf-8-sig") as file:
        reader = csv.DictReader(file)
        missing = REQUIRED_COLUMNS - set(reader.fieldnames or [])
        if missing:
            columns = ", ".join(sorted(missing))
            raise ValueError(f"missing required column(s): {columns}")

        for row in reader:
            benchmark = (row.get("benchmark") or "").strip()
            if not benchmark.startswith(BENCHMARK_PREFIX):
                continue

            entry = stats[benchmark]
            entry.samples += 1
            label = (row.get("label") or "").strip()
            if label:
                entry.labels.add(label)
            entry.max_allocs = max(entry.max_allocs, parse_int(row.get("allocs")))
            entry.max_bytes = max(entry.max_bytes, parse_int(row.get("bytes")))
            entry.max_allocs_per_op = max(
                entry.max_allocs_per_op,
                parse_float(row.get("allocs_per_op")),
            )

    return stats


def print_stats(stats: dict[str, LookupStats], color: bool) -> None:
    print(heading("ROUTER LOOKUP ALLOCATIONS", BOLD, color))
    print("  Worst allocation count observed per lookup benchmark:")
    for benchmark in sorted(stats):
        entry = stats[benchmark]
        status = "PASS" if entry.max_allocs == 0 else "FAIL"
        status_color = GREEN if status == "PASS" else RED
        name = paint(f"{benchmark:<42}", status_color, color)
        status_text = paint(status, status_color, color)
        labels = ", ".join(sorted(entry.labels))
        print(
            f"  {name} {status_text:<4} "
            f"allocs={entry.max_allocs:>6,} "
            f"bytes={entry.max_bytes:>10,} "
            f"allocs/op={entry.max_allocs_per_op:.6f} "
            f"samples={entry.samples} "
            f"[{labels}]"
        )


def main() -> int:
    args = parse_args()
    color = not args.no_color and "NO_COLOR" not in os.environ and sys.stdout.isatty()

    try:
        stats = read_lookup_stats(args.csv_file)
    except OSError as error:
        print(f"error: cannot read {args.csv_file}: {error}", file=sys.stderr)
        return 2
    except (csv.Error, ValueError) as error:
        print(f"error: invalid CSV {args.csv_file}: {error}", file=sys.stderr)
        return 2

    if not stats:
        print(
            f"error: no benchmarks starting with {BENCHMARK_PREFIX!r} in {args.csv_file}",
            file=sys.stderr,
        )
        return 2

    print(f"Lookup report: {args.csv_file}")
    print()
    print_stats(stats, color)

    failing = sorted(
        benchmark
        for benchmark, entry in stats.items()
        if entry.max_allocs > 0 or entry.max_allocs_per_op > 0.0
    )

    print()
    if failing:
        print(
            paint(
                f"FAIL: {len(failing)} lookup benchmark(s) allocated on the lookup path.",
                RED,
                color,
            )
        )
        if args.report_only:
            return 0
        return 1

    print(
        paint(
            f"PASS: all {len(stats)} lookup benchmarks reported zero allocations.",
            GREEN,
            color,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
