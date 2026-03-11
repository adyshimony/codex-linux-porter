#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:-$(getent passwd "$(id -un)" | cut -d: -f6)}"
WORK_DIR="${WORK_DIR:-"$SCRIPT_DIR/work"}"
APP_DIR="${APP_DIR:-"$WORK_DIR/app"}"
APP_ASAR_PATH="${APP_ASAR_PATH:-"$WORK_DIR/app.asar"}"
ELECTRON_BIN="${ELECTRON_BIN:-"${ELECTRON:-electron}"}"
ELECTRON_CACHE_DIR="${ELECTRON_CACHE_DIR:-"$WORK_DIR/.electron-npx-cache"}"
ELECTRON_XDG_CACHE_DIR="${ELECTRON_XDG_CACHE_DIR:-"$WORK_DIR/.cache/electron"}"
mkdir -p "$ELECTRON_CACHE_DIR" "$ELECTRON_XDG_CACHE_DIR"

prepend_path() {
  local dir_path="$1"

  [[ -d "$dir_path" ]] || return 0
  case ":$PATH:" in
    *":$dir_path:"*) ;;
    *) PATH="$dir_path:$PATH" ;;
  esac
}

augment_user_tool_paths() {
  prepend_path "$HOME_DIR/.local/bin"

  if [[ -n "${NVM_BIN:-}" ]]; then
    prepend_path "$NVM_BIN"
    return
  fi

  local nvm_bin_dir
  nvm_bin_dir="$(find "$HOME_DIR/.nvm/versions/node" -mindepth 2 -maxdepth 2 -type d -name bin 2>/dev/null | sort -V | tail -n 1 || true)"
  if [[ -n "$nvm_bin_dir" ]]; then
    prepend_path "$nvm_bin_dir"
  fi
}

augment_user_tool_paths
export PATH

resolve_codex_cli_path() {
  local candidate=""

  if [[ -n "${CODEX_CLI_PATH:-}" ]]; then
    candidate="${CODEX_CLI_PATH}"
  elif candidate="$(command -v codex 2>/dev/null || true)"; [[ -n "$candidate" ]]; then
    :
  elif [[ -x "$HOME_DIR/.local/bin/codex" ]]; then
    candidate="$HOME_DIR/.local/bin/codex"
  else
    local nvm_codex
    nvm_codex="$(find "$HOME_DIR/.nvm/versions/node" -path '*/bin/codex' 2>/dev/null | sort -V | tail -n 1 || true)"
    if [[ -n "$nvm_codex" ]]; then
      candidate="$nvm_codex"
    fi
  fi

  if [[ -n "$candidate" ]]; then
    printf '%s\n' "$candidate"
  fi
}

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

resolve_app_metadata_field() {
  local field_name="$1"

  if [[ ! -f "$APP_DIR/package.json" ]]; then
    echo ""
    return
  fi

  APP_DIR_ENV="$APP_DIR" FIELD_NAME="$field_name" node - <<'NODE'
const fs = require("fs")
const pkg = JSON.parse(fs.readFileSync(process.env.APP_DIR_ENV + "/package.json", "utf8"))
const value = pkg[process.env.FIELD_NAME]
if (typeof value === "string" && value.trim()) {
  process.stdout.write(value.trim())
}
NODE
}

resolve_electron_command() {
  local disable_sandbox="${ELECTRON_DISABLE_SANDBOX:-1}"
  local electron_args=()

  if [[ "$disable_sandbox" == "1" ]]; then
    electron_args+=(--no-sandbox)
  fi

  if command -v "$ELECTRON_BIN" >/dev/null 2>&1; then
    ELECTRON_CMD=(env ELECTRON_DISABLE_SANDBOX="$disable_sandbox" "$ELECTRON_BIN" "${electron_args[@]}")
    return
  fi

  if command -v npx >/dev/null 2>&1; then
    local ver
    ver="$(resolve_electron_version)"
    ELECTRON_CMD=(env \
      XDG_CACHE_HOME="$ELECTRON_XDG_CACHE_DIR" \
      ELECTRON_DISABLE_SANDBOX="$disable_sandbox" \
      npx --cache "$ELECTRON_CACHE_DIR" --yes "electron@$ver" "${electron_args[@]}")
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

CODEX_CLI_PATH="$(resolve_codex_cli_path)"

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

if [[ -z "${BUILD_FLAVOR:-}" ]]; then
  BUILD_FLAVOR="$(resolve_app_metadata_field "codexBuildFlavor")"
  if [[ -n "$BUILD_FLAVOR" ]]; then
    export BUILD_FLAVOR
  fi
fi

if [[ -z "${CODEX_BUILD_NUMBER:-}" ]]; then
  CODEX_BUILD_NUMBER="$(resolve_app_metadata_field "codexBuildNumber")"
  if [[ -n "$CODEX_BUILD_NUMBER" ]]; then
    export CODEX_BUILD_NUMBER
  fi
fi

export ELECTRON_FORCE_IS_PACKAGED=1
export NODE_ENV=production

if [[ -d "$APP_SOURCE" ]]; then
  cd "$APP_SOURCE"
else
  cd "$(dirname "$APP_SOURCE")"
fi

if [[ "${CODEX_DEBUG:-0}" == "1" ]]; then
  echo "Launching Electron app from: $APP_SOURCE"
  echo "Using CLI path: ${CODEX_CLI_PATH:-not set}"
  echo "Command: ${ELECTRON_CMD[*]} \"$APP_SOURCE\""
fi

exec "${ELECTRON_CMD[@]}" "$APP_SOURCE" "$@"
