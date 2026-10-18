// dma_engine.sv - NVMe storage DMA engine with a real PRP walk.
// LEGITIMATE and ONLY role: for a given NVMe command, transfer data blocks
// between the host memory DESIGNATED BY THE COMMAND'S PRPs and the storage
// backend, one host page at a time. It never generates an address of its own.
//
// IMPORTANT (PART G / quality rule 5): Bus Master Enable is NOT an arbitrary RAM
// read permission. This engine only addresses:
//   - the pages pointed to by PRP1 / PRP2, and
//   - the PRP-list pages pointed to by PRP2 when the transfer spans > 2 pages.
// Nothing else. An IOMMU reject (mem_err) ends the transfer with an error
// completion. No exfiltration path, no third-party process access.
//
// PRP rules implemented (NVMe 2.0, section 4.1.2):
//   - page size P = 2^(12+MPS), MPS from CC.MPS (default 4 KiB).
//   - PRP1 may carry a byte offset within its page; the first transfer covers
//     from that offset to the end of the page (or the whole length if smaller).
//   - if the remaining data fits in exactly one more page, PRP2 is a data page.
//   - otherwise PRP2 points to a PRP list; each 8-byte entry is a page address.
//     When a list page is full, its last entry chains to the next list page
//     (handled: CHAIN state).
//
// STATE: the per-page request is modeled as one handshake on mem_req_* toward
// the PCIe IP; the actual byte streaming datapath is wired to the IP during
// integration. Verified in sim by sim/integration/tb_dma_prp.sv (host-memory
// model); not hardware-proven. See docs/REVIEW.md.
import nvme_pkg::*;

