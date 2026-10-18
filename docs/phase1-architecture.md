# PHASE 1 - Hardware architecture

## 1.1 Block diagram

```
  M.2 M-key connector (PCIe x4 + 3.3 V)
        │
        ▼
 ┌──────────────────┐   refclk 100 MHz
 │  PCIe Hard IP     │◄──────────────── M.2 oscillator / clock
 │  (Gen2 x4)        │
 │  link training,   │   user_clk / user_rst
 │  Config Space     │────────────┐
 │  0x010802         │            │
 └───────┬──────────┘            │
   TLP   │  MMIO (BAR0)          │ Requester (Memory Rd/Wr)
         ▼                       ▼
 ┌───────────────┐      ┌──────────────────┐
 │ nvme_regs     │      │  dma_engine      │  (PRPs provided by the host)
 │ CAP/CC/CSTS…  │      │  SQE fetch,      │
 │ nvme_doorbells│      │  data transfer,  │
 └──────┬────────┘      │  CQE write       │
        │               └────────┬─────────┘
        ▼                        ▼
 ┌───────────────┐      ┌──────────────────┐
 │ nvme_queue_mgr│      │ storage_backend  │  BRAM -> DDR3
 │ SQ/CQ, phase  │      │ (real namespace) │
 └──────┬────────┘      └──────────────────┘
        ▼
 ┌───────────────┐
 │ nvme_cmd_dec  │  Admin/IO classification
 └───────────────┘

  -- DIAGNOSTIC path (separate from the storage path) --
 ┌───────────────┐   byte-stream    ┌──────────────┐   USB    ┌──────────┐
 │ usb_framer    │◄────────────────►│ USB PHY      │◄────────►│ PC #2    │
 │ (protocol)    │                  │ (FT601/ULPI) │          │ nvme-tool│
 └───────────────┘                  └──────────────┘          └──────────┘

  Supervision: reset_sync, cdc_sync/async_fifo (CDC link<->core<->USB),
               temperature/voltage sensors (XADC), power sequencing.
```

Flow: `M.2 -> PCIe Hard IP -> TLP/MMIO -> nvme_regs/doorbells -> cmd_decoder ->
queue_mgr -> dma_engine -> backend`. The diagnostic path (`usb_framer -> PHY ->
PC #2`) is **physically and logically separate** from the storage path.

## 1.2 Clock domains

| Domain | Source | Content |
|---|---|---|
| `user_clk` | PCIe Hard IP (125/250 MHz per width) | regs, queues, DMA, backend |
| `usb_clk` | USB PHY | USB framer |
| CDC | `async_fifo` / `cdc_sync` | link<->core and core<->USB crossings |

## 1.3 Preliminary BOM

Real references, prices *to source* (none invented). Variant B (prototype).

| Item | Reference | Source | Price |
|---|---|---|---|
| M.2 FPGA board | NiteFury (Artix-7 XC7A200T, M.2 2280, Gen2 x4, DDR3) | [Crowd Supply](https://www.crowdsupply.com/rhs-research/nitefury) | ~329 USD *(historical, sold out)* |
| USB PHY | FTDI FT601Q (USB 3.0 FIFO) **or** FT2232H (USB 2.0 HS) | Digi-Key/Mouser | *to source* |
| JTAG programmer | Xilinx Platform Cable / FT2232H | — | *to source* |
| Heatsink | NiteFury option (integrated heatsink) | Crowd Supply | *to source* |
| Main PC | Windows 10/11 x64, M.2 M-key slot, IOMMU | — | provided by you |
| Secondary PC | Windows/Linux + USB | — | provided by you |

For a **custom M.2 PCB** (variant C) the BOM extends: bare FPGA, M.2 edge
connector, DDR3, PMIC/regulators 3.3->1.0/1.8 V, oscillators, config EEPROM, ESD
protection, passives, test pads/JTAG - to establish only if A/B succeed.

## 1.4 Power budget (method)

> **[ASSUME]** - to replace with measurements (XADC + clamp) on the real board.
> The ceiling applicable to the M.2 connector and the host system must be
> validated **before** freezing the design (PART D rule).

| State | Item | Assumption | To measure |
|---|---|---|---|
| Boot | FPGA config + PLL lock | transient peak | 3.3 V inrush current |
| Idle | link up, controller disabled | static + clocks | P_idle |
| Full load | DMA + backend + USB active | dynamic logic + SERDES | P_max, ΔT |

DC/DC efficiency and margin (>= 20 %) to fold in once the regulators are known.

---

PHASE 1 - Hardware architecture - **DRAFT (on dev board)**
Decided: block diagram with a separate diagnostic path; 3 clock domains + CDC via async_fifo; BOM centered on an off-the-shelf M.2 board.
Dropped: immediate custom PCB (cost/risk); USB merged into the storage path (violates the A.2/B separation).
Implementation: `rtl/top/stornado_top.sv` wires regs+doorbells+queue_mgr+cmd_decoder+dma+backend+usb; PCIe wrapper isolated.
Tests: top elaboration/lint; regs+doorbells sim (`sim/`). Power/thermal measurements = hardware required.
Risk: power budget not measured; alt plan: cap the link width (x1/x2) during prototyping.
Budget: dominated by the FPGA board (~329 USD historical); USB PHY + cables *to source*.
Next action: wire the real PCIe Hard IP (Vivado IP) to the TLP<->MMIO bridge; connect the DMA SQE fetch.
Need from you: exact reference of the FPGA board you buy + USB PHY choice (USB 2.0 HS is enough for diagnostics).
