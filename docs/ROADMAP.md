# STORNADO - Full roadmap

Version: 18 October 2026. Adapted from an external proposal, reconciled with the
actual repo state.

## Scope
Build and validate a real NVMe SSD controller on FPGA, using the standard Windows
driver, a working namespace, spec-compliant DMA transactions for storage buffers,
and a USB diagnostic path on a second computer. Memory tests are confined to
explicitly authorized buffers. No clandestine process access, no arbitrary
exfiltration, no anti-cheat bypass.

## Legend
- **[P0]** Blocking to get a working NVMe SSD.
- **[P1]** Important for a robust, usable prototype.
- **[P2]** Required for an integrated M.2 / product-quality version.
- **[OPT]** Comfort or future-feature improvement.
- `[x]` = already present in the repo **at code level** (not hardware-proven).
  Every unchecked box still requires proof by test.

> Reality check: no bitstream and no hardware demo exist yet. Items checked below
> are code/sim/tooling only; nothing is validated on real hardware or Windows.

## 0 - Current state and gates
- [ ] Distinguish in the README "specified", "coded", "simulated", "synthesized", "tested on FPGA", "tested under Windows".
- [ ] Publish a feature matrix with code version, proof and validation date.
- [x] Record the current absence of a bitstream and hardware demo (README + REVIEW).
- [ ] Define the exact target FPGA board and freeze tool versions.
- [ ] Establish milestones with stop criteria, and forbid the final PCB before hardware storage validation.

## 1 - [P0] Development infrastructure
- [ ] Make the tool install reproducible under Windows and Linux (scripts/setup.sh covers Debian/Ubuntu).
- [ ] Pin versions of Vivado, Icarus, Verilator, Python and dependencies.
- [x] Fix the `rtl/**/*.sv` glob in the lint target (now uses scripts/lint.sh, portable).
- [x] Make CI/lint fail on a real error (lint no longer masks with `|| true`).
- [x] Add recursive lint scripts (scripts/lint.sh).
- [x] Add make targets `test-host`, `sim`, `lint` (and `cli`, `sim-debug`). Still missing: `package`.
- [x] Create GitHub Actions CI for Python tests and RTL simulation (.github/workflows/ci.yml).
- [ ] Archive logs, waveforms and failure reports as CI artifacts.
- [ ] Handle proprietary IP dependencies outside the repo.
- [ ] Add a hardware/RTL/firmware/protocol version file.
- [ ] Require regression tests on every pull request.
- [ ] Enable C/Python static analysis and automated formatting.

## 2 - [P0] Simulation and common RTL
- [ ] Run `make sim` in a tooled environment; do not confuse declared tests with executed results.
- [ ] Pass the testbenches on Icarus and, where supported, Verilator.
- [ ] Create a testbench for async_fifo with two asynchronous clocks. *(REVIEW S4)*
- [ ] Test the CDC synchronizers and skewed-reset scenarios.
- [ ] Add overflow, underflow, backpressure, reset, FIFO-drain tests.
- [ ] Verify SystemVerilog `inside` and packed-port constructs. *(REVIEW S5)*
- [ ] Cover edge cases with assertions.
- [x] Add timeouts to the testbenches to avoid infinite simulations.
- [ ] Add deterministic randomized tests (recorded seed).
- [ ] Add FSM and error-transition coverage.
- [ ] Check unconnected signals and implicit widths at the top. *(REVIEW S9)*
- [ ] Add endianness, alignment and byte-mask tests.

## 3 - [P0] FPGA choice and PCIe interface
- [ ] Confirm FPGA reference, package, transceivers, supported PCIe generation and width.
- [ ] Verify the license and documentation of the 7 Series Integrated Block for PCIe or equivalent.
- [ ] Select an available dev board (the cited NiteFury is historically sold out).
- [ ] Replace the `rtl/pcie/pcie_wrapper.sv` stub: `link_up` is currently tied to 0. *(REVIEW S6)*
- [ ] Adapt the Hard IP interface to a well-defined internal bus.
- [ ] Validate reset, PCIe clock, LTSSM and status signals.
- [ ] Verify the configuration capabilities and the required MMIO BARs.
- [ ] Define the interrupts (MSI/MSI-X) actually supported.
- [ ] Test compliant aligned/unaligned MMIO accesses.
- [ ] Handle transaction errors and functional resets.
- [ ] Document the width and throughput negotiated in the lab.
- [ ] Capture an ILA trace of init and BAR access.

