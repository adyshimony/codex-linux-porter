# Codex Linux Wrapper — Fix Notes

## What we fixed (this setup)

- Added a transparent-left-panel workaround to the wrapper flow in:
  - `setup/06_patch_sidebar_fallback.sh`
- Added a resilient CSS fallback in this script to force sidebar/background colors when tokenized CSS fails.
- Added a small runtime JS patch (`work/app/webview/assets/codex-linux-render-fix.js`) to repaint broken backgrounds after render.
- Made bootstrap apply the sidebar/render fix automatically as part of:
  - `setup/bootstrap.sh`
- Made repo docs and launcher portable for other clones:
  - Removed hardcoded absolute paths from readme/launcher-instruction files.
  - Desktop launcher now resolves relative to its own file location.
- Added `.gitignore` for generated artifacts (`work/`, caches, logs, `node_modules`, etc.) to keep a clean GitHub repo.

## Current state

- Your Linux wrapper repo is commit-ready and clean.
- No push was performed.
- You can keep your old working tree (`codex-linux-wrapper/work`) separate and keep running it with:
  - `WORK_DIR=/path/to/your/existing/work ./run-codex-linux.sh`
