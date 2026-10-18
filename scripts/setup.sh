#!/usr/bin/env bash
# Install simulation tools and host dependencies (Debian/Ubuntu).
set -euo pipefail
echo "[STORNADO] Installing tools..."
if command -v apt-get >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y iverilog verilator python3 python3-pip
fi
pip3 install -r "$(dirname "$0")/../host/requirements.txt"
echo "[STORNADO] OK. Run: make test-host && make sim"