## 4 - [P0] PCI identity and NVMe registers
- [ ] Set up a legitimate development PCI identity, class 0x010802.
- [ ] Validate Config Space, BAR sizes and the actually advertised capabilities.
- [x] Have CAP/VS/CC/CSTS/AQA/ASQ/ACQ and doorbells implemented with coherent registers/states (nvme_regs.sv, sim-checked T1.2).
- [ ] Verify each advertised value against the actually implemented capabilities.
- [ ] Replace the symbolic `RDY_DELAY` with coherent init logic, to validate. *(REVIEW S1)*
- [x] Have the CC.EN -> CSTS.RDY, disable and reset path (CFS pending on hardware). *(tb_nvme_regs)*
- [x] Respect the explicitly chosen NVMe version (VS = 2.0.0).
- [ ] Add partial read/write and reserved-field tests.
- [ ] Add a representative NVMe driver init simulation.
- [ ] Assess the gap between simulated behavior and a real SSD, without spoofing its identifiers.

## 5 - [P0] Admin queues and commands
- [ ] Finish the Admin SQ/CQ setup.
- [ ] Implement SQE fetch from the host-provided queue buffers.
- [ ] Verify field parsing, command CID and CQE responses.
- [ ] Verify CQ wrap per its configured size and Phase Tag toggle. *(REVIEW S2)*
- [ ] Handle indices, queue depth, overruns and invalid queue IDs.
- [ ] Implement the admin commands actually required by the target driver.
- [ ] Validate Identify Controller and Identify Namespace and consistency with CAP.
- [ ] Validate Set/Get Features used by the Windows stack.
- [ ] Validate I/O queue create/delete and associated errors.
- [x] Define normative behavior for an unsupported opcode (cmd_decoder issue_unsupported).
- [ ] Handle malformed commands, invalid lengths and in-flight reset.
- [ ] Add per-command testbenches and a complete init trace.

## 6 - [P0] I/O queues, storage DMA and PRP
- [ ] Finish I/O SQ/CQ handling and completions.
- [ ] Implement the DMA path for queues and data exclusively to host-authorized I/O buffers.
- [ ] Finish PRP1/PRP2 and PRP-list support within the NVMe storage scope. *(REVIEW S3 - the biggest block)*
- [ ] Verify transfers crossing page boundaries, plus 64-bit address cases.
- [ ] Respect the chosen PCIe interface size and alignment limits.
- [ ] Handle fragmentation and reception of multiple read completions.
- [ ] Handle backpressure and in-flight transaction queues.
- [ ] Detect PCIe timeouts and errors and report the correct I/O statuses.
- [x] Never assume a bus master grants access to all memory space (documented in dma_engine + risk-register).
- [ ] Test with IOMMU enabled and driver/lab buffers.
- [ ] Add negative cases where an unauthorized transaction is cleanly rejected.
- [ ] Test reset during DMA and absence of buffer corruption.
- [ ] Measure transaction, error, throughput and latency counters.

## 7 - [P0] Storage backend
- [ ] Fix and test the byte -> word mapping of the existing RAM backend. *(REVIEW S8)*
- [ ] Test LBA0, last LBA, out-of-bounds and varied-size read/write.
- [ ] Verify the match between NSZE, LBA format and actually available capacity.
- [ ] Test Write then Read then SHA-256 comparison on test data.
- [ ] Clearly define volatility and real persistence.
- [ ] Implement Flush with semantics matching the chosen backend.
- [ ] Test several successive then simultaneous I/O commands.
- [ ] Test namespace formatting and reuse.
- [ ] Integrate external DDR if higher capacity is required, after BRAM validation.
- [ ] Never confuse DDR3 (volatile) with persistent flash storage.
- [ ] Define a persistent backend (eMMC/NAND/other) if the final version must retain data when powered off.

## 8 - [P0] Windows tests
- [ ] Confirm FPGA power and programming on the real board.
- [ ] Get link_up and a PCIe device visible in the OS.
- [ ] Check class 0x010802 and BAR mapping.
- [ ] Verify the Microsoft stornvme.sys driver attaches.
- [ ] Capture CC/CSTS init and Admin transactions.
- [ ] Have Windows discover the namespace.
- [ ] Show a disk in Disk Management.
- [ ] Partition then format (on a test machine, no data at risk).
- [ ] Mount a volume and do a file round-trip.
- [ ] Verify SHA-256 on write and read-back.
- [ ] Test reboot, reset, controlled shutdown and recovery.
- [ ] Only declare "working SSD" after these proofs.

