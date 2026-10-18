"""Cross-check: the C frame encoder and the Python codec must agree byte-for-byte.

Compiles firmware/stornado_frame.c + tests/frame_vectors.c with gcc, runs several
vectors, and compares the raw frame hex to Python's Frame.encode(). Skips if gcc
is unavailable.
"""
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "host"))
from lib import Frame  # noqa: E402

pytestmark = pytest.mark.skipif(shutil.which("gcc") is None, reason="gcc not available")


@pytest.fixture(scope="module")
def harness(tmp_path_factory):
    out = tmp_path_factory.mktemp("cvec") / "frame_vectors"
    subprocess.run(
        ["gcc", "-std=c11", "-O2", "-I", str(ROOT / "firmware"),
         str(ROOT / "firmware" / "stornado_frame.c"),
         str(ROOT / "tests" / "frame_vectors.c"), "-o", str(out)],
        check=True,
    )
    return out


VECTORS = [
    (0x0001, 0, 0, b""),
    (0x0003, 7, 0, b"\x01\x02\x03\x04"),
    (0x000C, 42, 3, bytes(range(32))),
    (0x8000, 0xDEADBEEF, 0, b"hello world"),
    (0x000B, 1, 0, bytes([i % 256 for i in range(300)])),
]


@pytest.mark.parametrize("mtype,seq,flags,payload", VECTORS)
def test_c_matches_python(harness, mtype, seq, flags, payload):
    c_hex = subprocess.run(
        [str(harness), str(mtype), str(seq), str(flags), payload.hex()],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    py_hex = Frame(mtype, seq=seq, flags=flags, payload=payload).encode().hex()
    assert c_hex == py_hex
