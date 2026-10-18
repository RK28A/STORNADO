import struct
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import Frame, MsgType, ProtocolError, MockTransport  # noqa: E402


def test_roundtrip_empty():
    f = Frame(MsgType.PING, seq=7)
    assert Frame.decode(f.encode()) == f


def test_roundtrip_payload():
    f = Frame(MsgType.WRITE_TEST_PATTERN, seq=42, flags=3, payload=bytes(range(32)))
    g = Frame.decode(f.encode())
    assert g.payload == bytes(range(32))
    assert g.seq == 42 and g.flags == 3


def test_crc_detects_corruption():
    buf = bytearray(Frame(MsgType.PING, payload=b"abcd").encode())
    buf[12] ^= 0xFF  # flip a payload byte
    with pytest.raises(ProtocolError):
        Frame.decode(bytes(buf))


def test_bad_magic():
    buf = bytearray(Frame(MsgType.PING).encode())
    buf[0] ^= 0xFF
    with pytest.raises(ProtocolError):
        Frame.decode(bytes(buf))


def test_mock_ping():
    tp = MockTransport()
    tp.send(Frame(MsgType.PING, seq=1, payload=b"hi"))
    r = tp.recv()
    assert r.msg_type == MsgType.ACK
    assert r.payload == b"hi"


def test_mock_counters_reset():
    tp = MockTransport()
    tp.send(Frame(MsgType.RESET_COUNTERS))
    assert tp.recv().msg_type == MsgType.ACK
    tp.send(Frame(MsgType.GET_COUNTERS))
    reads, writes, errors = struct.unpack("<III", tp.recv().payload)
    assert (reads, writes, errors) == (0, 0, 0)


def test_mock_temperature():
    tp = MockTransport()
    tp.send(Frame(MsgType.GET_TEMPERATURE))
    (c,) = struct.unpack("<i", tp.recv().payload)
    assert isinstance(c, int)