## 9 - [P1] Physical USB and protocol
- [ ] Choose FT2232H, FT601 or an interface compatible with the available power and space.
- [ ] Actually integrate the USB PHY with the FPGA logic / firmware.
- [x] Keep a strict separation between NVMe storage and diagnostics (separate path in top + usb framer).
- [x] Have endianness, length, CRC, sequence and error codes defined in the protocol (usb-protocol.md + protocol.py).
- [x] Re-run the recently fixed USB framer tests (host test_protocol, 7 passed).
- [ ] Add a byte-by-byte testbench covering payload, CRC and fragmented frames (RTL framer).
- [ ] Add truncated-frame, oversized, unknown-command, bad-CRC tests.
- [ ] Test USB disconnect/reconnect without interrupting storage.
- [ ] Test FIFO saturation and USB backpressure.
- [ ] Add a protocol version identifier and capability negotiation.
- [x] Ensure diagnostic commands only expose internal/authorized buffers (firmware bounds to diag_buffer).

## 10 - [P1] Firmware and secondary-PC tools
- [ ] Validate firmware compilation on its real MCU/soft-core target (compiles with host gcc as a syntax check).
- [ ] Provide the exact hardware port of UART/USB, timers, logs, reset and CRC.
- [x] Fix memory-alignment issues (unaligned read fixed via memcpy, REVIEW C7).
- [ ] Test the C <-> Python protocol with shared binary vectors.
- [ ] Add end-to-end tests over real USB.
- [x] Clarify the difference between the mock transport and the physical FPGA device (docstrings + host/README).
- [x] Stabilize the CLI commands info/status/queues/counters/self-test (over the mock).
- [x] Add stable JSON output (--json); document CLI exit codes (exit code is still to document).
- [ ] Add automatic device discovery on the second PC.
- [ ] Add handling of busy port, permissions, reconnection and timeout.
- [ ] Add CSV/JSON export and timestamped logs.
- [x] Prevent writing outside diagnostic buffers (firmware OUT_OF_RANGE guard).
- [ ] Produce a packaged, reproducible Windows executable, without claiming it is tested if not executed.

## 11 - [P1] Observability and robustness
- [ ] Define per-stage counters: link, commands received, completed, rejected, errors.
- [ ] Expose queue and clock state.
- [ ] Add a controller watchdog and reset diagnostics.
- [ ] Capture NVMe and PCIe errors with code, subsystem and timestamp.
- [ ] Establish a recovery protocol after a queue or USB-interface stall.
- [ ] Detect overheating or undervoltage when the hardware provides the measurements.
- [ ] Plan fault injection in simulation and automated recovery.
- [ ] Add endurance, saturation, mixed-load, command-error tests.
- [ ] Document power-cut behavior: especially for volatile memory and in-flight writes.
- [ ] Measure p50/p95/p99 latency, IOPS, throughput, and compare across reproducible configs.

## 12 - [P2] Integrated M.2 2280 PCB
- [ ] Only start after proof of the PCIe link and a usable Windows volume.
- [ ] Confirm dimensions, thickness, M-key notch, mounting and component clearance.
- [ ] Draw the full schematic: FPGA, memory, optional flash, clocks, regulators, ESD, programming, USB.
- [ ] Establish the power tree (3.3 V input and secondary rails) and power sequence.
- [ ] Measure startup, idle and full-load current; compare to the M.2 host limits.
- [ ] Establish stackup, controlled impedances and PCIe SI rules.
- [ ] Review placement/routing with tools and an HDI PCB vendor if needed.
- [ ] Add test points, JTAG, boot/recovery and rail measurements.
- [ ] Verify thermal constraints in a closed enclosure.
- [ ] Request DFM/DFT and a BOM check before launching fabrication.
- [ ] Plan a first small batch and an electrical inspection procedure before inserting into a PC.
- [ ] Re-run the full test suite on the final board.

## 13 - [P1/P2] Documentation and delivery
- [ ] Complete architecture, diagrams, interfaces and internal-bus definitions.
- [ ] Publish a requirements register and a requirement -> test -> proof matrix.
- [ ] Add a verifiable BOM (manufacturer reference, quantity, supplier, dated price, replacement).
- [x] Explicitly mark SPEC/ASSUME/MEAS/GOAL data (convention in docs/README).
- [ ] Document the synthesis and bitstream-generation steps.
- [ ] Add a flash procedure and a recovery procedure after a failed flash.
- [ ] Publish a safe electrical bring-up guide on an isolated bench.
- [ ] Publish known limitations and Windows compatibility levels.
- [ ] Add a changelog, commit convention and contribution procedure (CONTRIBUTING.md exists).
- [ ] Version RTL, firmware, protocol, constraints, schematics and BOM together.
- [ ] Produce a release archive with sources, tests, checksums and instructions.

