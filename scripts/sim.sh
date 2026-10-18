#!/usr/bin/env bash
# Raccourci : lance tous les testbenches RTL via Icarus Verilog.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v iverilog >/dev/null || { echo "iverilog absent — voir scripts/setup.sh"; exit 1; }
make sim
