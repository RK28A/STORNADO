#!/usr/bin/env bash
# Lint RTL (verible) si disponible.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v verible-verilog-lint >/dev/null || { echo "verible absent (optionnel)"; exit 0; }
find rtl -name '*.sv' -print0 | xargs -0 verible-verilog-lint
