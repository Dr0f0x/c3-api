#!/usr/bin/env python3
import argparse
import json
import os
import re
import signal
import subprocess
import time
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run all example projects from project.json and stop each after 5 seconds."
    )
    parser.add_argument(
        "-q",
        "--quiet",
        action="store_true",
        help="Only print target: <name> - PASSED or target: <name> - FAILED lines.",
    )
    return parser.parse_args()


def load_jsonc(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    text = re.sub(r"//.*?$", "", text, flags=re.MULTILINE)
    return json.loads(text)


def list_executable_targets(project: dict) -> list[str]:
    targets = project.get("targets", {})
    return sorted(
        name
        for name, config in targets.items()
        if isinstance(config, dict) and config.get("type") == "executable"
    )


def kill_process_group(proc: subprocess.Popen) -> None:
    if os.name == "nt":
        try:
            proc.send_signal(signal.CTRL_BREAK_EVENT)
        except OSError:
            pass
    else:
        if hasattr(os, "killpg"):
            try:
                os.killpg(proc.pid, signal.SIGTERM)
            except OSError:
                pass
        else:
            try:
                proc.terminate()
            except OSError:
                pass

    try:
        proc.kill()
    except OSError:
        pass


def run_example(
    root: Path, target: str, timeout: float = 5.0
) -> tuple[int | None, float, str, bool]:
    command = ["c3c", "run", target]
    creationflags = subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
    start_new_session = os.name != "nt"

    proc = subprocess.Popen(
        command,
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        creationflags=creationflags,
        start_new_session=start_new_session,
    )

    timed_out = False
    start_time = time.monotonic()
    try:
        output, _ = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        kill_process_group(proc)
        output, _ = proc.communicate(timeout=5)
    duration = time.monotonic() - start_time
    return proc.returncode, duration, output or "", timed_out


def main() -> int:
    args = parse_args()
    root = Path(__file__).resolve().parent.parent
    project_file = root / "project.json"

    if not project_file.exists():
        print(f"ERROR: project.json not found at {project_file}")
        return 1

    project = load_jsonc(project_file)
    targets = list_executable_targets(project)

    if not targets:
        print("No executable targets found in project.json.")
        return 1

    if not args.quiet:
        print("Running example projects from project.json")
        print("Targets:")
        for target in targets:
            print(f"  - {target}")
        print()

    all_passed = True

    for target in targets:
        return_code, duration, output, timed_out = run_example(root, target)

        if timed_out:
            result = "PASSED"
        elif return_code != 0:
            result = "FAILED"
            all_passed = False
        else:
            result = "PASSED"

        if args.quiet:
            print(f"target: {target} - {result}")
            continue

        print("=" * 80)
        print(f"Target: {target}")
        print(f"Command: c3c run {target}")
        print("Timeout: 5 seconds")
        print("-" * 80)

        if timed_out:
            print(
                f"Result: {result} (timed out after {duration:.1f}s; process was stopped)"
            )
        elif return_code != 0:
            print(f"Result: {result} (exit code {return_code})")
        else:
            print(f"Result: {result} (exit code 0, duration {duration:.1f}s)")

        print("Output:")
        if output.strip():
            for line in output.strip().splitlines():
                print(f"[{target}] {line}")
        else:
            print(f"[{target}] <no output>")

        print()

    if not args.quiet:
        print("=" * 80)
        if all_passed:
            print("All example projects completed with exit code 0.")
            return 0

        print("Some example projects failed or timed out. See details above.")
        return 1

    return 0 if all_passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
