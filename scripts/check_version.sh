#!/usr/bin/env bash

set -euo pipefail

PROJECT_FILE="project.json"
PYPROJECT_FILE="pyproject.toml"

if [[ ! -f "$PROJECT_FILE" ]]; then
    echo "Error: $PROJECT_FILE not found."
    echo "Please run this script from the project root."
    exit 1
fi

if [[ ! -f "$PYPROJECT_FILE" ]]; then
    echo "Error: $PYPROJECT_FILE not found."
    echo "Please run this script from the project root."
    exit 1
fi

# C3 project.json allows comments, so extract the version with grep/sed.
C3_VERSION="$(
    grep -E '^[[:space:]]*"version"[[:space:]]*:' "$PROJECT_FILE" |
    head -n 1 |
    sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
)"

# Extract version from the [project] section of pyproject.toml.
PYPROJECT_VERSION="$(
    awk '
        /^\[project\]/ {
            in_project=1
            next
        }

        /^\[/ {
            in_project=0
        }

        in_project && /^[[:space:]]*version[[:space:]]*=/ {
            match($0, /"[^"]+"/)

            if (RSTART) {
                print substr($0, RSTART + 1, RLENGTH - 2)
                exit
            }
        }
    ' "$PYPROJECT_FILE"
)"

if [[ -z "$C3_VERSION" ]]; then
    echo "Error: Could not find version in $PROJECT_FILE."
    exit 1
fi

if [[ -z "$PYPROJECT_VERSION" ]]; then
    echo "Error: Could not find [project].version in $PYPROJECT_FILE."
    exit 1
fi

echo "C3 project version:     $C3_VERSION"
echo "Python project version: $PYPROJECT_VERSION"

if [[ "$C3_VERSION" != "$PYPROJECT_VERSION" ]]; then
    echo
    echo "Version mismatch!"
    echo "  project.json:   $C3_VERSION"
    echo "  pyproject.toml: $PYPROJECT_VERSION"
    exit 1
fi

echo
echo "Version check passed: $C3_VERSION"