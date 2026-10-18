#!/usr/bin/env python3
"""nvme-tool — CLI diagnostic STORNADO (PC secondaire).

Sans --port, utilise le transport mock (émulateur in-process) : la CLI tourne
sans matériel. Avec --port /dev/ttyUSBx (ou COMx), parle au lien USB réel via
pyserial.

Les valeurs renvoyées par le mock sont synthétiques, pas des mesures.
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import Frame, MsgType, MockTransport, SerialTransport  # noqa: E402


def make_transport(port: str | None):
    if port:
        return SerialTransport(port)
    return MockTransport()


def _roundtrip(tp, mtype, payload=b"", seq=0):
    tp.send(Frame(mtype, seq=seq, payload=payload))
    return tp.recv()


def cmd_info(tp, _):
    r = _roundtrip(tp, MsgType.GET_INFO)
    return {"info": r.payload.decode("latin1").split("\x00")}


def cmd_status(tp, _):
    r = _roundtrip(tp, MsgType.GET_STATUS)
    link, nvme, width, speed = struct.unpack("<BBBB", r.payload)
    return {"link_up": bool(link), "nvme_ready": bool(nvme),
            "link_width": width, "link_speed_gen": speed}


def cmd_temperature(tp, _):
    r = _roundtrip(tp, MsgType.GET_TEMPERATURE)
    (c,) = struct.unpack("<i", r.payload)
    return {"temperature_c": c}


def cmd_counters(tp, _):
    r = _roundtrip(tp, MsgType.GET_COUNTERS)
    reads, writes, errors = struct.unpack("<III", r.payload)
    return {"reads": reads, "writes": writes, "errors": errors}


def cmd_queues(tp, _):
    r = _roundtrip(tp, MsgType.GET_QUEUE_STATUS)
    return {"raw": r.payload.hex(), "type": int(r.msg_type)}


def cmd_nvme_state(tp, _):
    r = _roundtrip(tp, MsgType.GET_NVME_STATE)
    en, rdy, cfs = struct.unpack("<BBB", r.payload)
    return {"cc_en": bool(en), "csts_rdy": bool(rdy), "csts_cfs": bool(cfs)}


def cmd_benchmark(tp, args):
    _roundtrip(tp, MsgType.START_BENCHMARK)
    time.sleep(args.seconds if args.seconds else 0)
    _roundtrip(tp, MsgType.STOP_BENCHMARK)
    return cmd_counters(tp, args)


def cmd_reset_counters(tp, _):
    _roundtrip(tp, MsgType.RESET_COUNTERS)
    return {"reset": True}


def cmd_self_test(tp, _):
    ok = {}
    for name, mt in [("ping", MsgType.PING), ("info", MsgType.GET_INFO),
                     ("status", MsgType.GET_STATUS)]:
        r = _roundtrip(tp, mt, payload=b"\x01\x02")
        ok[name] = r.msg_type == MsgType.ACK
    return {"self_test": ok, "pass": all(ok.values())}


COMMANDS = {
    "info": cmd_info, "status": cmd_status, "temperature": cmd_temperature,
    "counters": cmd_counters, "queues": cmd_queues, "nvme-state": cmd_nvme_state,
    "benchmark": cmd_benchmark, "reset-counters": cmd_reset_counters,
    "self-test": cmd_self_test,
}


def main(argv=None):
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--port", help="port série (defaut: transport mock)")
    common.add_argument("--json", action="store_true", help="sortie JSON")

    p = argparse.ArgumentParser(description="STORNADO diagnostic CLI", parents=[common])
    sub = p.add_subparsers(dest="cmd", required=True)
    for name in COMMANDS:
        sp = sub.add_parser(name, parents=[common])
        if name == "benchmark":
            sp.add_argument("--seconds", type=float, default=0)
    args = p.parse_args(argv)

    tp = make_transport(args.port)
    try:
        result = COMMANDS[args.cmd](tp, args)
    finally:
        tp.close()

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        for k, v in result.items():
            print(f"{k}: {v}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
