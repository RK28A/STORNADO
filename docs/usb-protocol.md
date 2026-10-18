# STORNADO USB diagnostic protocol (v1)

**Diagnostic-only** link, separate from the storage path. Commands act on
**embedded / test-bench buffers** - never on the main PC's memory. No stealth,
no access to third-party processes.

## PHY choice
| Option | Throughput | Cost | Routing | Verdict |
|---|---|---|---|---|
| USB 2.0 HS (FT2232H) | 480 Mb/s | low | simple | **enough for diagnostics** |
| USB 3.x (FT601) | ~5 Gb/s | medium | more demanding | for large buffer dumps |

Recommended: **USB 2.0 HS** first (light thermal/electrical budget), USB 3.x
optional for large `READ_DIAGNOSTIC_BUFFER`.

## Binary frame (little-endian)

```
 Offset  Size  Field
 0       4     MAGIC   = "STRN" (0x53 0x54 0x52 0x4E)
 4       1     VERSION = 1
 5       1     HDR_LEN = 18
 6       2     MSG_TYPE
 8       2     FLAGS
 10      4     SEQ_ID
 14      4     PAYLOAD_LEN
 18      N     PAYLOAD
 18+N    4     CRC32 (IEEE 802.3, over VERSION..PAYLOAD)
```

Endianness: little-endian everywhere. CRC computed from the `VERSION` byte
(offset 4) to the end of `PAYLOAD`. Identical implementations in Python
(`host/lib/protocol.py`), C (`firmware/stornado_diag.c`) and RTL
(`rtl/usb/usb_packet_framer.sv`).

## Message types

| Name | Value | Meaning |
|---|---|---|
| PING | 0x0001 | echo |
| GET_INFO | 0x0002 | fw/bitstream/ids |
| GET_STATUS | 0x0003 | link/nvme/width/speed |
| GET_TEMPERATURE | 0x0004 | °C (int32) |
| GET_COUNTERS | 0x0005 | reads/writes/errors (u32x3) |
| GET_NVME_STATE | 0x0006 | CC.EN/CSTS.RDY/CSTS.CFS |
| GET_QUEUE_STATUS | 0x0007 | SQ/CQ heads/tails |
| START_BENCHMARK | 0x0008 | internal test bench |
| STOP_BENCHMARK | 0x0009 | |
| RESET_COUNTERS | 0x000A | |
| READ_DIAGNOSTIC_BUFFER | 0x000B | reads the **embedded** buffer |
| WRITE_TEST_PATTERN | 0x000C | writes the **embedded** buffer |
| ACK | 0x8000 | OK response |
| ERROR | 0x8001 | payload = code (u16) |

## Error codes
`OK=0, BAD_CRC=1, BAD_MAGIC=2, BAD_VERSION=3, UNKNOWN_TYPE=4, BAD_LENGTH=5,
OUT_OF_RANGE=6, BUSY=7`.

## Robustness
Resync on `MAGIC`, host-side timeout, `SEQ_ID` to match request/response,
idempotent reconnection, reject any `PAYLOAD_LEN` exceeding the embedded buffer
size (`OUT_OF_RANGE`). Segment large transfers via an increasing `SEQ_ID`.
