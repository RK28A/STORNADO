# Requirements -> test -> proof matrix

Each functional requirement maps to a test and its current proof. "sim" = passes
in simulation/CI; "hw" = requires hardware (not yet proven).

| ID | Requirement (from the brief) | Test | Proof |
|---|---|---|---|
| RQ1 | Enumerate as PCIe class 0x010802 | Config Space read on host | hw (milestone 3) |
| RQ2 | Load under Windows via stornvme.sys | Device Manager | hw (milestone 4) |
| RQ3 | CC.EN -> CSTS.RDY init sequence | tb_nvme_regs | sim ✅ |
| RQ4 | Admin queues + Identify consistent with CAP | per-command tb + host | sim (partial) / hw |
| RQ5 | I/O Read/Write/Flush | per-command tb + file round-trip | hw (milestone 6) |
| RQ6 | PRP walk (offset, list, page split, 64-bit) | tb_dma_prp | sim ✅ |
| RQ7 | DMA bounded to host PRPs/buffers; IOMMU respected | tb_dma_prp + negative IOMMU case | sim (positive) / hw (reject) |
| RQ8 | Real mountable namespace | Disk Management + round-trip | hw (milestone 5/6) |
| RQ9 | Data integrity (write==read) | SHA-256 round-trip | hw (milestone 6) |
| RQ10 | USB diagnostic link, separate from storage | tb + host CLI | sim (codec) / hw (link) |
| RQ11 | USB framing: magic/len/CRC/seq/errors | test_protocol, test_c_vectors, RTL framer | sim ✅ (codec) |
| RQ12 | No stealth / no arbitrary RAM access | design review (risk-register) | by construction (dma_engine) |
| RQ13 | Namespace persistence declared honestly | Identify NS vs backend | sim/doc |

Advance a row's proof from hw/partial to sim/✅ only with an archived log.
