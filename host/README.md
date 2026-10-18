# host/ - Secondary PC tools

- `lib/protocol.py` - STORNADO binary frame codec (+ CRC32).
- `lib/transport.py` - `SerialTransport` (pyserial) and `MockTransport` (emulator).
- `cli/nvme_tool.py` - CLI: `info status temperature counters queues nvme-state
  benchmark reset-counters self-test`. Without `--port` -> mock transport.
- `gui/dashboard.py` - minimal text dashboard.
- `tests/test_protocol.py` - pytest tests (round-trip, CRC, mock).

```bash
pip install -r requirements.txt
python -m pytest tests -q
python cli/nvme_tool.py self-test --json
python cli/nvme_tool.py --port /dev/ttyUSB0 status   # real link
```

All mock values are **synthetic** (not measurements).
