# pcb/

PCB notes for **variant C** (custom M.2 2280 board). Only start once variants A/B
are validated (mounted namespace + OK file round-trip).

Points to address (see `docs/phase1-architecture.md`):
- Stackup and reference planes; PCIe differential impedances (85 Ω) per spec.
- Transceiver placement, matched lengths/skews, return current.
- FPGA rails (3.3 -> 1.0/1.8 V), power sequencing, decoupling.
- M.2 M-key edge connector, ESD protection, convection/heatsink.
- FPGA vendor **and** PCB fab rules (distinguish from general rules).

No Gerber is provided (PART L rule: invent nothing). KiCad recommended.
