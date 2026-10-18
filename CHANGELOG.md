# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/). Versions follow VERSIONS.md.
Commit convention: `type: summary` (feat, fix, docs, test, chore, refactor).

## [Unreleased]
### Added
- Real PRP walk in the DMA engine (PRP1 offset, PRP2-as-page vs PRP2-as-list,
  page-boundary split, list chaining); `tb_dma_prp` host-memory model and a
  Python reference model `tools/prp_model.py` (`test_prp_model`) that proves the
  algorithm without a Verilog simulator.
- Python static analysis with ruff (CI + `make lint-py`).
- Testbenches: `tb_async_fifo` (dual-clock CDC), `tb_storage_backend` (LBA rw + OOB),
  `tb_usb_framer` (CRC good/bad + empty payload), `tb_cmd_decoder` (opcode
  classification), `tb_queue_mgr` (CQ wrap + phase toggle).
- Shared C frame builder (`firmware/stornado_frame.{c,h}`) and a C<->Python
  wire-format equivalence test (`test_c_vectors`).
- CLI: exit codes (0/1/2/3), `discover`, `--csv` export, busy-port handling,
  protocol version check.
- Register-doc generator from `tools/registers.json` (`tools/gen_register_doc.py`).
- Docs: `ROADMAP.md`, `feature-matrix.md`, `requirements-matrix.md`, `VERSIONS.md`.
- Infra: `make package`, ruff/clang-format configs, PR template, firmware CI job.

### Changed
- Queue manager: CQ wrap now uses the configured CQ size (was fixed 16-bit wrap).
- All code comments, docs and strings translated to English.
- Packed buses instead of unpacked array ports (Icarus portability).
- `make lint` is now portable and fails on real lint errors.

### Fixed
- USB framer header parsing + little-endian CRC assembly.
- Firmware unaligned read (memcpy).
- argparse `--json`/`--debug` precedence.

## [0.1.0] - 2026-10-18
### Added
- Initial STORNADO skeleton: RTL, host tools, firmware, per-phase docs, CI.
