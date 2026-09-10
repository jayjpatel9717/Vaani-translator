#!/bin/bash
# Renders every screen of the app to PNG (no window, no menu bar clicking) for a visual check.
# Usage: Tests/snapshots.sh [outdir]   (default: /tmp/vaani-snapshots)
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-/tmp/vaani-snapshots}"
mkdir -p "$OUT"
swift build -c release --arch arm64 2>&1 | tail -1
VAANI_SNAPSHOT_DIR="$OUT" .build/arm64-apple-macosx/release/SaarasTranslator
ls "$OUT"
