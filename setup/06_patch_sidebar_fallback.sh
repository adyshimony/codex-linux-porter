#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="${WORK_DIR:-"$ROOT_DIR/work"}"
ASSETS_DIR="$WORK_DIR/app/webview/assets"
INDEX_HTML="$WORK_DIR/app/webview/index.html"
MAIN_PROCESS_BUNDLE="$WORK_DIR/app/.vite/build/main.js"
RENDER_FIX_JS="$ASSETS_DIR/codex-linux-render-fix.js"
CSS_MARKER="Codex Linux wrapper sidebar fallback v2"
JS_MARKER="window.__codexLinuxRenderFix"
WINDOW_PATCH_MARKER='a.once(`ready-to-show`,()=>{a.isDestroyed()||(a.show(),a.focus())})'
RENDER_FIX_ENABLED="${ENABLE_SIDEBAR_RENDER_FIX:-1}"

CSS_PATTERN="$WORK_DIR/app/webview/assets/index-*.css"
CSS_FILE="$(ls $CSS_PATTERN 2>/dev/null | sort | head -n 1 || true)"

if [[ -z "$CSS_FILE" ]]; then
  echo "No webview stylesheet found in $WORK_DIR/app/webview/assets (pattern $CSS_PATTERN)." >&2
  exit 1
fi

if [[ ! -f "$INDEX_HTML" ]]; then
  echo "No webview index.html found at $INDEX_HTML." >&2
  exit 1
fi

if [[ ! -f "$MAIN_PROCESS_BUNDLE" ]]; then
  echo "No main process bundle found at $MAIN_PROCESS_BUNDLE." >&2
  exit 1
fi

if grep -q "$CSS_MARKER" "$CSS_FILE"; then
  echo "Sidebar fallback already applied: $CSS_FILE"
else
cat <<'CSS' >> "$CSS_FILE"

