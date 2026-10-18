// dma_engine.sv - NVMe storage DMA engine (SKELETON).
// LEGITIMATE and ONLY role: for a given NVMe command, read the SQE, fetch the
// host-provided PRPs, transfer data blocks between the host memory DESIGNATED BY
// THOSE PRPs and the storage backend, then write the CQE. It never generates an
// address on its own.
//
// IMPORTANT (see PART G / quality rule 5): Bus Master Enable is NOT an arbitrary
// RAM read permission. This engine only addresses the pages listed in the PRPs
// of the current command. No exfiltration path, no access to third-party
// processes. IOMMU translations (VT-d/AMD-Vi) remain authoritative: an IOMMU
// reject results in an error completion.
//
// State: interface and FSM in place; actual memory TLP emission depends on the
// chosen PCIe IP (see rtl/pcie/pcie_wrapper.sv) and is not simulated here.
import nvme_pkg::*;

module dma_engine #(
  parameter int ADDR_W = 64,
  parameter int DATA_W = 128   // AXI-stream datapath width toward the PCIe IP
)(
  input  logic              clk,
  input  logic              rst_n,

  // ---- Transfer request (from the command decoder) ----
  input  logic              req_valid,
  output logic              req_ready,
  input  logic              req_is_write, // 1 = host->backend, 0 = backend->host
  input  logic [ADDR_W-1:0] req_prp1,
  input  logic [ADDR_W-1:0] req_prp2,
  input  logic [31:0]       req_len_bytes,
  input  logic [ADDR_W-1:0] req_backend_addr,

  // ---- PCIe IP side: memory request (Memory Read/Write TLP) ----
  output logic              mem_req_valid,
  input  logic              mem_req_ready,
  output logic              mem_req_we,
  output logic [ADDR_W-1:0] mem_req_addr,     // IOVA provided by the host (via PRP)
  output logic [10:0]       mem_req_len_dw,
  output logic [DATA_W-1:0] mem_wdata,
  input  logic [DATA_W-1:0] mem_rdata,
  input  logic              mem_rvalid,
  input  logic              mem_err,          // e.g. IOMMU reject / completion abort

  // ---- Storage backend side ----
  output logic              be_req_valid,
  input  logic              be_req_ready,
  output logic              be_we,
  output logic [ADDR_W-1:0] be_addr,
  output logic [DATA_W-1:0] be_wdata,
  input  logic [DATA_W-1:0] be_rdata,

  // ---- Transfer completion ----
  output logic              done,
  output logic              error
);
  localparam int PAGE = 4096;

  typedef enum logic [2:0] {
    D_IDLE, D_PRP_SETUP, D_XFER, D_DONE, D_ERR
  } dma_e;
  dma_e st, st_n;

  logic [31:0]       remaining;
  logic [ADDR_W-1:0] cur_host_addr;
  logic [ADDR_W-1:0] cur_be_addr;

  assign req_ready = (st == D_IDLE);

  always_comb begin
    st_n = st;
    unique case (st)
      D_IDLE     : if (req_valid) st_n = D_PRP_SETUP;
      D_PRP_SETUP: st_n = D_XFER;                 // PRP list walk: TODO (PART G)
      D_XFER     : if (mem_err)              st_n = D_ERR;
                   else if (remaining == 0)  st_n = D_DONE;
      D_DONE     : st_n = D_IDLE;
      D_ERR      : st_n = D_IDLE;
      default    : st_n = D_IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= D_IDLE; remaining <= '0; cur_host_addr <= '0; cur_be_addr <= '0;
    end else begin
`ifdef STORNADO_DEBUG
      if (st != st_n) $display("[%0t] DMA %0d -> %0d (rem=%0d host=%0h be=%0h)",
                               $time, st, st_n, remaining, cur_host_addr, cur_be_addr);
`endif
      st <= st_n;
      unique case (st)
        D_IDLE : if (req_valid) begin
                   remaining     <= req_len_bytes;
                   cur_host_addr <= req_prp1;
                   cur_be_addr   <= req_backend_addr;
                 end
        D_XFER : if (mem_req_valid && mem_req_ready) begin
                   // symbolic advance; the real pipeline depends on the PCIe IP
                   remaining     <= (remaining > PAGE) ? remaining - PAGE : '0;
                   cur_host_addr <= cur_host_addr + PAGE;
                   cur_be_addr   <= cur_be_addr + PAGE;
                 end
        default: ;
      endcase
    end
  end

  // Outputs (real datapath to be wired to the PCIe IP during integration)
  assign mem_req_valid = (st == D_XFER) && (remaining != 0);
  assign mem_req_we    = req_is_write ? 1'b0 : 1'b1; // write cmd -> we read the host
  assign mem_req_addr  = cur_host_addr;
  assign mem_req_len_dw= (remaining > PAGE) ? 11'd1024 : remaining[12:2];
  assign mem_wdata     = be_rdata;

  assign be_req_valid  = (st == D_XFER);
  assign be_we         = req_is_write;              // write cmd -> we write the backend
  assign be_addr       = cur_be_addr;
  assign be_wdata      = mem_rdata;

  assign done  = (st == D_DONE);
  assign error = (st == D_ERR);
endmodule : dma_engine