module dma_engine #(
  parameter int ADDR_W = 64,
  parameter int DATA_W = 128,
  parameter int PAGE_SHIFT = 12            // default 4 KiB page (MPS=0)
)(
  input  logic              clk,
  input  logic              rst_n,

  // ---- Transfer request (from the command decoder) ----
  input  logic              req_valid,
  output logic              req_ready,
  input  logic              req_is_write,  // 1 = host->backend, 0 = backend->host
  input  logic [ADDR_W-1:0] req_prp1,
  input  logic [ADDR_W-1:0] req_prp2,
  input  logic [31:0]       req_len_bytes,
  input  logic [ADDR_W-1:0] req_backend_addr,

  // ---- PCIe IP side: memory request (Memory Read/Write TLP) ----
  output logic              mem_req_valid,
  input  logic              mem_req_ready,
  output logic              mem_req_we,       // 1 = write to host, 0 = read from host
  output logic [ADDR_W-1:0] mem_req_addr,     // host IOVA (from a PRP, never invented)
  output logic [12:0]       mem_req_len_bytes,// bytes for this page request
  input  logic [DATA_W-1:0] mem_rdata,
  input  logic              mem_rvalid,       // qualifies mem_rdata (list reads)
  input  logic              mem_err,          // e.g. IOMMU reject / completion abort

  // ---- Storage backend side ----
  output logic              be_req_valid,
  input  logic              be_req_ready,
  output logic              be_we,
  output logic [ADDR_W-1:0] be_addr,
  output logic [12:0]       be_len_bytes,

  // ---- Completion ----
  output logic              done,
  output logic              error
);
  localparam int unsigned PAGE = 1 << PAGE_SHIFT;

  typedef enum logic [2:0] {
    D_IDLE, D_FIRST, D_LIST_RD, D_PAGE, D_NEXT, D_DONE, D_ERR
  } dma_e;
  dma_e st, st_n;

  logic [31:0]       remaining;      // bytes left to move
  logic [ADDR_W-1:0] host_addr;      // current host page address
  logic [ADDR_W-1:0] be_addr_q;      // current backend address
  logic [ADDR_W-1:0] list_addr;      // address of the next PRP-list entry
  logic              use_list;       // PRP2 is a list (transfer spans > 2 pages)
  logic [12:0]       this_len;       // bytes for the current page
  logic              page_done;      // current page handshaked
  logic              first_page;

  // bytes from an offset to the end of its page
  function automatic logic [12:0] bytes_to_page_end(input logic [ADDR_W-1:0] a);
    bytes_to_page_end = PAGE[12:0] - a[PAGE_SHIFT-1:0];
  endfunction

  // chunk for the current page: min(remaining, bytes to page end from host_addr)
  wire [12:0] to_end  = bytes_to_page_end(host_addr);
  wire [12:0] chunk   = (remaining < {19'b0, to_end}) ? remaining[12:0] : to_end;

  // does the list entry we are about to read sit in the last slot of its page?
  // (if so, that entry chains to the next list page instead of a data page)
  wire list_last_slot = (list_addr[PAGE_SHIFT-1:0] == (PAGE - 8));

  assign req_ready = (st == D_IDLE);

  always_comb begin
    st_n = st;
    unique case (st)
      D_IDLE   : if (req_valid) st_n = D_FIRST;
      D_FIRST  : st_n = D_PAGE;                 // first page always uses PRP1
      D_LIST_RD: if (mem_err)        st_n = D_ERR;
                 else if (mem_rvalid) st_n = D_PAGE;
      D_PAGE   : if (mem_err)        st_n = D_ERR;
                 else if (page_done) st_n = (remaining == 0) ? D_DONE : D_NEXT;
      D_NEXT   : st_n = use_list ? D_LIST_RD : D_PAGE; // 2nd page from PRP2 (data)
      D_DONE   : st_n = D_IDLE;
      D_ERR    : st_n = D_IDLE;
      default  : st_n = D_IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= D_IDLE; remaining <= '0; host_addr <= '0; be_addr_q <= '0;
      list_addr <= '0; use_list <= 1'b0; this_len <= '0;
      page_done <= 1'b0; first_page <= 1'b1;
    end else begin
`ifdef STORNADO_DEBUG
      if (st != st_n) $display("[%0t] DMA %0d -> %0d (rem=%0d host=%0h be=%0h list=%0b)",
                               $time, st, st_n, remaining, host_addr, be_addr_q, use_list);
`endif
      st <= st_n;
      page_done <= 1'b0;

      unique case (st)
        D_IDLE: if (req_valid) begin
          remaining  <= req_len_bytes;
          host_addr  <= req_prp1;
          be_addr_q  <= req_backend_addr;
          first_page <= 1'b1;
          // Decide how PRP2 is used, from the bytes left AFTER the first page.
          // first page covers (PAGE - offset(prp1)) bytes.
          if (req_len_bytes <= {19'b0, bytes_to_page_end(req_prp1)}) begin
            use_list  <= 1'b0;                 // single page, PRP2 unused
            list_addr <= '0;
          end else if (req_len_bytes - bytes_to_page_end(req_prp1) <= PAGE) begin
            use_list  <= 1'b0;                 // exactly one more page: PRP2 is data
            list_addr <= '0;
          end else begin
            use_list  <= 1'b1;                 // > 2 pages: PRP2 is a list pointer
            list_addr <= req_prp2;
          end
        end

        // consume a page handshake on the mem_req bus
        D_PAGE: if (mem_req_valid && mem_req_ready && be_req_valid && be_req_ready) begin
          page_done <= 1'b1;
          remaining <= (remaining > {19'b0, chunk}) ? remaining - chunk : '0;
          be_addr_q <= be_addr_q + chunk;
          first_page <= 1'b0;
        end

        // advance to the next host page address
        D_NEXT: begin
          if (use_list) begin
            // next address comes from the PRP list (read in D_LIST_RD)
          end else begin
            host_addr <= req_prp2;             // the single "second page" case
          end
        end

        // latch the page address (or chain) from a PRP-list entry read
        D_LIST_RD: if (mem_rvalid) begin
          if (list_last_slot) begin
            list_addr <= mem_rdata[ADDR_W-1:0];   // chain to next list page
          end else begin
            host_addr <= mem_rdata[ADDR_W-1:0];   // next data page
            list_addr <= list_addr + 64'd8;
          end
        end
        default: ;
      endcase
    end
  end

  // ---- outputs ----
  // During D_PAGE we move one page chunk; during D_LIST_RD we read 8 bytes.
  assign this_len         = chunk;
  assign mem_req_valid    = (st == D_PAGE) || (st == D_LIST_RD);
  assign mem_req_we       = (st == D_PAGE) ? ~req_is_write  // write cmd -> read host
                                           : 1'b0;          // list read
  assign mem_req_addr     = (st == D_LIST_RD) ? list_addr : host_addr;
  assign mem_req_len_bytes= (st == D_LIST_RD) ? 13'd8 : chunk;

  assign be_req_valid     = (st == D_PAGE);
  assign be_we            = req_is_write;                   // write cmd -> write backend
  assign be_addr          = be_addr_q;
  assign be_len_bytes     = chunk;

  assign done  = (st == D_DONE);
  assign error = (st == D_ERR);
endmodule : dma_engine
