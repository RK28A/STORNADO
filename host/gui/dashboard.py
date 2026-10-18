#!/usr/bin/env python3
"""Minimal text dashboard (optional GUI, PART I).

Refreshes link/NVMe state, temperature and counters. Works with the mock
transport when --port is omitted. A richer GUI (Qt/Tk/web) can reuse host/lib
as-is; this is the base.
"""
from __future__ import annotations

import argparse
import struct
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import Frame, MockTransport, MsgType, SerialTransport  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port")
    ap.add_argument("--interval", type=float, default=1.0)
    ap.add_argument("--iterations", type=int, default=0, help="0 = infinite")
    a = ap.parse_args()
    tp = SerialTransport(a.port) if a.port else MockTransport()

    i = 0
    try:
        while a.iterations == 0 or i < a.iterations:
            tp.send(Frame(MsgType.GET_STATUS))
            st = tp.recv().payload
            tp.send(Frame(MsgType.GET_TEMPERATURE))
            (t,) = struct.unpack("<i", tp.recv().payload)
            tp.send(Frame(MsgType.GET_COUNTERS))
            r, w, e = struct.unpack("<III", tp.recv().payload)
            link, nvme, width, speed = struct.unpack("<BBBB", st)
            print(f"\rlink={link} nvme_rdy={nvme} x{width} gen{speed} | "
                  f"{t}C | R={r} W={w} E={e}   ", end="", flush=True)
            i += 1
            if a.iterations == 0 or i < a.iterations:
                time.sleep(a.interval)
    except KeyboardInterrupt:
        pass
    finally:
        print()
        tp.close()


if __name__ == "__main__":
    main()
