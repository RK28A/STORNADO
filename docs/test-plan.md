# Test plan by milestones

Each test: **ID · prerequisites · hardware · procedure · observable · expected ·
logs · acceptance criterion · diagnostic on failure.** Current status: only logic
sim tests and the Python tests are runnable without hardware.

## Milestone 1 - Unit sim (runnable now)
| ID | Target | File | Expected |
|---|---|---|---|
| T1.1 | sync FIFO | `sim/unit/tb_sync_fifo.sv` | `PASS` |
| T1.2 | Registers + CC.EN->CSTS.RDY | `sim/unit/tb_nvme_regs.sv` | `PASS` |
| T1.3 | Init + doorbell | `sim/integration/tb_init_sequence.sv` | `PASS` |
| T1.4 | USB protocol (codec/CRC) | `host/tests/test_protocol.py` | `7 passed` ✅ (run) |

Sim procedure: `make sim` (iverilog) or `make sim-verilator`.
Python procedure: `make test-host` (run: **7 passed**).

## Milestone 2 - Synthesis & timing
Vivado: Artix-7 synthesis, timing closure, NiteFury board programming (JTAG).
Observable: timing report WNS >= 0; bitstream loaded. Diagnostic: XDC constraints.

## Milestone 3 - PCIe link training & Config Space
Observable: `link_up`, width/speed; device in Device Manager/`lspci`.
Criterion: BAR0 mapped, class 0x010802 read.

## Milestone 4 - stornvme + Identify
Criterion: driver attached; Identify Controller/Namespace consistent with CAP.

## Milestone 5 - Windows disk + namespace mount
Criterion: disk visible in Disk Management; namespace partitionable.

## Milestone 6 - File round-trip
Procedure: write a file, `certutil -hashfile`, read back, compare.
Criterion: **identical hash** (end-to-end integrity).

## Milestone 7 - USB + secondary software
Procedure: `nvme-tool self-test`, `info`, `status` over the real link.
Criterion: ACK on all commands, CRC OK, timestamped logs.

## Milestone 8 - DMA to authorized test buffers
Procedure: transfers to buffers **reserved by the test bench**; signatures/CRC;
4 GB+ runs; page boundaries; **include an IOMMU reject case** (must be cleanly
rejected as an error completion). No access outside the authorized buffers.

## Milestone 9 - Endurance & recovery
Prolonged transfers; error injection; controller/PCIe reset; power loss.
Criterion: no corruption; clean recovery (CSTS.CFS handled).

## Milestone 10 - M.2 2280 PCB (variant C)
Electrical check (rails, sequencing), thermal (ΔT), regression of milestones 1-9.

> PART J rule: the absence of a crash proves **neither** full PCIe/NVMe
> compliance **nor** security. These claims remain distinct and not acquired.
