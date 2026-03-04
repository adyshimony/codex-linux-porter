# Codex Linux Wrapper (Ubuntu/Linux)

This project runs the macOS Codex Electron app on Linux by reusing the app payload from the DMG and launching it with a Linux Electron runtime.

## What this wrapper does

- Extracts the Codex `.dmg` file.
- Pulls `Codex.app/Contents/Resources/app.asar` from the DMG.
- Rebuilds native modules (`better-sqlite3`, `node-pty`) so they can run on Linux.
- Launches the unpacked Electron app payload with Linux-compatible `electron`.

The UI is still the official Codex app; only the runtime host changes.

## Folder layout

- `<REPO_ROOT>/work` **(important)**: all generated/working artifacts.
  - `dmg/` → copied DMG.
  - `app.asar` → extracted app bundle from `app.asar`.
  - `app/` → unpacked asar app source used by Electron.
  - `extracted_dmg/` → temporary extract tree from 7z.
  - `payload/info` and `.npm-cache`/`work` helper folders.
- `setup/*.sh` → bootstrap + setup pipeline scripts.
- `run-codex-linux.sh` → runtime launcher.

If you need a full reset, deleting this directory and rerunning setup is safe:

```bash
REPO_ROOT="$(pwd)"  # directory where you cloned this repo
rm -rf "$REPO_ROOT/work"
```

## DMG structure and why this works

A `.dmg` is basically a disk image container. In this app it contains the classic macOS app bundle:

- `Codex Installer/Codex.app/Contents/Resources/app.asar`
- `.../Codex.app/Contents/Resources/app.asar.unpacked` (optional)
- `.../Codex.app/Contents/Frameworks/...` etc.

`app.asar` is Electron’s archive format (`asar`) for app code/assets. We extract it and point Electron at the unpacked directory.

Flow:

1. `setup/01_download_or_link_dmg.sh` copies/gets `Codex.dmg`.
2. `setup/02_extract_codex.sh` extracts it with `7z` and copies `app.asar`.
3. `setup/03_unpack_asar.sh` unpacks `app.asar` into `work/app`.
4. `setup/04_fix_native_modules.sh` compiles Linux native addons (`better-sqlite3`, `node-pty`) with C++20 flags.
5. `setup/05_verify_stack.sh` checks Electron/CLI/native compatibility.
6. `run-codex-linux.sh` launches `electron` on `work/app`.

### Why this can work without rebuilding everything

- The app shell and web UI are JavaScript/HTML/CSS and can run on Electron across platforms.
- `asar` is just Electron’s packaging format; extracting and running payload content is expected.
- Only native add-ons differ by platform/ABI, so Linux rebuilds them and validates ELF binaries.

## How it launches and talks to CLI

`run-codex-linux.sh` sets `CODEX_CLI_PATH` and then execs Electron:

- `--` command uses your installed `electron` binary when available.
- If missing, it falls back to `npx electron@<version>`.
- Electron is pointed at `work/app` (unpacked payload).

Inside the app, one startup path starts the app backend using the CLI command:

- `bash -lc "codex app-server"`

So the wrapper relies on the **same `codex` CLI binary you already use on Linux**.

## Login: GPT login (no API key)

This wrapper does not require API keys.

Use this once:

```bash
codex login
```

That flow stores interactive auth state in the CLI user config. After that, the wrapper’s embedded app-server uses the CLI’s auth context automatically.

Useful checks:

```bash
codex login status
codex --help | head -n 1
```

If you still want key-based auth, CLI also supports `codex login --with-api-key`, but this wrapper’s intended local workflow is GPT/dev account login.

## Can I change the UX?

Short answer: yes, but with caveats.

What is safe/low risk:
- Frontend tweaks in extracted assets under `work/app/webview`.
- Replace static assets/icons/styles and restart app.

What is risky:
- Editing minified runtime code directly (`work/app/.vite/build/*.js`) can be fragile.
- Native bridge IPC assumptions and packaged assumptions can break quickly.
- Any mismatch in asset paths or preload contracts can crash startup.

Recommended path for real UX changes:
1. Patch Codex source in upstream repo.
2. Build Linux-compatible app bundle there (or re-create wrapper from your own built payload).
3. Re-import into wrapper flow.

## Will updates work?

Not in the automatic way.

The app’s built-in updater is configured through Sparkle and only starts on macOS production builds:

- `shouldIncludeSparkle` returns true only for macOS in non-dev build flavors.
- This Linux wrapper path runs as unpacked app dir with no Sparkle runtime on Linux.

Result: “Check for Updates” effectively no-op / unavailable under Linux wrapper.

For updates:

1. Download a new Codex DMG.
2. Re-run:

```bash
./setup/bootstrap.sh /path/to/new/Codex.dmg
```

The wrapper is re-primed with the new payload.

## Commands

Full bootstrap:

```bash
cd /path/to/codex-linux-wrapper
./setup/bootstrap.sh /path/to/Codex.dmg
codex login
./run-codex-linux.sh
```

Optional env overrides:

- `CODEX_DMG_PATH` or `CODEX_DMG_URL`
- `WORK_DIR` (defaults to `<repo>/work`)
- `APP_DIR` and `APP_ASAR_PATH`
- `ELECTRON_BIN`
- `CODEX_CLI_PATH`
- `ELECTRON_DISABLE_SANDBOX=1` (defaults from launcher)

Verification:

```bash
./setup/05_verify_stack.sh
```

Common expected outputs:
- `run-codex-linux.sh` finds Electron.
- CLI present at `codex`.
- App payload exists (`app.asar`, `app/`).
- Native addons show ELF format.

## Troubleshooting

- **`dangerous link ignored: Codex Installer/Applications`** during extraction: normal for macOS DMG symlink entries. Ignore.
- **App opens then exits with missing module / ABI errors**: rerun `./setup/04_fix_native_modules.sh`.
- **Startup still fails**: delete `work`, re-run bootstrap from a fresh DMG.

## Desktop launcher

Optional menu entry:

```ini
# <REPO_ROOT>/codex.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Codex Linux Wrapper
Comment=Run Codex macOS app payload on Linux
Exec=sh -c 'DIR="$(dirname "%k")"; "$DIR/run-codex-linux.sh"'
Icon=utilities-terminal
Terminal=false
Categories=Development;Utility;
```

## Clean GitHub repository

This folder is intentionally minimal and commit-friendly:

- It does **not** include the generated `work/` payload.
- The repo is ready for first-time `git init`, commit, and push.

Quick setup:

```bash
cd /path/to/codex-linux-wrapper-github
git init
git add .
git status
git commit -m "feat: add ubuntu wrapper and bootstrap instructions"
```

Then connect to GitHub without pushing from this host:

```bash
git branch -M main
git remote add origin git@github.com:<you>/<repo>.git
git remote -v
```

When you are ready to publish from another machine:

```bash
git push -u origin main
```