## 14 - [OPT] Nice options for later
- [ ] Native Windows GUI with PCIe/NVMe/USB link, temperature and power indicators.
- [ ] Real-time throughput, IOPS, p95/p99 and error charts.
- [ ] A "full self-test" button that runs the validation plan and exports a report.
- [ ] USB first-connection wizard with automatic diagnostics.
- [ ] Saveable, reproducible benchmark profiles.
- [ ] Session history with performance comparison.
- [ ] Local web dashboard on the secondary PC (no internet exposure by default).
- [ ] Local notifications on USB disconnect, critical error or overheating.
- [ ] Multicolor diagnostic LED on the board, if form factor and budget allow.
- [ ] Export waveforms and ILA signals tied to each incident.
- [ ] No-FPGA demo mode to test GUI/CLI on simulated data (mock transport already enables this).
- [ ] Log reader with NVMe/PCIe code explanations.
- [ ] Power-saving, performance and diagnostic modes (spec-compliant).
- [ ] Dual-image / "golden image" firmware for post-update recovery.
- [ ] Integrity check of distributed firmware images and bitstreams.
- [ ] Windows and Linux portability of the host tool.
- [ ] Documented Python API for test automation.
- [ ] pytest + cocotb integration for sequential and randomized tests.
- [ ] Real-SSD performance reference to compare protocol compliance, without spoofing its identity.
- [ ] Storage-backend health monitoring (wear/endurance if flash).
- [ ] Test the actually supported NVMe power states.
- [ ] Optional support for a second namespace if resources allow.
- [ ] USB config update without interrupting I/O, if safe.
- [ ] Rate-limited "command trace" mode to debug Identify/queues.
- [ ] Test-coverage measurement and an associated CI badge.
- [ ] HTML validation report before release, including limitations.
- [ ] A bench enclosure/adapter with accessible measurement points.
- [ ] Windows Event Viewer and Linux lspci/nvme-cli collection scripts.
- [ ] Automated hot-reset resilience tests if the platform allows.
- [ ] Latency-counter calibration against external measurements.
- [ ] A small catalog of supported FPGA boards via hardware adapters.
- [ ] A register-doc generator from a single YAML/JSON source.
- [ ] A minimal NVMe host simulator to validate the protocol without Windows.
- [ ] Automatic check that advertised capacity == allocated storage.
- [ ] Automatic generation of compatibility tables and BOM per release.

## 15 - Recommended order and exit criteria
- **Gate A - Base quality**: green CI, reproducible Python + RTL tests, async FIFO/backend tested.
- **Gate B - Coherent NVMe RTL**: CAP/Identify/queues and storage DMA pass an integrated simulation, negative cases included.
- **Gate C - Physical PCIe**: FPGA board programmed, real link_up, Config Space and BAR observed on host.
- **Gate D - Windows**: stornvme.sys attached, namespace visible, volume mounted, read/write verified by hash.
- **Gate E - Physical USB**: secondary-PC communication, CRC/reconnection tests, storage undisturbed.
- **Gate F - Reliability**: load tests, reset, IOMMU enabled on authorized buffers, no corruption.
- **Gate G - Final board**: measured power budget, PCB reviewed, first board fabricated then gates C-F replayed.

## Recommended first sprint
1. Fix the Makefile lint + wire automated CI. *(done)*
2. Add async_fifo tb and storage_backend_ram tb.
3. Fix the CQ phase and all configured queue sizes.
4. Verify the PRP walk in simulation for legitimate NVMe operations.
5. Run the Icarus and Verilator tests and fix incompatibilities.
6. Choose an actually purchasable FPGA/PCIe board and freeze the IP interface.
7. Revise the status docs to separate what works from what is still theoretical.

## End-of-project criteria
- The hardware is identified as an NVMe controller by Windows via its standard driver.
- At least one namespace really exists and allows reproducible reads/writes.
- Storage DMA transfers respect the host-provided buffers and the IOMMU.
- The second PC can read diagnostics over USB without disturbing storage.
- Every claimed result has archived proof.
- The final board meets power, M.2 mechanics and thermal constraints.
