# Audit - potential bugs & unsupported constructs

Static review (no RTL simulator available in the build environment: RTL sim is
validated on your side / in CI with Icarus + Verilator). The Python tests pass
(`7 passed`). Split into **fixed** and **to watch**.

## Fixed in this pass

| # | Problem | Files | Fix |
|---|---|---|---|
| C1 | **Unpacked array ports** (`logic [15:0] x [N]` as ports) - poorly/not supported by Icarus Verilog | `nvme_doorbells`, `nvme_queue_mgr`, `stornado_top`, `tb_init_sequence` | Switched to **packed buses** `[N*16-1:0]`, access `[q*16 +: 16]` |
| C2 | `do … while` in testbench tasks - not guaranteed under Icarus | `tb_sync_fifo` | Replaced with `while` plus a clock wait |
| C3 | `break` + `fork…join` for polling - fragile/non-portable | `tb_nvme_regs` | `while` loop bounded by a `guard` counter |
| C4 | **Non-functional USB framer**: `MSG_TYPE/SEQ/PLEN` never extracted (payload never consumed) and CRC assembled backwards | `usb_packet_framer` | Rewritten: byte-by-byte extraction, `U_DECIDE` state, little-endian received CRC |
| C5 | Variable declaration in an unnamed `begin` of a `case` - rejected by some simulators | `usb_packet_framer` | Hoisted to `wire crc_rx_full` |
| C6 | **argparse**: `--json`/`--debug` placed before the subcommand were overwritten by the subparser default | `host/cli/nvme_tool.py` | `default=argparse.SUPPRESS` + `getattr` |
| C7 | **Unaligned** memory read `*(uint32_t*)payload` (UB on strict archs) | `firmware/stornado_diag.c` | `memcpy` into an aligned `uint32_t` |

## To watch (needs sim or hardware)

| # | Point | Where | Nature |
|---|---|---|---|
| S1 | Symbolic `RDY_DELAY` (!= real NVMe init latency) | `nvme_regs` | **[ASSUME]** - tune to real behavior |
| S2 | ~~Simplified CQ wrap~~ FIXED: wraps at the configured CQ size + phase toggle | `nvme_queue_mgr` | done, tb_queue_mgr |
| S3 | **No real PRP list walk** (PRP2 = list pointer if >2 pages); symbolic per-page DMA advance | `dma_engine` | `TODO` PART G - the DMA core is still to write |
| S4 | ~~`async_fifo` has no testbench~~ FIXED: `tb_async_fifo` (dual-clock) | `rtl/common` | done |
| S5 | `inside` operator (opcode classification) | `nvme_cmd_decoder` | tb_cmd_decoder added; confirm under Icarus -g2012 in CI |
| S6 | `pcie_wrapper` = **stub** (`link_up=0` tied): the top establishes no link as-is | `rtl/pcie` | normal - depends on the Hard IP (`TODO-IP`) |
| S7 | Backend `mem[65536]` x128 b in sim (~1 MiB) | `storage_backend_ram` | heavy but ok; reduce `CAP_BYTES` for fast sim |
| S8 | ~~Backend byte->word address mapping~~ FIXED: verified | `storage_backend_ram` | done, tb_storage_backend |
| S9 | Signals left unconnected at the top (expected lint warnings) | `stornado_top` | cosmetic; wire up during integration |
| S10 | `make lint` uses `rtl/**/*.sv` (needs `globstar`) | `Makefile` | use `scripts/lint.sh` (find) instead |

## How to enable debug

- **RTL**: `make sim-debug` (defines `STORNADO_DEBUG`) -> traces for the NVMe init
  FSM, doorbells, DMA, USB frames.
- **Host**: `python3 host/cli/nvme_tool.py --debug <cmd>` -> traces frame TX/RX.
- **Firmware**: compile with `-DSTORNADO_DEBUG` and provide `dbg_puts()`.

## Next code priorities
1. Implement the real **PRP walk** (S3) - the most structural block.
2. Add an **async_fifo testbench** (S4) and a backend read/write tb (S8).
3. Confirm `inside` under Icarus, otherwise replace with explicit comparisons (S5).
