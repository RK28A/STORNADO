# Register map (generated)

Generated from `tools/registers.json` by `tools/gen_register_doc.py`.
Do not edit by hand.

## NVMe controller registers (BAR0)

_NVMe Base 2.0c, section 3.1_

| Register | Offset | Width | Access | Role |
|---|---|---|---|---|
| CAP | 0x00 | 64 | RO | Capabilities (MQES, CQR, TO, DSTRD, CSS, MPSMIN/MAX) |
| VS | 0x08 | 32 | RO | Version = 0x00020000 (2.0.0) |
| INTMS | 0x0C | 32 | RW1S | Interrupt mask set |
| INTMC | 0x10 | 32 | RW1C | Interrupt mask clear |
| CC | 0x14 | 32 | RW | EN, CSS, MPS, IOSQES, IOCQES |
| CSTS | 0x1C | 32 | RO | RDY, CFS, SHST |
| NSSR | 0x20 | 32 | RW | Subsystem reset (if supported) |
| AQA | 0x24 | 32 | RW | Admin SQ/CQ sizes |
| ASQ | 0x28 | 64 | RW | Admin SQ DMA base |
| ACQ | 0x30 | 64 | RW | Admin CQ DMA base |
| SQ0TDBL | 0x1000+ | 32 | RW | Doorbells (stride 4, DSTRD=0) |

## PCIe Configuration Space (Type 0)

_PCIe Base 4.0; class 0x010802 (NVMe)_

| Register | Offset | Width | Access | Role |
|---|---|---|---|---|
| Vendor ID | 0x00 | 16 | RO | Legitimate/test VID (never spoof a vendor) |
| Device ID | 0x02 | 16 | RO | Project-owned DID |
| Command | 0x04 | 16 | RW | Memory Space (bit1) + Bus Master (bit2) |
| Class Code | 0x09 | 24 | RO | 0x010802 |
| BAR0/BAR1 | 0x10 | 64 | RW | 64-bit BAR mapping the NVMe registers |
