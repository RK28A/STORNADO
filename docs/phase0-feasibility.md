# PHASE 0 - Feasibility study

> Convention: **[SPEC]** = normative value, **[ASSUME]** = assumption to verify,
> **[MEAS]** = real measurement (none at this stage), **[GOAL]** = objective.
> No price, throughput or power is invented: unsourced figures are marked
> *to source*.

## 0.1 FPGA / SoC candidates

Three realistic families for a single person, from most accessible to most capable.

| Criterion | **Xilinx Artix-7 XC7A200T** | **Lattice ECP5 (LFE5UM-85F)** | **Intel Cyclone 10 GX** |
|---|---|---|---|
| PCIe Hard IP | Yes - *7 Series Integrated Block for PCIe*, **Gen2, up to x4** [ASSUME, verify PG054] | **No** - no PCIe hard IP; 5 Gb/s SERDES + *soft* PCIe stack | Yes - PCIe Hard IP **Gen2 x4** (H-Tile/P-Tile per variant) |
| Transceivers | GTP 6.6 Gb/s | SERDES 5 Gb/s | 10 Gb/s |
| LUT / FF | ~215k logic cells | ~84k LUT | ~80-220k LE |
| BRAM | ~13 Mb | ~3.7 Mb | variable |
| External memory | DDR3 (NiteFury board: 512 MB) | DDR3 | DDR3/DDR4 |
| Tools | **Vivado** (free WebPACK covers Artix-7) | **open-source** (Yosys + nextpnr) or Diamond | **Quartus Prime** (Lite/Standard) |
| PCIe license | Hard IP **included, no paid license** [ASSUME] | soft stack (open or third-party) | Hard IP included |
| JTAG | Yes | Yes | Yes |
| Ready-made M.2 board | **NiteFury**: M.2 2280 M-key, Gen2 x4, XC7A200T, ~329 USD (Crowd Supply, *sold out*, historical price) | mostly non-M.2 dev boards | few consumer M.2 boards |
| Availability | distributors (Digi-Key/Mouser) *to source* | good, low-cost | medium |

**Sources**: [NiteFury - Crowd Supply](https://www.crowdsupply.com/rhs-research/nitefury) ·
[7 Series Overview DS180](https://docs.amd.com/v/u/en-US/ds180_7Series_Overview) ·
[PG054 - 7 Series Integrated Block for PCIe](https://docs.amd.com/r/en-US/pg054-7series-pcie).

## 0.2 Difficulty and risk per block (/10)

| Block | Difficulty | Risk | Note |
|---|---:|---|---|
| Custom M.2 PCB | 9 | high | pushed to variant C; use an off-the-shelf M.2 board first |
| Signal integrity (Gen2) | 7 | medium | handled by the NiteFury board in variants A/B |
| M.2 power (3.3 V) | 6 | medium | budget to validate (see Phase 1) |
| PCIe link training | 5 | medium | provided by the Hard IP; depends on the Configuration Space |
| Configuration Space (0x010802) | 6 | medium | IP setup + 64-bit BAR + MSI-X |
| NVMe Admin (Identify, queues) | 8 | **high** | **block most likely to fail** on the logic side |
| I/O queues SQ/CQ | 7 | high | coupled to the DMA |
| DMA (PRP walk, 64-bit) | 8 | high | PRP correctness + alignment |
| Storage backend | 4 | low | BRAM first, DDR next |
| USB diagnostic | 4 | low | protocol already defined, standard PHY |
| Windows / stornvme compat | 9 | **very high** | zero tolerance on inconsistent CAP/Identify |
| Thermal | 4 | low | Artix-7 moderate; NiteFury heatsink available |
| Validation | 7 | medium | sim first, hardware next |

## 0.3 Chosen architecture

- **[GOAL]** Proof of concept on an **off-the-shelf M.2 board (NiteFury, Artix-7
  XC7A200T)** - no custom PCB before a mountable namespace under Windows.
- **[SPEC]** PCIe **Gen2 x4** via Hard IP (no PHY built from scratch - rule B.1).
- **[ASSUME]** Namespace backend: **BRAM** first (volatile, non-persistent,
  declared as such in Identify), then the board's DDR3.
- **[SPEC]** USB: diagnostic link separate from the storage path (no overlap).

Clear distinction:
- **Dev-board PoC** = variants A then B (PCIe/NVMe/Windows validation).
- **Final custom M.2 2280 board** = variant C (miniaturization), only once A/B are proven.

## 0.4 Answers to the start-up questions

1. **FPGA/board**: Artix-7 XC7A200T on a NiteFury M.2 board. Limits: Gen2 x4 (not Gen3), modest DDR3, custom PCB out of initial scope.
2. **M.2 slot / IOMMU**: **[NEED]** to confirm on the main PC (free M-key slot, VT-d/AMD-Vi enabled in BIOS).
3. **A/B/C costs**: see `variants-costs.md` (sourced figures or marked *to source*).
4. **Block most at risk**: Windows/stornvme compat (consistent CAP + Identify) and NVMe Admin.
5. **Anti-waste progression**: sim -> dev board -> Windows -> DMA test buffers -> custom PCB last.
6. **Without a paid IP license**: Xilinx PCIe Hard IP (included), NVMe/DMA/USB RTL (this repo), Vivado WebPACK.

---

PHASE 0 - Feasibility - **DONE (analysis)**
Decided: Artix-7 XC7A200T / NiteFury M.2 board; PCIe Gen2 x4 Hard IP; BRAM->DDR3 backend; separate USB.
Dropped: ECP5 (no PCIe Hard IP -> soft PCIe too risky solo); custom M.2 PCB upfront (SI/power/cost); Gen3 (not on Artix-7).
Implementation: FPGA comparison, difficulty/risk table, reference architecture, answers to the 6 questions.
Tests: re-check PG054 (Gen2 x4 Artix-7); confirm the main PC's M.2 slot + IOMMU.
Risk: CAP/Identify inconsistency -> stornvme refuses the controller; alt plan: align on a dump from a real SSD as a value reference.
Budget: NiteFury board ~329 USD (historical, sold out) - equivalent to source; high uncertainty on availability.
Next action: PHASE 1 - block diagram + preliminary BOM + power budget.
Need from you: real components (chosen FPGA board + target PC). Confirm a free M.2 M-key slot and IOMMU can be enabled.
