// pcie_wrapper.sv - Wrapper around the PCIe Hard IP (VENDOR-SPECIFIC WRAPPER).
// This file isolates EVERYTHING that depends on the device: the Hard IP
// instantiation (Xilinx PCIe4C / Intel P-Tile / Lattice), the transceivers, the
// PLLs. The rest of the NVMe core stays portable and only sees the MMIO +
// memory-request interface below (quality rule 7: separate portable logic from
// IP wrappers).
//
// STATE: interface skeleton. Link training, width/speed negotiation, the
// Configuration Space (class 0x010802, BAR, MSI-X capability, PM) and the
// TLP<->MMIO mapping are provided by the IP and wired during integration (see
// docs/phase1-architecture.md and docs/register-map.md). DO NOT present this
// module as functional on hardware without link-up proof.
import nvme_pkg::*;

module pcie_wrapper #(
  parameter int LANES = 4
)(
  // physical references (to the M.2 connector / dev board)
  input  logic              refclk_p,
  input  logic              refclk_n,
  input  logic              perst_n,     // PCIe reset
  input  logic [LANES-1:0]  rx_p, rx_n,
  output logic [LANES-1:0]  tx_p, tx_n,

  // user clock/reset provided by the IP once the link is up
  output logic              user_clk,
  output logic              user_rst_n,
  output logic              link_up,
  output logic [3:0]        link_width,
  output logic [2:0]        link_speed,

  // ---- MMIO decoded from TLPs (toward nvme_regs / doorbells) ----
  output logic              mmio_sel,
  output logic              mmio_we,
  output logic [REG_AW-1:0] mmio_addr,
  output logic [REG_DW-1:0] mmio_wdata,
  output logic [3:0]        mmio_wstrb,
  input  logic [REG_DW-1:0] mmio_rdata,
  input  logic              mmio_ack,

  // ---- host memory requests (from dma_engine) ----
  input  logic              mem_req_valid,
  output logic              mem_req_ready,
  input  logic              mem_req_we,
  input  logic [63:0]       mem_req_addr,
  input  logic [10:0]       mem_req_len_dw,
  input  logic [127:0]      mem_wdata,
  output logic [127:0]      mem_rdata,
  output logic              mem_rvalid,
  output logic              mem_err,

  // ---- interrupts ----
  input  logic              msix_req,
  input  logic [10:0]       msix_vector
);
  // --------------------------------------------------------------------------
  // TODO-IP: instantiate the chosen device's PCIe Hard IP here.
  //   - Xilinx Artix-7/Kintex-7: pcie_7x / PCIE4C (via IP catalog + XDC).
  //   - Intel Cyclone 10 GX / Agilex: P-Tile / H-Tile Avalon-ST.
  // The TLP->MMIO bridge and the memory-request engine (Completer/Requester)
  // connect to the ports above. The Configuration Space values (VID/DID, class
  // 0x010802, 64-bit BAR0, MSI-X) are set inside the IP.
  // --------------------------------------------------------------------------

  // Fallback values so the module elaborates and simulates (NOT representative of
  // a real link). The integration testbench drives these signals directly.
  assign user_clk      = refclk_p;      // placeholder
  assign user_rst_n    = perst_n;
  assign link_up       = 1'b0;
  assign link_width    = LANES[3:0];
  assign link_speed    = 3'd1;
  assign mmio_sel      = 1'b0;
  assign mmio_we       = 1'b0;
  assign mmio_addr     = '0;
  assign mmio_wdata    = '0;
  assign mmio_wstrb    = '0;
  assign mem_req_ready = 1'b0;
  assign mem_rdata     = '0;
  assign mem_rvalid    = 1'b0;
  assign mem_err       = 1'b0;
  assign tx_p = '0; assign tx_n = '0;
endmodule : pcie_wrapper
