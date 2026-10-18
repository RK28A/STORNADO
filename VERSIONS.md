# Versions

Single place to track the versions that make up a STORNADO build. Bump these
together and tag releases from them (see CHANGELOG.md).

| Component | Version | Notes |
|---|---|---|
| Project | 0.1.0 | pre-hardware; code/sim only |
| RTL | 0.1.0 | skeleton + PRP walk, sim-verified in CI |
| Firmware | 0.1.0 | diagnostic dispatch, host-gcc compile only |
| USB protocol | 1 | `VERSION` in host/lib/protocol.py and firmware/stornado_frame.h |
| Target FPGA | TBD | to freeze (candidate: Artix-7 XC7A200T, see docs/phase0-feasibility.md) |

## Toolchain (to pin per dev environment)
| Tool | Pinned version | Status |
|---|---|---|
| Python | 3.12 (CI) | pinned in CI |
| pytest | >= 7 | host/requirements.txt |
| pyserial | >= 3.5 | host/requirements.txt |
| Icarus Verilog | distro package (CI: apt) | to pin exact version |
| Verilator | distro package | optional |
| Vivado | TBD | WebPACK, once the board is chosen |

> Not yet frozen: exact Icarus/Verilator/Vivado versions. Freeze them when the
> target board is selected (roadmap section 1 / 3).
