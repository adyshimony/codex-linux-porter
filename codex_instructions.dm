# Codex Linux Wrapper — Persistent Instructions

Goal
- Recreate and run Codex Electron app on Ubuntu/Linux using Codex macOS `.dmg` payload.
- Keep non-API (GPT login) flow functional.

Paths
- Repo root: `<REPO_ROOT>`
- Working state: `<REPO_ROOT>/work`
- Launcher: `<REPO_ROOT>/run-codex-linux.sh`
- Bootstrap: `<REPO_ROOT>/setup/bootstrap.sh`

One-Run Setup
1) Prereqs
- Ubuntu/Debian Linux + apt
- node/npm installed and `codex` CLI available in PATH
- Optional: `electron` binary (otherwise script uses `npx` fallback)

2) Bootstrap from DMG
```bash
cd /path/to/you-cloned-repo
./setup/bootstrap.sh /path/to/Codex.dmg
```

3) CLI auth (GPT login)
```bash
codex login
```

4) Launch
```bash
./run-codex-linux.sh
```

What each script does
- `setup/01_download_or_link_dmg.sh`
  - Reads `CODEX_DMG_PATH`, arg 1, or existing `work/dmg/Codex.dmg`.
  - Copies DMG into `work/dmg/Codex.dmg`.
- `setup/02_extract_codex.sh`
  - `7z x` into `work/extracted_dmg`.
  - Locates `Codex.app/Contents/Resources/app.asar` and copies to `work/app.asar`.
- `setup/03_unpack_asar.sh`
  - Unpacks `app.asar` into `work/app`.
- `setup/04_fix_native_modules.sh`
  - Detects target ABI modules.
  - `npm rebuild` + target flags (electron runtime + Linux + C++20 flags).
- `setup/05_verify_stack.sh`
  - Verifies CLI, Electron, unpacked payload, and native addon artifacts.
- `run-codex-linux.sh`
  - Resolves electron command, exports `CODEX_CLI_PATH`, and runs:
    - `electron work/app` via local `electron` or `npx electron@<version>`.

Critical behavior notes
- The app bundle is `app.asar` from macOS payload.
- The run-time command is Linux Electron with extracted app directory.
- The app-server side path inside the app launches backend via:
  - `bash -lc "codex app-server"`
  - So authentication/session context comes from CLI config used by `codex`.

Update behavior
- Built-in update manager is Sparkle-based and only initialized for macOS packaged builds.
- On Linux wrapper, `Check for Updates` is effectively unavailable.
- Update strategy is manual:
  - download new DMG
  - rerun bootstrap
  - optionally `rm -rf work` first.

Reset / recovery
- If things break:
```bash
cd /path/to/you-cloned-repo
rm -rf work
./setup/bootstrap.sh /path/to/Codex.dmg
./setup/05_verify_stack.sh
./run-codex-linux.sh
```

- If you previously saw `Dangerous link path ignored: Codex Installer/Applications`:
  - from extracting macOS app links.
  - usually non-fatal.

UX changes
- Can customize some UI assets in `work/app/webview` / static files.
- Avoid editing minified Electron/webpack bundles unless you accept high fragility.
- For durable UI changes, patch upstream source/build and repackage then wrap as normal.

What to answer if asked about “how does it work?”
- DMG holds macOS `.app` bundle.
- `app.asar` is extracted and unpacked.
- Linux-compatible Electron executes the unpacked app.
- CLI-backed app-server provides Codex backend behavior.
- GPT login is shared with installed CLI, not API-key-first startup.
