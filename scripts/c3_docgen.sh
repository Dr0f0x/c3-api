#!/usr/bin/env bash

set -euo pipefail

# scripts/ -> project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "Generating C3 documentation..."
echo "Project root: $PROJECT_ROOT"

mapfile -t SOURCES < <(find ./src -type f -name "*.c3")

if [[ ${#SOURCES[@]} -eq 0 ]]; then
    echo "Error: No .c3 files found."
    exit 1
fi

c3c docgen "${SOURCES[@]}" --emit-stdlib=no

echo "Documentation generated successfully."