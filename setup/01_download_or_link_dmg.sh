#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="${WORK_DIR:-"$ROOT_DIR/work"}"
DmgDir="$WORK_DIR/dmg"
mkdir -p "$DmgDir"

INPUT_PATH="${1:-""}"
DMG_PATH="${CODEX_DMG_PATH:-""}"
DMG_URL="${CODEX_DMG_URL:-""}"

if [[ -n "$INPUT_PATH" ]]; then
  DMG_PATH="$INPUT_PATH"
elif [[ -z "$DMG_PATH" && -f "$DmgDir/Codex.dmg" ]]; then
  DMG_PATH="$DmgDir/Codex.dmg"
elif [[ -z "$DMG_PATH" && -f "$WORK_DIR/app.asar" ]]; then
  echo "app.asar already exists; skipping DMG stage."
  exit 0
fi

if [[ -z "$DMG_PATH" && -z "$DMG_URL" ]]; then
  echo "No DMG source set."
  echo "Pass a local path as arg, or set CODEX_DMG_PATH / CODEX_DMG_URL."
  exit 1
fi

if [[ -n "$DMG_PATH" ]]; then
  if [[ ! -f "$DMG_PATH" ]]; then
    echo "DMG not found: $DMG_PATH" >&2
    exit 1
  fi
  cp "$DMG_PATH" "$DmgDir/Codex.dmg"
  echo "Copied DMG to $DmgDir/Codex.dmg"
elif [[ -n "$DMG_URL" ]]; then
  echo "Downloading DMG from $DMG_URL"
  if command -v curl >/dev/null 2>&1; then
    curl -L "$DMG_URL" -o "$DmgDir/Codex.dmg"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$DmgDir/Codex.dmg" "$DMG_URL"
  else
    echo "Neither curl nor wget available." >&2
    exit 1
  fi
fi

echo "Dmg ready at $DmgDir/Codex.dmg"
