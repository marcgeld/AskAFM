#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$SCRIPT_DIR/docs"
OUTPUT_FILE="$DOCS_DIR/askafm.md"
DOCC_SOURCE="$SCRIPT_DIR/Sources/askafm/askafm.docc/askafm.md"

mkdir -p "$DOCS_DIR"

{
    sed \
        -e 's/# ``askafm``/# askafm/' \
        -e 's/``AskAFM``/`AskAFM`/g' \
        "$DOCC_SOURCE"
    printf '\n'
    printf '## Architecture\n\n'
    printf 'See [FilterModeArchitecture.md](FilterModeArchitecture.md) for the filter-mode architecture, configuration model, and generated documentation workflow.\n'
} > "$OUTPUT_FILE"

printf 'Generated Markdown documentation at %s\n' "$OUTPUT_FILE"
