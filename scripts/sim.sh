#!/usr/bin/env bash
# Shortcut: run all RTL testbenches via Icarus Verilog.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v iverilog >/dev/null || { echo "iverilog missing - see scripts/setup.sh"; exit 1; }
make sim
