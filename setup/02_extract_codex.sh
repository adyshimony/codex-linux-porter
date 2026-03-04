#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="${WORK_DIR:-"$ROOT_DIR/work"}"
DmgDir="$WORK_DIR/dmg"
ExtractDir="$WORK_DIR/extracted_dmg"
PayloadDir="$WORK_DIR/payload"
PayloadPath="$PayloadDir/app.asar"
PayloadUnpackedPath="$WORK_DIR/app.asar.unpacked"

mkdir -p "$PayloadDir"

DMG_FILE="$DmgDir/Codex.dmg"
if [[ ! -f "$DMG_FILE" ]]; then
  echo "No DMG found at $DMG_FILE. Run 01_download_or_link_dmg.sh first." >&2
  exit 1
fi

if ! command -v 7z >/dev/null 2>&1; then
  echo "7z not found. Install p7zip-full." >&2
  exit 1
fi

rm -rf "$ExtractDir"
mkdir -p "$ExtractDir"

set +e
7z x "$DMG_FILE" -o"$ExtractDir" -y >/tmp/codex-dmg-extract.log 2>&1
EXTRACT_RC=$?
set -e

if (( EXTRACT_RC != 0 && EXTRACT_RC != 2 )); then
  echo "7z extraction failed with code $EXTRACT_RC" >&2
  echo "See /tmp/codex-dmg-extract.log" >&2
  exit 1
fi

if (( EXTRACT_RC == 2 )); then
  echo "Warning: 7z reported warnings (code 2). Continuing since these are usually non-fatal." >&2
  echo "See /tmp/codex-dmg-extract.log" >&2
fi

ASAR_SOURCE="$(find "$ExtractDir" -path "*/Contents/Resources/app.asar" | head -n 1 || true)"
if [[ -z "$ASAR_SOURCE" ]]; then
  echo "Could not locate app.asar in extracted DMG." >&2
  echo "Extraction log: /tmp/codex-dmg-extract.log" >&2
  exit 1
fi

cp "$ASAR_SOURCE" "$PayloadPath"
rm -f "$WORK_DIR/app.asar"
cp "$PayloadPath" "$WORK_DIR/app.asar"

ASAR_UNPACKED_SOURCE="${ASAR_SOURCE}.unpacked"
if [[ -d "$ASAR_UNPACKED_SOURCE" ]]; then
  rm -rf "$PayloadUnpackedPath"
  cp -r "$ASAR_UNPACKED_SOURCE" "$PayloadUnpackedPath"
  echo "Copied sibling unpacked payload: $ASAR_UNPACKED_SOURCE"
fi

cat > "$WORK_DIR/payload.info" <<PAYLOAD_INFO
app_asar=$PayloadPath
app_unpacked=$PayloadUnpackedPath
app_bundle=$ASAR_SOURCE
app_bundle_unpacked=$ASAR_UNPACKED_SOURCE
extracted_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
source=$DMG_FILE
PAYLOAD_INFO

echo "Found app.asar: $ASAR_SOURCE"
echo "Copied to payload: $PayloadPath"
if [[ -d "$PayloadUnpackedPath" ]]; then
  echo "Copied asar unpacked to: $PayloadUnpackedPath"
fi
echo "Wrote payload info to $WORK_DIR/payload.info"
