# Variants, costs and trade-offs

> No invented prices. Unsourced costs are marked *to source*; time is an effort
> estimate for a single person, not a commitment.

## Variant A - Economy bench (PCIe/NVMe validation)
FPGA dev board + PCIe link, BRAM backend, no USB.
- **Goal**: prove link training, Config Space 0x010802, register init, Identify.
- Components: Artix-7 board (NiteFury M.2 or dev board + PCIe slot), JTAG.
- Tools: Vivado WebPACK (free), this repo.
- PCB/assembly: none.
- Cost: board ~329 USD *(NiteFury historical, sold out - equivalent to source)*.
- Power/thermal: low (link + logic).
- Time: high on the NVMe Admin logic.
- Risks: R1, R2.

## Variant B - Functional prototype (namespace + USB)
A + real namespace (BRAM->DDR3) + USB diagnostics (PC #2).
- **Goal**: mountable disk under Windows, file round-trip, diagnostic CLI.
- Components: + USB PHY (FT2232H USB2 **or** FT601 USB3) + wiring.
- Tools: + C/Python toolchain (this repo).
- PCB: possibly a small USB adapter if not integrated.
- Cost: A + USB PHY *to source*.
- Time: + full DMA path + Windows bring-up.
- Risks: R3, R4, R7.

## Variant C - Integrated M.2 2280 board (miniaturization)
Custom PCB: bare FPGA + DDR3 + PMIC + USB + M.2 edge connector.
- **Goal**: final form factor, self-contained in an M.2 slot.
- Components: full BOM (see phase1 §1.3, extended).
- Tools: + PCB CAD (KiCad), HDI PCB fab, SMT assembly.
- Cost: FPGA + memories + PMIC + HDI PCB + assembly - **to quote after A/B**.
- Time: highest (SI, power, thermal, hardware bring-up).
- Risks: R5, R6, R8, R10 + all previous ones.

## Key trade-offs
| Axis | Cautious option | Ambitious option | STORNADO choice |
|---|---|---|---|
| PCIe width | x1 (bring-up) | x4 (perf) | x4 target, x1/x2 fallback |
| USB | 2.0 HS | 3.x | 2.0 HS first |
| Backend | BRAM (volatile) | DDR3/NAND (persistent) | BRAM -> DDR3 |
| PCIe IP | Hard IP (included) | soft (ECP5) | **Hard IP** (rule B.1) |
| Support | off-the-shelf dev board | custom M.2 PCB | dev board -> PCB last |

Rationale: minimize the risk of **useless fabrication** - a PCB (variant C) is
only etched once a mounted namespace and a validated file round-trip (A/B) exist.
