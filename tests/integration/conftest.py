"""Session-scoped fixtures for the c3-api integration tests.

The fixtures package the repository source as a ``c3api.c3l`` library, build
the standalone test application against that package, and launch the
compiled server for the duration of the test session.
"""

from __future__ import annotations

import json
import os
import shutil
import socket
import subprocess
import time
import urllib.error
import urllib.request
import zipfile
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
APP_DIR = Path(__file__).resolve().parent / "test_app"
APP_TARGET = "integration-app"
C3L_NAME = "c3api.c3l"


def _report(config: pytest.Config, message: str) -> None:
    """Write a progress message to pytest's terminal reporter.

    Args:
        config: Active pytest configuration used to locate the terminal reporter.
        message: Human-readable progress message.
    """
    reporter: Any = config.pluginmanager.getplugin("terminalreporter")
    if reporter is not None:
        reporter.write_line(message)
        reporter.flush()
    else:
        print(message, flush=True)


def _build_c3l(destination: Path, config: pytest.Config) -> Path:
    """Package the framework sources into a ``c3api.c3l`` archive.

    All C3 sources are flattened into the archive root. Nested source paths are
    prefixed with ``__`` so files with the same basename, such as
    ``middleware.c3`` and ``routing/middleware.c3``, do not overwrite each other.

    Args:
        destination: Path where the finished ``c3api.c3l`` archive is written.
        config: Active pytest configuration used for progress reporting.

    Returns:
        The path to the created ``c3api.c3l`` archive.
    """
    _report(config, f"integration: building {C3L_NAME}")

    staging = destination.parent / "c3api-package"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)

    source_root = REPO_ROOT / "src"
    for source_file in sorted(source_root.rglob("*.c3")):
        relative = source_file.relative_to(source_root)
        archive_name = "__".join(relative.parts)
        shutil.copy2(source_file, staging / archive_name)

    shutil.copy2(REPO_ROOT / "manifest.json", staging / "manifest.json")

    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for entry in sorted(staging.iterdir()):
            if entry.is_file():
                archive.write(entry, entry.name)

    _report(config, f"integration: built {C3L_NAME} at {destination}")
    return destination