/* Codex Linux wrapper sidebar fallback v2 to avoid transparent sidebar from unresolved VS Code tokens */
[data-codex-window-type=electron] {
  --color-token-side-bar-background: var(--vscode-sideBar-background, #111827);
}
[data-codex-window-type=electron] #root,
[data-codex-window-type=electron] body,
[data-codex-window-type=electron] .app,
[data-codex-window-type=electron] .app-shell,
[data-codex-window-type=electron] .main-surface,
[data-codex-window-type=electron] .docs-story,
[data-codex-window-type=electron] .left-panel,
[data-codex-window-type=electron] .left-sidebar,
[data-codex-window-type=electron] .sidebar,
[data-codex-window-type=electron] .navigation-panel,
[data-codex-window-type=electron] .split-view {
  background-color: var(--color-token-side-bar-background, #111827) !important;
  background-image: none !important;
}
[data-codex-window-type=electron] .main-surface {
  box-shadow: none !important;
  backdrop-filter: none !important;
}
[data-codex-window-type=electron] :where(.main-surface) {
  background-color: var(--color-token-side-bar-background, #111827) !important;
}
CSS

  echo "Applied sidebar fallback patch to $CSS_FILE"
fi

if [[ "${RENDER_FIX_ENABLED}" != "0" ]]; then
if grep -q "$JS_MARKER" "$RENDER_FIX_JS" 2>/dev/null; then
  echo "Render fix script already patched: $RENDER_FIX_JS"
else
cat <<'JS' > "$RENDER_FIX_JS"
/* Codex Linux wrapper render fix */
(function () {
  if (window.__codexLinuxRenderFix) return

  window.__codexLinuxRenderFix = true

  const FALLBACK_BG = "#111827"
  const TARGET_SELECTORS = [
    ".app",
    ".app-shell",
    ".main-surface",
    ".docs-story",
    ".left-panel",
    ".left-sidebar",
    ".sidebar",
    ".navigation-panel",
    ".split-view",
    ".split-pane",
    "[role='complementary']",
    "#root",
  ]

  let scheduled = false

  function getThemeFallback() {
    const root = document.documentElement
    if (!root) return FALLBACK_BG

    const raw = getComputedStyle(root).getPropertyValue("--vscode-sideBar-background").trim()
    return raw || FALLBACK_BG
  }

  function paint() {
    const shell = document.querySelector('[data-codex-window-type="electron"]')
    const root = shell || document.documentElement || document.body
    if (!root) return

    const background = getThemeFallback()
    const seen = new Set()
    const targets = []

    for (const target of [document.documentElement, document.body, root, document.getElementById("root")]) {
      if (target && target.style) {
        targets.push(target)
      }
    }

    for (const selector of TARGET_SELECTORS) {
      for (const node of document.querySelectorAll(selector)) {
        if (node && node.style) {
          targets.push(node)
        }
      }
    }

    for (const target of targets) {
      if (!target || seen.has(target)) continue
      seen.add(target)
      target.style.setProperty("--color-token-side-bar-background", background, "important")
      target.style.backgroundColor = background
      target.style.backgroundImage = "none"
    }

    if (shell) {
      shell.style.backgroundColor = background
    }
  }

  function paintFrame() {
    paint()
    scheduled = false
  }

  function schedule() {
    if (scheduled) return
    scheduled = true
    requestAnimationFrame(() => {
      requestAnimationFrame(paintFrame)
    })
  }

  function bootstrap() {
    paint()
    setTimeout(paint, 80)
    setTimeout(paint, 250)
    setTimeout(paint, 800)
    setTimeout(paint, 1600)
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", schedule, { once: true })
  } else {
    schedule()
  }

  bootstrap()
  window.addEventListener("focus", schedule)
  window.addEventListener("resize", schedule)
})();
JS

  echo "Generated render fix helper: $RENDER_FIX_JS"
fi
else
  if [[ -f "$RENDER_FIX_JS" ]]; then
    :
  fi
fi

if [[ "${RENDER_FIX_ENABLED}" != "0" ]]; then
if ! grep -q "codex-linux-render-fix.js" "$INDEX_HTML"; then
  perl -0pi -e 's#</head>#  <script src="./assets/codex-linux-render-fix.js"></script>\n</head>#' "$INDEX_HTML"
  echo "Injected render fix script into $INDEX_HTML"
else
  echo "Render fix script already injected: $INDEX_HTML"
fi
else
  perl -0pi -e 's#\n\s*<script src="./assets/codex-linux-render-fix.js"></script>##g' "$INDEX_HTML"
  echo "Render-fix disabled; script removed if present: $INDEX_HTML"
fi

if ! grep -q "$CSS_MARKER" "$CSS_FILE"; then
  echo "Warning: sidebar fallback marker not found after patch, check $CSS_FILE"
  exit 1
fi

if [[ "${RENDER_FIX_ENABLED}" != "0" ]] && ! grep -q "codex-linux-render-fix" "$INDEX_HTML"; then
  echo "Warning: render-fix script reference not found after patch: $INDEX_HTML"
  exit 1
fi

if [[ "${RENDER_FIX_ENABLED}" != "0" ]] && ! grep -q "$JS_MARKER" "$RENDER_FIX_JS"; then
  echo "Warning: render-fix helper file content check failed: $RENDER_FIX_JS"
  exit 1
fi

if grep -q "$WINDOW_PATCH_MARKER" "$MAIN_PROCESS_BUNDLE"; then
  echo "Primary window startup patch already applied: $MAIN_PROCESS_BUNDLE"
else
  set +e
  MAIN_PROCESS_BUNDLE="$MAIN_PROCESS_BUNDLE" node - <<'NODE'
const fs = require("fs")

const bundlePath = process.env.MAIN_PROCESS_BUNDLE
const source = fs.readFileSync(bundlePath, "utf8")
const replacement = "show:i});return i||(a.once(`ready-to-show`,()=>{a.isDestroyed()||(a.show(),a.focus())}),sie(a,n.id)),a"

const variants = [
  "show:!0});return i||sie(a,n.id),a",
  "show:i});return i||sie(a,n.id),a",
]

let next = source
let changed = false
for (const variant of variants) {
  if (next.includes(variant)) {
    next = next.replace(variant, replacement)
    changed = true
    break
  }
}

if (!changed) {
  process.exit(2)
}

fs.writeFileSync(bundlePath, next)
NODE
  PATCH_RC=$?
  set -e

  if [[ $PATCH_RC -ne 0 ]]; then
    echo "Failed to apply primary window startup patch to $MAIN_PROCESS_BUNDLE." >&2
    exit 1
  fi

  echo "Applied primary window startup patch to $MAIN_PROCESS_BUNDLE"
fi

if ! grep -q "$WINDOW_PATCH_MARKER" "$MAIN_PROCESS_BUNDLE"; then
  echo "Warning: primary window startup marker not found after patch: $MAIN_PROCESS_BUNDLE" >&2
  exit 1
fi

echo "Render fix patch complete"
