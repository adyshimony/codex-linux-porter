#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${WORK_DIR:-"$SCRIPT_DIR/work"}"
APP_DIR="${APP_DIR:-"$WORK_DIR/app"}"
APP_ASAR_PATH="${APP_ASAR_PATH:-"$WORK_DIR/app.asar"}"
ELECTRON_BIN="${ELECTRON_BIN:-"${ELECTRON:-electron}"}"
CODEX_CLI_PATH="${CODEX_CLI_PATH:-"$(command -v codex || true)"}"
ELECTRON_CACHE_DIR="$WORK_DIR/.npm-cache"
ELECTRON_XDG_CACHE_DIR="${ELECTRON_XDG_CACHE_DIR:-"$WORK_DIR/.cache/electron"}"
mkdir -p "$ELECTRON_CACHE_DIR" "$ELECTRON_XDG_CACHE_DIR"

resolve_electron_version() {
  if command -v "$ELECTRON_BIN" >/dev/null 2>&1; then
    "$ELECTRON_BIN" --version 2>/dev/null | sed 's/^v//'
    return
  fi

  if [[ -f "$APP_DIR/package.json" ]]; then
    APP_DIR_ENV="$APP_DIR" node - <<'NODE'
const fs = require("fs")
const pkg = JSON.parse(fs.readFileSync(process.env.APP_DIR_ENV + "/package.json", "utf8"))
process.stdout.write((pkg.devDependencies?.electron || pkg.dependencies?.electron || "40.0.0").trim())
NODE
    return
  fi

  echo "40.0.0"
}

resolve_electron_command() {
  if command -v "$ELECTRON_BIN" >/dev/null 2>&1; then
    ELECTRON_CMD=(env ELECTRON_DISABLE_SANDBOX="${ELECTRON_DISABLE_SANDBOX:-1}" "$ELECTRON_BIN")
    return
  fi

  if command -v npx >/dev/null 2>&1; then
    local ver
    ver="$(resolve_electron_version)"
    ELECTRON_CMD=(env \
      XDG_CACHE_HOME="$ELECTRON_XDG_CACHE_DIR" \
      ELECTRON_DISABLE_SANDBOX="${ELECTRON_DISABLE_SANDBOX:-1}" \
      npx --cache "$ELECTRON_CACHE_DIR" --yes "electron@$ver")
    return
  fi

  ELECTRON_CMD=()
}

APP_SOURCE=""
if [[ -d "$APP_DIR" ]]; then
  APP_SOURCE="$APP_DIR"
elif [[ -f "$APP_ASAR_PATH" ]]; then
  APP_SOURCE="$APP_ASAR_PATH"
else
  echo "No unpacked app dir or app.asar. Run setup scripts first." >&2
  exit 1
fi

if [[ -n "$CODEX_CLI_PATH" ]]; then
  export CODEX_CLI_PATH
  export PATH="$(dirname "$CODEX_CLI_PATH"):$PATH"
else
  echo "Warning: CODEX_CLI_PATH not set. Ensure Codex CLI is discoverable in PATH."
fi

resolve_electron_command
if ((${#ELECTRON_CMD[@]} == 0)); then
  echo "Electron not found: set ELECTRON_BIN or install node's npx." >&2
  exit 1
fi

export ELECTRON_FORCE_IS_PACKAGED=1
export NODE_ENV=production

if [[ "${CODEX_DEBUG:-0}" == "1" ]]; then
  echo "Launching Electron app from: $APP_SOURCE"
  echo "Using CLI path: ${CODEX_CLI_PATH:-not set}"
  echo "Command: ${ELECTRON_CMD[*]} \"$APP_SOURCE\""
fi

exec "${ELECTRON_CMD[@]}" "$APP_SOURCE" "$@"
