# AGENTS.md

## Purpose

This repository is an unofficial Linux porter for the macOS Codex app.
When working here, prefer the provided scripts over manually reproducing their steps.

## Primary workflow

Use these entrypoints unless the task is specifically about debugging an internal step:

1. `./setup/bootstrap.sh /path/to/Codex.dmg`
2. `./setup/05_verify_stack.sh`
3. `./run-codex-linux.sh`

Prefer `bootstrap.sh` over calling helper scripts one by one for normal setup work.

## Script roles

- `setup/00_install_prereqs.sh` checks or installs Linux prerequisites.
- `setup/01_download_or_link_dmg.sh` locates or copies the Codex DMG.
- `setup/02_extract_codex.sh` extracts the DMG and copies `app.asar`.
- `setup/03_unpack_asar.sh` unpacks `app.asar` into `work/app`.
- `setup/04_fix_native_modules.sh` installs or rebuilds Linux-compatible native modules.
- `setup/05_verify_stack.sh` verifies Electron, CLI, and native module compatibility.
- `setup/06_patch_sidebar_fallback.sh` applies Linux-specific runtime patches.
- `setup/bootstrap.sh` runs the full setup pipeline.

## Working rules

- Treat `work/` as generated output, not source.
- Prefer rerunning the scripts over manually editing files under `work/`.
- Do not commit generated files from `work/`.
- Keep docs explicit that this project is unofficial and not supported by OpenAI.
- Do not assume the Electron sandbox is enabled; the Linux fallback launcher currently uses `--no-sandbox`.

## Change guidance

- If changing setup behavior, update the relevant script in `setup/` and keep `bootstrap.sh` working end to end.
- If changing launch behavior, update `run-codex-linux.sh`.
- If changing user-facing setup expectations, update `README.md`.
- Preserve the script-first workflow in docs and examples.

## Verification

After meaningful changes, run:

```bash
./setup/05_verify_stack.sh
```

If the change affects setup or runtime launch, also run:

```bash
./setup/bootstrap.sh /path/to/Codex.dmg
./run-codex-linux.sh
```

## Avoid

- Do not hand-edit extracted files in `work/` unless the task explicitly requires patching generated runtime assets.
- Do not replace scripted steps with undocumented manual commands.
- Do not remove compatibility checks without updating both the scripts and `README.md`.
