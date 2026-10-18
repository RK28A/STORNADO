# STORNADO

**STOR**age + tor**NADO** - an **NVMe storage controller on FPGA**, M.2 2280 form
factor, that enumerates as PCIe class `0x010802` and mounts under Windows via the
native `stornvme.sys` driver, with no third-party driver. A deliberate nod to
`stornvme`.

> **Status: engineering skeleton + tested software base.** This repo contains a
> reference architecture, starter synthesizable SystemVerilog RTL, testbenches,
> **working** host tools (CLI/protocol), and full per-phase documentation.
> **Nothing is "ready to flash":** blocks that depend on the PCIe Hard IP and
> real hardware are marked `TODO-IP` / `TODO-SPEC`. No hardware result
> (bitstream, scope capture, Windows test) is provided until it has been
> measured.

## What the project does (and does not)

- ✅ Real NVMe controller: registers, Admin/IO queues, commands, backend, storage DMA.
- ✅ DMA **bounded** to the PRPs/buffers provided by the host or reserved for the test bench.
- ✅ **Diagnostic** USB link, separate from the storage path.
- 🚫 No arbitrary RAM access, no exfiltration, no stealth. Bus Master != arbitrary
  memory read permission (see `docs/risk-register.md`).

## Layout

```
rtl/        SystemVerilog RTL: top, pcie(IP wrapper), nvme, dma, memory, usb, common
firmware/   diagnostic dispatch (C) for a soft-core/MCU
host/        secondary-PC tools: lib (protocol+transport), cli, gui, tests
sim/         unit + integration testbenches (Icarus/Verilator)
constraints/ XDC/SDC (documented placeholders)
pcb/         M.2 PCB notes (variant C)
scripts/     setup, sim, lint
docs/        phases 0->9, register map, USB protocol, risks, variants, tests
tests/       end-to-end integration test location
```

## Quick start (how-to-setup)

### 1. Prerequisites
```bash
# Debian/Ubuntu - simulation tools and Python
sudo apt-get install -y iverilog verilator python3 python3-pip
pip3 install -r host/requirements.txt    # pyserial, pytest
```
For FPGA synthesis: **Xilinx Vivado** (free WebPACK edition, covers Artix-7).
For linting: `verible-verilog-lint` (optional).

### 2. Run what works with no hardware
```bash
make test-host      # USB protocol tests (Python)   -> 7 passed
make sim            # RTL testbenches via Icarus     -> *: PASS
make sim-debug      # same with RTL traces (STORNADO_DEBUG)
make cli            # CLI demo over the mock transport (no FPGA)
```

Debug: `make sim-debug` (RTL), `nvme_tool.py --debug <cmd>` (host, traces TX/RX),
`-DSTORNADO_DEBUG` (firmware). Bug/limitation audit: `docs/REVIEW.md`.

### 3. Diagnostic CLI (secondary PC)
```bash
# no hardware (in-process emulator)
python3 host/cli/nvme_tool.py self-test --json
python3 host/cli/nvme_tool.py status

# with the real USB link
python3 host/cli/nvme_tool.py --port /dev/ttyUSB0 info
```

### 4. Synthesis (once you have the board)
See `docs/phase1-architecture.md` and `constraints/`. The PCIe Hard IP is
instantiated in `rtl/pcie/pcie_wrapper.sv` (the only device-specific file).

## Roadmap

| Phase | Doc | Status |
|---|---|---|
| 0 Feasibility | `docs/phase0-feasibility.md` | ✅ analysis |
| 1 Architecture | `docs/phase1-architecture.md` | ✅ draft |
| 2 Windows enumeration | `docs/phase2-windows-enumeration.md` | ✅ specified |
| 3 RTL & sim | `rtl/`, `sim/` | 🟡 base + TODO-IP |
| 4 DMA & IOMMU | `rtl/dma/`, `docs/` | 🟡 skeleton |
| 5 USB | `rtl/usb/`, `docs/usb-protocol.md` | ✅ protocol + framer |
| 6 Secondary-PC tools | `host/` | ✅ CLI/lib tested |
| 7 Perf/reliability | `docs/test-plan.md` | ⬜ hardware required |
| 8 Test milestones | `docs/test-plan.md` | 🟡 M1/M4 ok |
| 9 Final package | `docs/` | 🟡 in progress |

Full task-level plan with exit gates: `docs/ROADMAP.md`.

## Hardware to obtain
See `docs/variants-costs.md` and `docs/phase1-architecture.md` (BOM). Starting
reference: an Artix-7 M.2 board (NiteFury type) + a USB PHY (FT2232H or FT601).

## License
Code under the MIT license (see `LICENSE`). Educational project.
