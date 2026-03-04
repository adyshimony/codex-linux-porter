#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

"$SCRIPT_DIR/00_install_prereqs.sh"
"$SCRIPT_DIR/01_download_or_link_dmg.sh" "${1:-}"
"$SCRIPT_DIR/02_extract_codex.sh"
"$SCRIPT_DIR/03_unpack_asar.sh"
"$SCRIPT_DIR/06_patch_sidebar_fallback.sh"
"$SCRIPT_DIR/04_fix_native_modules.sh"
"$SCRIPT_DIR/05_verify_stack.sh"

echo "Bootstrap complete. Run: $ROOT_DIR/run-codex-linux.sh"
