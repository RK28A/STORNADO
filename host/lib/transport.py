"""Transports for the STORNADO diagnostic link.

SerialTransport  : real USB-CDC / FTDI link via pyserial.
MockTransport    : in-process device emulator so the CLI and tests run with no
                   hardware. It answers a subset of diagnostic commands with
                   plausible, clearly-synthetic values.
"""
from __future__ import annotations

import io
import logging
import struct

from .protocol import Frame, MsgType, ErrorCode, read_frame

log = logging.getLogger("stornado.transport")


class Transport:
    def send(self, frame: Frame) -> None: ...
    def recv(self) -> Frame: ...
    def close(self) -> None: ...


class SerialTransport(Transport):
    def __init__(self, port: str, baud: int = 921600, timeout: float = 1.0):
        import serial  # pyserial, optional
        self._ser = serial.Serial(port, baud, timeout=timeout)

    def send(self, frame: Frame) -> None:
        raw = frame.encode()
        log.debug("TX type=0x%04x seq=%d plen=%d raw=%s",
                  frame.msg_type, frame.seq, len(frame.payload), raw.hex())
        self._ser.write(raw)

    def recv(self) -> Frame:
        f = read_frame(self._ser)
        log.debug("RX type=0x%04x seq=%d plen=%d", f.msg_type, f.seq, len(f.payload))
        return f

    def close(self) -> None:
        self._ser.close()


class MockTransport(Transport):
    """Emulated device. Values are synthetic placeholders, not measurements."""

    def __init__(self):
        self._out = io.BytesIO()
        self._counters = {"reads": 0, "writes": 0, "errors": 0}
        self._bench = False

    def send(self, frame: Frame) -> None:
        log.debug("TX(mock) type=0x%04x seq=%d plen=%d",
                  frame.msg_type, frame.seq, len(frame.payload))
        self._out = io.BytesIO(self._reply(frame).encode())

    def recv(self) -> Frame:
        self._out.seek(0)
        f = read_frame(self._out)
        log.debug("RX(mock) type=0x%04x seq=%d plen=%d", f.msg_type, f.seq, len(f.payload))
        return f

    def close(self) -> None:
        pass

    def _reply(self, f: Frame) -> Frame:
        t = f.msg_type
        if t == MsgType.PING:
            return Frame(MsgType.ACK, f.seq, payload=f.payload)
        if t == MsgType.GET_INFO:
            info = b"STORNADO mock\x00fw=0.1.0\x00bitstream=none"
            return Frame(MsgType.ACK, f.seq, payload=info)
        if t == MsgType.GET_STATUS:
            # link_up=0, nvme_ready=0, width=0, speed=1 (synthetic)
            return Frame(MsgType.ACK, f.seq, payload=struct.pack("<BBBB", 0, 0, 0, 1))
        if t == MsgType.GET_TEMPERATURE:
            return Frame(MsgType.ACK, f.seq, payload=struct.pack("<i", 42))  # °C synth.
        if t == MsgType.GET_COUNTERS:
            c = self._counters
            return Frame(MsgType.ACK, f.seq,
                         payload=struct.pack("<III", c["reads"], c["writes"], c["errors"]))
        if t == MsgType.RESET_COUNTERS:
            self._counters = {k: 0 for k in self._counters}
            return Frame(MsgType.ACK, f.seq)
        if t == MsgType.START_BENCHMARK:
            self._bench = True
            return Frame(MsgType.ACK, f.seq)
        if t == MsgType.STOP_BENCHMARK:
            self._bench = False
            return Frame(MsgType.ACK, f.seq)
        if t == MsgType.GET_NVME_STATE:
            # CC.EN, CSTS.RDY, CSTS.CFS (synthetic, controller disabled)
            return Frame(MsgType.ACK, f.seq, payload=struct.pack("<BBB", 0, 0, 0))
        return Frame(MsgType.ERROR, f.seq, payload=struct.pack("<H", int(ErrorCode.UNKNOWN_TYPE)))
