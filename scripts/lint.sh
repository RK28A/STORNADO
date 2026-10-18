#!/usr/bin/env bash
# RTL lint (verible) if available.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v verible-verilog-lint >/dev/null || { echo "verible missing (optional)"; exit 0; }
find rtl -name '*.sv' -print0 | xargs -0 verible-verilog-lint