def _build_app(c3l_file: Path, workspace: Path, config: pytest.Config) -> tuple[Path, Path]:
    """Build the standalone test application against a packaged library.

    The test application is copied into ``workspace`` so the repository stays
    clean. The supplied ``c3api.c3l`` is installed into the application's
    ``lib`` directory before running ``c3c``.

    Args:
        c3l_file: Packaged ``c3api.c3l`` library used as a dependency.
        workspace: Temporary directory that receives the copied application.
        config: Active pytest configuration used for progress reporting.

    Returns:
        A tuple containing the application directory and the compiled binary.

    Raises:
        RuntimeError: If the application fails to build or the binary is missing.
    """
    _report(config, "integration: building test app against c3api.c3l")

    app_dir = workspace / "test_app"
    shutil.copytree(APP_DIR, app_dir)

    lib_dir = app_dir / "lib"
    lib_dir.mkdir()
    shutil.copy2(c3l_file, lib_dir / C3L_NAME)

    result = subprocess.run(
        ["c3c", "build", APP_TARGET],
        cwd=app_dir,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"failed to build integration app\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )

    binary = app_dir / "build" / APP_TARGET
    if os.name == "nt":
        binary = binary.with_suffix(".exe")
    if not binary.exists():
        raise RuntimeError(f"integration app binary not found at {binary}")

    _report(config, f"integration: built test app at {binary}")
    return app_dir, binary


def _free_port() -> int:
    """Return an available localhost TCP port.

    Returns:
        A port number that was free when checked.
    """
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def _write_config(app_dir: Path, port: int) -> None:
    """Write a minimal server configuration for the test application.

    Args:
        app_dir: Working directory where ``c3api.conf.json`` is written.
        port: Port the server should listen on.
    """
    config = {
        "address": "127.0.0.1",
        "port": port,
        "logging": {
            "console": {"enabled": False},
            "file": {"enabled": False},
        },
    }
    (app_dir / "c3api.conf.json").write_text(json.dumps(config, indent=2), encoding="utf-8")


def _wait_until_ready(
    process: subprocess.Popen,
    base_url: str,
    log_path: Path,
    timeout: float = 15.0,
) -> None:
    """Wait until the application responds successfully on its health endpoint.

    Args:
        process: Running application process.
        base_url: Base URL of the application server.
        log_path: File receiving the application's stdout and stderr.
        timeout: Maximum number of seconds to wait for readiness.

    Raises:
        RuntimeError: If the application exits before becoming ready.
        TimeoutError: If the application does not become ready before ``timeout``.
    """
    deadline = time.monotonic() + timeout

    while time.monotonic() < deadline:
        if process.poll() is not None:
            log = log_path.read_text(encoding="utf-8", errors="replace")
            raise RuntimeError(f"integration app exited with code {process.returncode}\n{log}")

        try:
            with urllib.request.urlopen(f"{base_url}/health", timeout=0.5) as response:
                if response.status == 200:
                    return
        except (urllib.error.URLError, TimeoutError):
            pass

        time.sleep(0.1)

    log = log_path.read_text(encoding="utf-8", errors="replace")
    raise TimeoutError(f"integration app did not become ready\n{log}")


def _stop_process(process: subprocess.Popen) -> None:
    """Stop the application process, killing it if it does not exit gracefully.

    Args:
        process: Running application process.
    """
    if process.poll() is not None:
        return

    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


@pytest.fixture(scope="session")
def c3api_c3l(tmp_path_factory: pytest.TempPathFactory, request: pytest.FixtureRequest) -> Path:
    """Build the framework package once per test session.

    Args:
        tmp_path_factory: Pytest factory for temporary directories.
        request: Fixture request providing access to the pytest configuration.

    Returns:
        Path to the generated ``c3api.c3l`` archive.
    """
    destination = tmp_path_factory.mktemp("c3api") / C3L_NAME
    return _build_c3l(destination, request.config)


@pytest.fixture(scope="session")
def app_binary(
    c3api_c3l: Path,
    tmp_path_factory: pytest.TempPathFactory,
    request: pytest.FixtureRequest,
) -> tuple[Path, Path]:
    """Build the standalone test application against the packaged library.

    Args:
        c3api_c3l: Packaged framework library used as the application dependency.
        tmp_path_factory: Pytest factory for temporary directories.
        request: Fixture request providing access to the pytest configuration.

    Returns:
        A tuple containing the application directory and compiled binary path.
    """
    workspace = tmp_path_factory.mktemp("integration-app")
    return _build_app(c3api_c3l, workspace, request.config)


@pytest.fixture(scope="session")
def server_url(app_binary: tuple[Path, Path], request: pytest.FixtureRequest) -> Iterator[str]:
    """Run the integration application and yield its base URL.

    The application listens on an available localhost port. The fixture waits
    until its ``/health`` endpoint succeeds before yielding, then always stops
    the process during teardown.

    Args:
        app_binary: Application directory and compiled binary from ``app_binary``.
        request: Fixture request providing access to the pytest configuration.

    Yields:
        The base URL of the running application, such as ``http://127.0.0.1:8000``.
    """
    app_dir, binary = app_binary
    port = _free_port()
    _write_config(app_dir, port)

    base_url = f"http://127.0.0.1:{port}"
    log_path = app_dir / "server.log"

    _report(request.config, f"integration: starting test app on {base_url}")

    with log_path.open("wb", buffering=0) as log_file:
        process = subprocess.Popen(
            [str(binary)],
            cwd=app_dir,
            stdout=log_file,
            stderr=subprocess.STDOUT,
        )
        try:
            _wait_until_ready(process, base_url, log_path)
            _report(request.config, f"integration: test app ready at {base_url}")
            yield base_url
        finally:
            _report(request.config, "integration: stopping test app")
            _stop_process(process)
