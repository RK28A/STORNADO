"""The register-doc generator must produce a table with the key registers."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import gen_register_doc as gen  # noqa: E402


def test_render_contains_core_registers():
    data = json.loads((ROOT / "tools" / "registers.json").read_text())
    md = gen.render(data)
    for name in ("CAP", "CC", "CSTS", "Class Code"):
        assert f"| {name} " in md
    assert "0x010802" in md


def test_main_writes_file(tmp_path):
    out = tmp_path / "regs.md"
    assert gen.main(["--out", str(out)]) == 0
    assert out.exists() and "Register map (generated)" in out.read_text()
