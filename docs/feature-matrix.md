# Feature matrix

Maturity of each block. Columns are cumulative stages; a block is only as mature
as its rightmost checked column. **No column is checked without evidence.**

Legend: Spec = specified · Code = implemented in RTL/SW · Sim = passes a
simulation/test · Synth = synthesized (timing closed) · FPGA = proven on real
hardware · Win = proven under Windows.

| Block | Spec | Code | Sim | Synth | FPGA | Win | Evidence |
|---|:--:|:--:|:--:|:--:|:--:|:--:|---|
| Common FIFO (sync) | ✅ | ✅ | ✅ | — | — | — | tb_sync_fifo |
| Common FIFO (async/CDC) | ✅ | ✅ | ✅ | — | — | — | tb_async_fifo |
| NVMe registers + init FSM | ✅ | ✅ | ✅ | — | — | — | tb_nvme_regs |
| Doorbells | ✅ | ✅ | ✅ | — | — | — | tb_init_sequence |
| Queue manager (SQ/CQ, phase) | ✅ | ✅ | ✅ | — | — | — | tb_init_sequence + tb_queue_mgr (CQ wrap) |
| Command decoder | ✅ | ✅ | ✅ | — | — | — | tb_cmd_decoder (opcode classification) |
| DMA engine (PRP walk) | ✅ | ✅ | ✅ | — | — | — | tb_dma_prp (3-page, PRP list) |
| Storage backend (BRAM) | ✅ | ✅ | ✅ | — | — | — | tb_storage_backend |
| USB framer (RTL) | ✅ | ✅ | ✅ | — | — | — | tb_usb_framer (CRC good/bad, empty payload) |
| USB protocol (codec) | ✅ | ✅ | ✅ | n/a | — | — | test_protocol + test_c_vectors |
| PCIe Hard IP wrapper | ✅ | 🟡 | — | — | — | — | stub (link_up=0), TODO-IP |
| Host CLI / tools | ✅ | ✅ | ✅ | n/a | — | — | test_cli (mock) |
| Firmware dispatch | ✅ | ✅ | 🟡 | n/a | — | — | gcc compile + C-vector test |
| Windows enumeration | ✅ | — | — | — | — | — | spec only (docs/phase2) |
| M.2 PCB | 🟡 | — | — | — | — | — | notes only (pcb/) |

🟡 = partial. Update this table with the test name and date when a cell advances.
