# host/ — Outils du PC secondaire

- `lib/protocol.py` — codec du cadre binaire STORNADO (+ CRC32).
- `lib/transport.py` — `SerialTransport` (pyserial) et `MockTransport` (émulateur).
- `cli/nvme_tool.py` — CLI : `info status temperature counters queues nvme-state
  benchmark reset-counters self-test`. Sans `--port` → transport mock.
- `gui/dashboard.py` — tableau de bord texte minimal.
- `tests/test_protocol.py` — tests pytest (round-trip, CRC, mock).

```bash
pip install -r requirements.txt
python -m pytest tests -q
python cli/nvme_tool.py self-test --json
python cli/nvme_tool.py --port /dev/ttyUSB0 status   # lien réel
```

Toutes les valeurs du mock sont **synthétiques** (pas des mesures).
