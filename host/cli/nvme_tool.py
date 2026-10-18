#!/usr/bin/env python3
"""nvme-tool - STORNADO diagnostic CLI (secondary PC).

Without --port, it uses the mock transport (in-process emulator): the CLI runs
with no hardware. With --port /dev/ttyUSBx (or COMx), it talks to the real USB
link via pyserial.

Exit codes:
  0  success
  1  the device returned an ERROR frame
  2  usage error (argparse)
  3  transport/connection failure (bad port, permission, busy, pyserial missing)

Values returned by the mock are synthetic, not measurements.
"""
from __future__ import annotations

import argparse
import csv as csvmod
import datetime as dt
import json
import logging
import struct
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import Frame, MockTransport, MsgType, SerialTransport, TransportError  # noqa: E402

EXIT_OK, EXIT_DEVICE_ERROR, EXIT_USAGE, EXIT_TRANSPORT = 0, 1, 2, 3


def make_transport(port: str | None):
    return SerialTransport(port) if port else MockTransport()


def _roundtrip(tp, mtype, payload=b"", seq=0):
    tp.send(Frame(mtype, seq=seq, payload=payload))
    return tp.recv()


def _expect_ack(r):
    if r.msg_type == MsgType.ERROR:
        code = struct.unpack("<H", r.payload[:2])[0] if len(r.payload) >= 2 else 0
        return {"_error": True, "error_code": code}
    return None


def cmd_info(tp, _):
    r = _roundtrip(tp, MsgType.GET_INFO)
    return _expect_ack(r) or {"info": r.payload.decode("latin1").split("\x00")}


def cmd_status(tp, _):
    r = _roundtrip(tp, MsgType.GET_STATUS)
    e = _expect_ack(r)
    if e:
        return e
    link, nvme, width, speed = struct.unpack("<BBBB", r.payload)
    return {"link_up": bool(link), "nvme_ready": bool(nvme),
            "link_width": width, "link_speed_gen": speed}


def cmd_temperature(tp, _):
    r = _roundtrip(tp, MsgType.GET_TEMPERATURE)
    return _expect_ack(r) or {"temperature_c": struct.unpack("<i", r.payload)[0]}


def cmd_counters(tp, _):
    r = _roundtrip(tp, MsgType.GET_COUNTERS)
    e = _expect_ack(r)
    if e:
        return e
    reads, writes, errors = struct.unpack("<III", r.payload)
    return {"reads": reads, "writes": writes, "errors": errors}


def cmd_queues(tp, _):
    r = _roundtrip(tp, MsgType.GET_QUEUE_STATUS)
    return _expect_ack(r) or {"raw": r.payload.hex()}


def cmd_nvme_state(tp, _):
    r = _roundtrip(tp, MsgType.GET_NVME_STATE)
    e = _expect_ack(r)
    if e:
        return e
    en, rdy, cfs = struct.unpack("<BBB", r.payload)
    return {"cc_en": bool(en), "csts_rdy": bool(rdy), "csts_cfs": bool(cfs)}


def cmd_benchmark(tp, args):
    _roundtrip(tp, MsgType.START_BENCHMARK)
    time.sleep(args.seconds if args.seconds else 0)
    _roundtrip(tp, MsgType.STOP_BENCHMARK)
    return cmd_counters(tp, args)


def cmd_reset_counters(tp, _):
    return _expect_ack(_roundtrip(tp, MsgType.RESET_COUNTERS)) or {"reset": True}


def cmd_self_test(tp, _):
    ok = {}
    for name, mt in [("ping", MsgType.PING), ("info", MsgType.GET_INFO),
                     ("status", MsgType.GET_STATUS)]:
        ok[name] = _roundtrip(tp, mt, payload=b"\x01\x02").msg_type == MsgType.ACK
    return {"self_test": ok, "pass": all(ok.values())}


def cmd_discover(_tp, _args):
    ports = SerialTransport.list_ports()
    return {"ports": [{"device": d, "description": desc} for d, desc in ports]}


# discover does not use a transport
NO_TRANSPORT = {"discover"}

COMMANDS = {
    "info": cmd_info, "status": cmd_status, "temperature": cmd_temperature,
    "counters": cmd_counters, "queues": cmd_queues, "nvme-state": cmd_nvme_state,
    "benchmark": cmd_benchmark, "reset-counters": cmd_reset_counters,
    "self-test": cmd_self_test, "discover": cmd_discover,
}


def _write_csv(path: str, cmd: str, result: dict):
    row = {"timestamp": dt.datetime.now(dt.UTC).isoformat(), "command": cmd}
    for k, v in result.items():
        row[k] = json.dumps(v) if isinstance(v, (dict, list)) else v
    p = Path(path)
    new = not p.exists()
    with p.open("a", newline="") as f:
        w = csvmod.DictWriter(f, fieldnames=list(row.keys()))
        if new:
            w.writeheader()
        w.writerow(row)


def main(argv=None):
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--port", default=argparse.SUPPRESS, help="serial port (default: mock transport)")
    common.add_argument("--json", action="store_true", default=argparse.SUPPRESS, help="JSON output")
    common.add_argument("--csv", default=argparse.SUPPRESS, help="append a timestamped row to this CSV file")
    common.add_argument("--debug", action="store_true", default=argparse.SUPPRESS, help="trace frames (TX/RX)")

    p = argparse.ArgumentParser(description="STORNADO diagnostic CLI", parents=[common])
    sub = p.add_subparsers(dest="cmd", required=True)
    for name in COMMANDS:
        sp = sub.add_parser(name, parents=[common])
        if name == "benchmark":
            sp.add_argument("--seconds", type=float, default=0)
    args = p.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if getattr(args, "debug", False) else logging.WARNING,
        format="%(levelname)s %(name)s: %(message)s",
    )

    tp = None
    try:
        if args.cmd not in NO_TRANSPORT:
            tp = make_transport(getattr(args, "port", None))
        result = COMMANDS[args.cmd](tp, args)
    except TransportError as e:
        print(f"transport error: {e}", file=sys.stderr)
        return EXIT_TRANSPORT
    finally:
        if tp is not None:
            tp.close()

    if getattr(args, "csv", None):
        _write_csv(args.csv, args.cmd, result)

    if getattr(args, "json", False):
        print(json.dumps(result, indent=2))
    else:
        for k, v in result.items():
            print(f"{k}: {v}")

    return EXIT_DEVICE_ERROR if result.get("_error") else EXIT_OK


if __name__ == "__main__":
    raise SystemExit(main())
