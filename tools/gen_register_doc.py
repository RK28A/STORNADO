#!/usr/bin/env python3
"""Generate a Markdown register table from tools/registers.json (single source).

Usage:
    python3 tools/gen_register_doc.py [--out docs/register-map-generated.md]

Keeps the register documentation in sync with one machine-readable source, so RTL
and docs can be checked against the same data. No external dependencies.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tools" / "registers.json"


def render(data: dict) -> str:
    lines = ["# Register map (generated)", "",
             "Generated from `tools/registers.json` by `tools/gen_register_doc.py`.",
             "Do not edit by hand.", ""]
    for _key, block in data.items():
        lines.append(f"## {block['title']}")
        lines.append("")
        lines.append(f"_{block['spec']}_")
        lines.append("")
        lines.append("| Register | Offset | Width | Access | Role |")
        lines.append("|---|---|---|---|---|")
        for r in block["registers"]:
            lines.append(f"| {r['name']} | {r['offset']} | {r['width']} | {r['access']} | {r['role']} |")
        lines.append("")
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "docs" / "register-map-generated.md"))
    args = ap.parse_args(argv)
    data = json.loads(SRC.read_text())
    text = render(data)
    Path(args.out).write_text(text)
    print(f"wrote {args.out} ({len(data)} blocks)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
