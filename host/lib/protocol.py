"""STORNADO diagnostic protocol — binary frame codec.

Frame (little-endian):
    MAGIC(4)=b"STRN" | VER(1) | HDR_LEN(1) | MSG_TYPE(2) | FLAGS(2) |
    SEQ(4) | PLEN(4) | PAYLOAD(PLEN) | CRC32(4)

CRC32 is IEEE-802.3 computed over everything from VER up to the end of
PAYLOAD (i.e. excluding MAGIC and the CRC field itself).

Scope: diagnostics only. Commands act on embedded/test-bench buffers, never on
host memory (see docs/usb-protocol.md).
"""
from __future__ import annotations

import struct
import zlib
from dataclasses import dataclass, field
from enum import IntEnum

MAGIC = b"STRN"
VERSION = 1
HEADER_FMT = "<4sBBHHII"            # magic, ver, hdr_len, type, flags, seq, plen
HEADER_LEN = struct.calcsize(HEADER_FMT)


class MsgType(IntEnum):
    PING = 0x0001
    GET_INFO = 0x0002
    GET_STATUS = 0x0003
    GET_TEMPERATURE = 0x0004
    GET_COUNTERS = 0x0005
    GET_NVME_STATE = 0x0006
    GET_QUEUE_STATUS = 0x0007
    START_BENCHMARK = 0x0008
    STOP_BENCHMARK = 0x0009
    RESET_COUNTERS = 0x000A
    READ_DIAGNOSTIC_BUFFER = 0x000B
    WRITE_TEST_PATTERN = 0x000C
    ACK = 0x8000
    ERROR = 0x8001


class ErrorCode(IntEnum):
    OK = 0
    BAD_CRC = 1
    BAD_MAGIC = 2
    BAD_VERSION = 3
    UNKNOWN_TYPE = 4
    BAD_LENGTH = 5
    OUT_OF_RANGE = 6
    BUSY = 7


class ProtocolError(Exception):
    pass


def _crc32(data: bytes) -> int:
    return zlib.crc32(data) & 0xFFFFFFFF


@dataclass
class Frame:
    msg_type: int
    seq: int = 0
    flags: int = 0
    payload: bytes = b""
    version: int = VERSION

    def encode(self) -> bytes:
        header = struct.pack(
            HEADER_FMT, MAGIC, self.version, HEADER_LEN,
            int(self.msg_type), self.flags, self.seq, len(self.payload),
        )
        body = header[4:] + self.payload          # VER..PAYLOAD
        crc = _crc32(body)
        return header + self.payload + struct.pack("<I", crc)

    @classmethod
    def decode(cls, buf: bytes) -> "Frame":
        if len(buf) < HEADER_LEN + 4:
            raise ProtocolError("frame too short")
        magic, ver, hlen, mtype, flags, seq, plen = struct.unpack(
            HEADER_FMT, buf[:HEADER_LEN]
        )
        if magic != MAGIC:
            raise ProtocolError("bad magic")
        end = HEADER_LEN + plen
        if len(buf) < end + 4:
            raise ProtocolError("truncated payload/crc")
        payload = buf[HEADER_LEN:end]
        (crc_rx,) = struct.unpack("<I", buf[end:end + 4])
        if _crc32(buf[4:end]) != crc_rx:
            raise ProtocolError("bad crc")
        return cls(msg_type=mtype, seq=seq, flags=flags, payload=payload, version=ver)


def read_frame(reader) -> Frame:
    """Read one frame from a stream exposing .read(n). Resyncs on MAGIC."""
    window = b""
    while len(window) < 4:
        b = reader.read(1)
        if not b:
            raise ProtocolError("eof while seeking magic")
        window += b
        if len(window) > 4:
            window = window[-4:]
        if window == MAGIC:
            break
    rest = reader.read(HEADER_LEN - 4)
    _, _, _, _, _, _, plen = struct.unpack(HEADER_FMT, MAGIC + rest)
    body = reader.read(plen + 4)
    return Frame.decode(MAGIC + rest + body)
