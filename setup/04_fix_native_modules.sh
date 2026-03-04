#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="${WORK_DIR:-"$ROOT_DIR/work"}"
APP_DIR="${APP_DIR:-"$WORK_DIR/app"}"
ELECTRON_BIN="${ELECTRON_BIN:-"${ELECTRON:-electron}"}"
ELECTRON_VERSION="${ELECTRON_VERSION:-""}"
NPM_CACHE_DIR="$WORK_DIR/.npm-cache"
ELECTRON_XDG_CACHE_DIR="${ELECTRON_XDG_CACHE_DIR:-"$WORK_DIR/.cache/electron"}"
REBUILD_TMP_DIR="$WORK_DIR/native-rebuild"
ELECTRON_DISABLE_SANDBOX="${ELECTRON_DISABLE_SANDBOX:-1}"
declare -A NATIVE_MODULE_ARTIFACTS
NATIVE_MODULE_ARTIFACTS=(
  ["better-sqlite3"]="build/Release/better_sqlite3.node"
  ["node-pty"]="build/Release/pty.node"
)
mkdir -p "$NPM_CACHE_DIR" "$REBUILD_TMP_DIR" "$ELECTRON_XDG_CACHE_DIR"

warn() {
  printf "[WARN] %s\n" "$1" >&2
}

fail() {
  printf "[FAIL] %s\n" "$1" >&2
}

if [[ ! -d "$APP_DIR" ]]; then
  fail "Missing app directory: $APP_DIR. Run 03_unpack_asar.sh first."
  exit 1
fi

resolve_electron_version() {
  if [[ -n "${1:-}" ]]; then
    echo "$1"
    return
  fi

  if command -v "$ELECTRON_BIN" >/dev/null 2>&1; then
    "$ELECTRON_BIN" --version 2>/dev/null | sed 's/^v//'
    return
  fi

  if [[ -f "$APP_DIR/package.json" ]]; then
    APP_DIR_ENV="$APP_DIR" node - <<'NODE'
const fs = require("fs")
const pkg = JSON.parse(fs.readFileSync(process.env.APP_DIR_ENV + "/package.json", "utf8"))
process.stdout.write((pkg.devDependencies?.electron || pkg.dependencies?.electron || "").trim())
NODE
    return
  fi

  echo ""
}

ensure_build_env() {
  local cflags="${CXXFLAGS:-}"
  local cxxflags="${npm_config_cxxflags:-}"
  local cppflags="${npm_config_cppflags:-}"
  local cflags_cfg="${npm_config_cflags:-}"

  if [[ -z "$cflags" ]]; then
    export CXXFLAGS="-std=gnu++20"
  elif [[ "$cflags" != *"c++20"* && "$cflags" != *"gnu++20"* ]]; then
    export CXXFLAGS="${cflags} -std=gnu++20"
  fi
  if [[ -z "$cxxflags" ]]; then
    export npm_config_cxxflags="-std=gnu++20"
  elif [[ "$cxxflags" != *"c++20"* && "$cxxflags" != *"gnu++20"* ]]; then
    export npm_config_cxxflags="${cxxflags} -std=gnu++20"
  fi
  if [[ -z "$cppflags" ]]; then
    export npm_config_cppflags="-std=gnu++20"
  elif [[ "$cppflags" != *"c++20"* && "$cppflags" != *"gnu++20"* ]]; then
    export npm_config_cppflags="${cppflags} -std=gnu++20"
  fi
  if [[ -z "$cflags_cfg" ]]; then
    export npm_config_cflags="-std=gnu++20"
  elif [[ "$cflags_cfg" != *"c++20"* && "$cflags_cfg" != *"gnu++20"* ]]; then
    export npm_config_cflags="${cflags_cfg} -std=gnu++20"
  fi

  export XDG_CACHE_HOME="$ELECTRON_XDG_CACHE_DIR"
  export npm_config_cache="$NPM_CACHE_DIR"
}

ensure_artifact_present() {
  local module_name="$1"
  local expected="${NATIVE_MODULE_ARTIFACTS[$module_name]:-}"
  local artifact_path

  if [[ -z "$expected" ]]; then
    return 0
  fi

  artifact_path="$APP_DIR/node_modules/$module_name/$expected"
  if [[ ! -f "$artifact_path" ]]; then
    warn "Expected Linux addon missing: $artifact_path"
    return 1
  fi

  if ! file "$artifact_path" | grep -q "ELF"; then
    warn "Native addon is not ELF: $artifact_path"
    return 1
  fi

  return 0
}

replace_with_local_install() {
  local module_name="$1"
  ensure_build_env
  if ! npm rebuild "$module_name" --build-from-source; then
    warn "Local fallback rebuild failed for ${module_name}."
    return 1
  fi
  return 0
}

ELECTRON_VERSION="$(resolve_electron_version "$ELECTRON_VERSION")"
if [[ -z "$ELECTRON_VERSION" ]]; then
  warn "Could not detect Electron version; defaulting to 40.0.0 for rebuild steps."
  ELECTRON_VERSION="40.0.0"
fi

if [[ -z "$ELECTRON_VERSION" ]]; then
  fail "Could not resolve Electron version."
  exit 1
fi

echo "Using Electron version: $ELECTRON_VERSION"

ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  x86_64) NPM_ARCH=x64 ;;
  aarch64) NPM_ARCH=arm64 ;;
  arm64) NPM_ARCH=arm64 ;;
  *) NPM_ARCH="$ARCH_RAW" ;;
esac

TARGET_MODULES=(better-sqlite3 node-pty)
MODS_PRESENT=()
for module in "${TARGET_MODULES[@]}"; do
  if [[ -d "$APP_DIR/node_modules/$module" ]]; then
    MODS_PRESENT+=("$module")
  fi
done

if ((${#MODS_PRESENT[@]} == 0)); then
  echo "No target native modules found. Skipping rebuild."
  exit 0
fi

echo "Rebuilding native modules for ABI compatibility: ${MODS_PRESENT[*]}"

cd "$APP_DIR"
ensure_build_env
export npm_config_arch="$NPM_ARCH"
export npm_config_target="$ELECTRON_VERSION"
export npm_config_runtime="electron"
export npm_config_disturl="https://electronjs.org/headers"

for module in "${MODS_PRESENT[@]}"; do
  if ! replace_with_local_install "$module"; then
    fail "npm rebuild failed for $module."
    exit 1
  fi
  if ! ensure_artifact_present "$module"; then
    fail "Expected artifact missing after rebuild for $module."
    exit 1
  fi
done

for module in "${MODS_PRESENT[@]}"; do
  if [[ -d "$APP_DIR/node_modules/$module/prebuilds" ]]; then
    rm -rf "$APP_DIR/node_modules/$module/prebuilds"
  fi
done

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

if [[ $bad -ne 0 ]]; then
  echo "Some native addons are not Linux ELF binaries."
  exit 1
fi

echo "Native module check complete."
