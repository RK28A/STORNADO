#!/usr/bin/env bash
# Installe les dépendances de simulation et des outils hôte (Debian/Ubuntu).
set -euo pipefail
echo "[STORNADO] Installation des outils..."
if command -v apt-get >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y iverilog verilator python3 python3-pip
fi
pip3 install -r "$(dirname "$0")/../host/requirements.txt"
echo "[STORNADO] OK. Lance: make test-host && make sim"
