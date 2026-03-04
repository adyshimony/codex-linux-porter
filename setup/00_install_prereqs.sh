#!/usr/bin/env bash
set -euo pipefail

cat <<'MSG'
This script installs Linux packages required for the wrapper path.
Some environments disallow sudo; if so, install these packages manually.
MSG

REQUIRED_PACKAGES=(
  curl
  wget
  p7zip-full
  build-essential
  python3
  make
  g++
  libsecret-1-dev
  pkg-config
)

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script is for Ubuntu/Debian Linux only." >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "apt-get not found; install packages with your distro package manager." >&2
  exit 1
fi

MISSING=()
for pkg in "${REQUIRED_PACKAGES[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    MISSING+=("$pkg")
  fi
done

if ((${#MISSING[@]} > 0)); then
  echo "Installing missing packages: ${MISSING[*]}"
  sudo apt-get update
  sudo apt-get install -y "${MISSING[@]}"
else
  echo "All required apt packages are already installed."
fi

if ! command -v node >/dev/null 2>&1; then
  echo "Missing nodejs. Install via nvm or your package manager." >&2
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "Missing npm. Install via nvm or your package manager." >&2
fi

if ! command -v electron >/dev/null 2>&1; then
  echo "electron binary not found globally; you can still continue and set ELECTRON_BIN to your binary path."
fi

echo "Prerequisite check complete."
