#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANUSCRIPT="$REPO_ROOT/MANUSCRIPT.md"
COVER_IMAGE="$REPO_ROOT/cover.png"
OUTPUT_EPUB="$REPO_ROOT/The Two Alexes.epub"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

require_file() {
  if [[ ! -f "$1" ]]; then
    printf 'Required file not found: %s\n' "$1" >&2
    exit 1
  fi
}

require_command pandoc
require_file "$SCRIPT_DIR/generate-manuscript.sh"
require_file "$COVER_IMAGE"

bash "$SCRIPT_DIR/generate-manuscript.sh"
require_file "$MANUSCRIPT"

pandoc "$MANUSCRIPT" \
  --from markdown \
  --to epub3 \
  --toc \
  --toc-depth=2 \
  --split-level=2 \
  --metadata title="The Two Alexes" \
  --metadata author="Joshua Szepietowski" \
  --metadata lang="en-US" \
  --resource-path="$REPO_ROOT" \
  --epub-cover-image="$COVER_IMAGE" \
  --output "$OUTPUT_EPUB"

printf 'Generated: %s\n' "$OUTPUT_EPUB"
