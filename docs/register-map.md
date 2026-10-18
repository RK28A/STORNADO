# Register map - PCIe Config Space & NVMe (BAR0)

> Values to **re-verify against the specifications** before freeze (PCIe Base
> 4.0, NVMe Base 2.0c). Marked [ASSUME] until confronted with the spec / a dump
> from a real reference SSD. No value is invented: uncertain fields are flagged.

## 1. PCIe Configuration Space (Type 0)

Target class: **Base 0x01 / Subclass 0x08 / Prog IF 0x02 = 0x010802** (NVMe).

| Field | Offset | Width | Reset | Notes |
|---|---|---|---|---|
| Vendor ID | 0x00 | 16 | [ASSUME] | **do not spoof a vendor**; use a legitimate/allocated or test VID |
| Device ID | 0x02 | 16 | [ASSUME] | project-owned DID |
| Command | 0x04 | 16 | 0x0000 | enable Memory Space (bit1) + Bus Master (bit2) for storage |
| Status | 0x06 | 16 | — | capabilities list bit |
| Revision ID | 0x08 | 8 | [ASSUME] | |
| Class Code | 0x09 | 24 | **0x010802** | [SPEC] |
| BAR0/BAR1 | 0x10 | 64 | — | 64-bit BAR, non-prefetchable, maps the NVMe registers |
| Capabilities Ptr | 0x34 | 8 | -> list | |
| PCI Express Cap | — | — | — | Device/Link Control, width/speed |
| MSI-X Cap | — | — | — | vector table (preferred over MSI) |
| Power Management | — | — | — | D0/D3 states |
| AER (option) | — | — | — | if implemented |

For each field: offset/width/reset/RW vs reserved bits/behavior/enumeration
criterion -> **to complete from PCIe Base** and from the Xilinx IP setup (PG054).
Reference: [PG054](https://docs.amd.com/r/en-US/pg054-7series-pcie).

## 2. NVMe registers (BAR0) - NVMe 2.0 §3.1

Implemented in `rtl/nvme/nvme_regs.sv` (see the code for exact reset values).

| Register | Offset | Width | Access | Role |
|---|---|---|---|---|
| CAP | 0x00 | 64 | RO | capabilities (MQES, CQR, TO, DSTRD, CSS, MPSMIN/MAX) |
| VS | 0x08 | 32 | RO | version = 0x00020000 (2.0.0) |
| INTMS | 0x0C | 32 | RW1S | interrupt mask set |
| INTMC | 0x10 | 32 | RW1C | interrupt mask clear |
| CC | 0x14 | 32 | RW | EN, CSS, MPS, IOSQES, IOCQES |
| CSTS | 0x1C | 32 | RO | RDY, CFS, SHST |
| NSSR | 0x20 | 32 | RW | subsystem reset (if supported) |
| AQA | 0x24 | 32 | RW | Admin SQ/CQ sizes |
| ASQ | 0x28 | 64 | RW | Admin SQ DMA base |
| ACQ | 0x30 | 64 | RW | Admin CQ DMA base |
| SQ0TDBL… | 0x1000+ | 32 | RW | doorbells (stride 4, DSTRD=0) |

**Init FSM** (`nvme_regs.sv`): `CC.EN 0->1` => after latency => `CSTS.RDY=1`;
`CC.EN 1->0` => controller reset => `CSTS.RDY=0`. Consistency **CAP <-> Identify
<-> advertised features** = condition for not being rejected by stornvme.

## 3. Commands

### Admin (needed for Windows init)
Identify (Controller 0x01 / Namespace 0x00 / NS list 0x02), Get/Set Features,
Create/Delete I/O SQ & CQ, Get Log Page (SMART/Health, Error, Firmware), Abort,
plus clean rejection of unsupported opcodes (status *Invalid Command Opcode*).

### I/O (NVM Command Set)
| Cmd | Opcode | Key fields | Validation |
|---|---|---|---|
| Flush | 0x00 | NSID | backend persists if applicable |
| Write | 0x01 | SLBA, NLB, PRP1/2 | LBA range, alignment, size |
| Read | 0x02 | SLBA, NLB, PRP1/2 | same |

Each command: opcode / input fields / validation / data flow / completion code /
positive + negative test -> detailed in `test-plan.md`.

## 4. Namespace
- Demo backend: **volatile BRAM** (non-persistent - declared explicitly).
- LBA = 512 B (LBA_SHIFT=9). Demo capacity 1 MiB (BRAM) -> DDR3 next.
- Flush: no-op on BRAM; real on DDR/NAND with power-loss handling.
- Identify Namespace: NSZE/NCAP/NUSE, LBAF (LBADS=9), **persistence advertised
  consistently with the real backend**.
