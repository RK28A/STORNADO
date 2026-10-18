# PHASE 2 - Windows enumeration & storage

Verifiable chain, with per transition: expected trace, sim test or Windows tool,
expected result, diagnostic on failure.

| # | Transition | Observable / tool | Expected result | On failure |
|---|---|---|---|---|
| 1 | Power -> reset | LED/power, JTAG | FPGA configured | check 3.3 V sequencing, bitstream |
| 2 | PERST# -> link training | Hard IP status, ILA | `link_up=1`, width/speed negotiated | review refclk, lane polarity, SI |
| 3 | PCIe enumeration | `Device Manager`, `lspci` (Linux) | device visible, BAR0 mapped | Config Space, BAR size |
| 4 | Class identification | device properties | class **0x010802** | fix Class Code in the IP |
| 5 | stornvme load | Device Manager | `stornvme.sys` driver attached | inconsistent class/CAP/MSI-X -> see §consistency |
| 6 | Register/queue init | ILA on CC/CSTS/AQA | `CC.EN->CSTS.RDY`, ASQ/ACQ set | `nvme_regs` FSM, timeouts |
| 7 | Identify commands | Admin CQ trace | consistent Identify Controller/Namespace | review Identify structures vs CAP |
| 8 | Namespace discovery | `Disk Management` | 1 uninitialized disk | Identify NS (NSZE/LBAF) |
| 9 | Partition + format | `diskpart` / GUI | mounted NTFS volume | I/O Read/Write/Flush |
| 10 | File round-trip | copy + `certutil -hashfile` | **identical hash** | DMA/backend integrity |

## Critical consistency (non-rejection condition)
`CAP` (MQES, DSTRD, CSS, MPS) **<->** `Identify Controller/Namespace` values
**<->** actually implemented features. Any divergence = stornvme refuses or the
disk does not appear. Plan B: align values on a **dump from a real NVMe SSD**
used as a reference (read Config/CAP/Identify of a commercial SSD).

## Tools
Windows: Device Manager, Disk Management, `diskpart`, `certutil`, `winsat disk`.
Linux (diagnostics): `lspci -vvv`, `nvme-cli`, `dmesg`. FPGA: Vivado
ILA/ChipScope on the internal buses.

---

PHASE 2 - Windows enumeration & storage - **SPECIFIED (not executed)**
Decided: 10 traceable transitions; CAP<->Identify consistency as an invariant.
Dropped: skipping sim to test directly on Windows (costly blind debug).
Implementation: procedure + tools + diagnostics per transition.
Tests: real execution = hardware (test-plan milestones 3-6).
Risk: stornvme rejection on inconsistency; alt plan: mirror a real SSD dump.
Budget: none (doc); costs in bring-up time.
Next action: attach an ILA to CC/CSTS/doorbells once the link is up.
Need from you: access to the main PC (admin rights, BIOS IOMMU, M.2 slot).
