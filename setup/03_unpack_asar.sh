#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="${WORK_DIR:-"$ROOT_DIR/work"}"
APP_ASAR_PATH="${APP_ASAR_PATH:-"$WORK_DIR/app.asar"}"
APP_DIR="${APP_DIR:-"$WORK_DIR/app"}"
NPM_CACHE_DIR="$WORK_DIR/.npm-cache"
mkdir -p "$NPM_CACHE_DIR"

if [[ ! -f "$APP_ASAR_PATH" ]]; then
  echo "Missing app.asar at $APP_ASAR_PATH. Run 02_extract_codex.sh first." >&2
  exit 1
fi

if command -v asar >/dev/null 2>&1; then
  ASAR_CMD=(asar)
elif command -v npx >/dev/null 2>&1; then
  ASAR_CMD=(npx --cache "$NPM_CACHE_DIR" --yes @electron/asar)
else
  echo "asar tool unavailable. Install npm+ npx or system asar package." >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"

"${ASAR_CMD[@]}" extract "$APP_ASAR_PATH" "$APP_DIR"

echo "Unpacked app.asar to: $APP_DIR"
