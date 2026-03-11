#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="${WORK_DIR:-"$ROOT_DIR/work"}"
APP_DIR="${APP_DIR:-"$WORK_DIR/app"}"
APP_ASAR_PATH="${APP_ASAR_PATH:-"$WORK_DIR/app.asar"}"
CODEX_CLI_PATH="${CODEX_CLI_PATH:-"$(command -v codex || true)"}"
ELECTRON_BIN="${ELECTRON_BIN:-"${ELECTRON:-electron}"}"
ELECTRON_CACHE_DIR="${ELECTRON_CACHE_DIR:-"$WORK_DIR/.electron-npx-cache"}"
ELECTRON_XDG_CACHE_DIR="${ELECTRON_XDG_CACHE_DIR:-"$WORK_DIR/.cache/electron"}"
declare -A EXPECTED_NATIVE_ARTIFACTS=(
  ["better-sqlite3"]="build/Release/better_sqlite3.node"
  ["node-pty"]="build/Release/pty.node"
)
mkdir -p "$ELECTRON_CACHE_DIR" "$ELECTRON_XDG_CACHE_DIR"

STATUS=0

ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[WARN] %s\n" "$1"; }
fail() { printf "[FAIL] %s\n" "$1" >&2; STATUS=1; }

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

ensure_expected_artifacts() {
  local missing=0

  for module in "${!EXPECTED_NATIVE_ARTIFACTS[@]}"; do
    local artifact_path="$APP_DIR/node_modules/$module/${EXPECTED_NATIVE_ARTIFACTS[$module]}"
    if [[ ! -f "$artifact_path" ]]; then
      warn "Expected Linux addon missing: $artifact_path"
      missing=1
    elif ! file "$artifact_path" | grep -q "ELF"; then
      warn "Expected Linux addon is not ELF: $artifact_path"
      missing=1
    fi
  done

  return "$missing"
}

if command -v "$ELECTRON_BIN" >/dev/null 2>&1; then
  ok "Electron found: $($ELECTRON_BIN --version)"
else
  resolve_electron_command
  if ((${#ELECTRON_CMD[@]} == 0)); then
    fail "Electron not found: set ELECTRON_BIN"
  else
    ELECTRON_BIN_INFO="$("${ELECTRON_CMD[@]}" --version 2>/dev/null || true)"
    if [[ -n "$ELECTRON_BIN_INFO" ]]; then
      ok "Electron via npx available: $ELECTRON_BIN_INFO"
    else
      fail "Electron command unavailable even via npx fallback."
    fi
  fi
fi

if [[ -x "$CODEX_CLI_PATH" ]]; then
  ok "Codex CLI found: $CODEX_CLI_PATH"
else
  fail "Codex CLI missing from PATH. Set CODEX_CLI_PATH."
fi

if [[ -d "$APP_DIR" || -f "$APP_ASAR_PATH" ]]; then
  ok "App payload exists."
else
  fail "No app payload. Run setup scripts first."
fi

if [[ -f "$WORK_DIR/app.asar" ]]; then
  ok "app.asar available at $WORK_DIR/app.asar"
else
  warn "app.asar not found in expected path"
fi

if [[ -f "$WORK_DIR/payload.info" ]]; then
  ok "payload.info present."
  cat "$WORK_DIR/payload.info"
else
  warn "payload.info missing"
fi

if [[ -x "$CODEX_CLI_PATH" ]]; then
  if "$CODEX_CLI_PATH" --help >/tmp/codex-help.out 2>&1; then
    if grep -qi "login" /tmp/codex-help.out; then
      ok "Codex CLI supports login/help flow"
    else
      warn "Could not detect login marker in Codex CLI help output"
    fi
  else
    warn "Could not run '$CODEX_CLI_PATH --help'"
  fi
fi

if command -v node >/dev/null 2>&1; then
  ok "Node: $(node -v)"
else
  fail "Node missing"
fi

if command -v npm >/dev/null 2>&1; then
  ok "npm: $(npm -v)"
else
  warn "npm missing. Required for rebuild steps."
fi

if [[ -d "$APP_DIR/node_modules" ]]; then
  bad=0
  while IFS= read -r -d '' mod; do
    if [[ "$mod" == *"/prebuilds/"* || "$mod" == */native/* ]]; then
      continue
    fi
    if ! file "$mod" | grep -q "ELF"; then
      warn "Non-ELF native addon detected: $mod"
      bad=1
    fi
  done < <(find "$APP_DIR/node_modules" -name "*.node" -print0)
  if [[ $bad -eq 0 ]]; then
    ok "Native addon files appear Linux-compatible"
  else
    fail "Some native addons are not Linux-compatible"
  fi
  if ! ensure_expected_artifacts; then
    fail "Missing or invalid required native addon artifact."
  fi
else
  warn "No node_modules found in app directory"
fi

echo "Verification pass complete."
if [[ $STATUS -ne 0 ]]; then
  echo "Verification found issues." >&2
  exit $STATUS
fi
