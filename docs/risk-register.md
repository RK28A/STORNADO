# Risk register

For each risk: probability · severity · detection · mitigation · alternative · budget impact.

| # | Risk | Prob. | Severity | Detection | Mitigation | Alternative | Budget |
|---|---|---|---|---|---|---|---|
| R1 | stornvme rejects the controller (inconsistent CAP/Identify) | High | Critical | Device Manager, Identify CQ | Align on a real SSD dump; re-read NVMe 2.0 spec | Test first under Linux (`nvme-cli`), more verbose | Time |
| R2 | PCIe link training fails | Medium | Critical | Hard IP status, ILA | Off-the-shelf M.2 board (SI handled); cap x1/x2 | Stay on Gen1 x1 | Time |
| R3 | PRP walk / DMA incorrect (alignment, page boundaries) | High | High | CRC/signatures, sim | Reserved-buffer tests; assertions; 4 GB+ case | 1-page bounded transfers first | Time |
| R4 | IOMMU reject mishandled | Medium | High | `mem_err`, logs | Handle as error completion; dedicated test M8 | Disable IOMMU for bring-up (then re-enable) | Time |
| R5 | Timing closure not met (Artix-7) | Medium | Medium | Vivado WNS | Pipeline FSMs, lower user_clk frequency | Bigger/faster FPGA | Hardware |
| R6 | Power budget exceeded at the M.2 connector | Low | High | XADC, clamp | Measure early; cap link width | External power on bench | Hardware |
| R7 | Namespace persistence mis-declared (volatile BRAM) | Medium | Medium | Reboot + readback | Declare non-persistent explicitly in Identify | Move to DDR3/NAND | Hardware |
| R8 | Flash error / board bricking | Low | Medium | JTAG unreachable | Keep a recovery image; JTAG fallback mode | Reprogram via dedicated JTAG | Time |
| R9 | NiteFury board unavailable (sold out) | High | Medium | Distributors | Source an Artix-7 M.2 equivalent; dev board + M.2 adapter | Another family (Cyclone 10 GX) | Hardware |
| R10 | Thermal under prolonged load | Low | Medium | GET_TEMPERATURE, sensor | Heatsink; throttle benchmark | Reduce QD/throughput | Hardware |

Quality rule 12: **no** stealth/undetectability claim. The DMA stays bounded to
the authorized PRPs/buffers (R3/R4).
