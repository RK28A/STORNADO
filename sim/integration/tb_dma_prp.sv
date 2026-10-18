// tb_dma_prp.sv - Proves the dma_engine PRP walk (Icarus/Verilator).
// Scenario: a READ command spanning 3 pages with a byte offset in PRP1 and a
// PRP list in PRP2. A host-memory model answers the PRP-list reads. The TB
// records the sequence of data-page host addresses requested and checks it.
//
// Page = 4096. PRP1 = 0x1_0000_0200 (offset 0x200) -> first page = 3584 bytes.
// Remaining after page 0 = 4196 > 4096 -> PRP2 is a list.
//   list[0] @ 0x2_0000_0000 = 0x3_0000_0000
//   list[1] @ 0x2_0000_0008 = 0x4_0000_0000
// Expected data pages: 0x1_0000_0200, 0x3_0000_0000, 0x4_0000_0000.
`timescale 1ns/1ps
import nvme_pkg::*;

module tb_dma_prp;
  localparam int ADDR_W = 64, DATA_W = 128;
  logic clk = 0, rst_n = 0;

  logic              req_valid, req_ready, req_is_write;
  logic [ADDR_W-1:0] req_prp1, req_prp2, req_backend_addr;
  logic [31:0]       req_len_bytes;

  logic              mem_req_valid, mem_req_ready, mem_req_we;
  logic [ADDR_W-1:0] mem_req_addr;
  logic [12:0]       mem_req_len_bytes;
  logic [DATA_W-1:0] mem_rdata;
  logic              mem_rvalid, mem_err;

  logic              be_req_valid, be_req_ready, be_we;
  logic [ADDR_W-1:0] be_addr;
  logic [12:0]       be_len_bytes;
  logic              done, error;

  int errors = 0;

  dma_engine #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) dut (
    .clk, .rst_n,
    .req_valid, .req_ready, .req_is_write,
    .req_prp1, .req_prp2, .req_len_bytes, .req_backend_addr,
    .mem_req_valid, .mem_req_ready, .mem_req_we, .mem_req_addr,
    .mem_req_len_bytes, .mem_rdata, .mem_rvalid, .mem_err,
    .be_req_valid, .be_req_ready, .be_we, .be_addr, .be_len_bytes,
    .done, .error
  );

  always #5 clk = ~clk;

  assign mem_req_ready = 1'b1;
  assign be_req_ready  = 1'b1;
  assign mem_err       = 1'b0;

  // Host-memory model: answer PRP-list reads (mem_req_we==0) one cycle later.
  function automatic logic [63:0] list_entry(input logic [63:0] a);
    case (a)
      64'h2_0000_0000: list_entry = 64'h3_0000_0000;
      64'h2_0000_0008: list_entry = 64'h4_0000_0000;
      default:         list_entry = 64'hDEAD_DEAD_DEAD_DEAD;
    endcase
  endfunction

  always_ff @(posedge clk) begin
    mem_rvalid <= 1'b0;
    if (rst_n && mem_req_valid && !mem_req_we) begin
      mem_rdata  <= {64'h0, list_entry(mem_req_addr)};
      mem_rvalid <= 1'b1;
    end
  end

  // Record data-page requests on the rising edge of (mem_req_valid & mem_req_we).
  logic [ADDR_W-1:0] seen [0:7];
  int n = 0;
  logic prev_page_req = 0;
  always_ff @(posedge clk) begin
    if (rst_n) begin
      if (mem_req_valid && mem_req_we && !prev_page_req && n < 8) begin
        seen[n] <= mem_req_addr; n <= n + 1;
      end
      prev_page_req <= (mem_req_valid && mem_req_we);
    end
  end

  int guard;
  initial begin
    req_valid = 0; req_is_write = 0; req_prp1 = 0; req_prp2 = 0;
    req_len_bytes = 0; req_backend_addr = 0; mem_rvalid = 0; mem_rdata = 0;
    repeat (3) @(posedge clk); rst_n = 1;

    @(posedge clk);
    req_is_write     = 0;                       // READ command (device writes host)
    req_prp1         = 64'h1_0000_0200;
    req_prp2         = 64'h2_0000_0000;         // PRP list pointer
    req_len_bytes    = 3584 + 4096 + 100;       // 7780 -> 3 pages
    req_backend_addr = 64'h0;
    req_valid = 1;
    @(posedge clk);
    while (!req_ready) @(posedge clk);          // (ready this cycle; defensive)
    req_valid = 0;

    guard = 0;
    while (!done && !error && guard < 500) begin @(posedge clk); guard++; end
    if (error) begin $display("FAIL: DMA error"); errors++; end
    if (!done)  begin $display("FAIL: DMA never completed"); errors++; end

    if (n !== 3) begin $display("FAIL: %0d data pages (exp 3)", n); errors++; end
    if (seen[0] !== 64'h1_0000_0200) begin $display("FAIL page0 %0h", seen[0]); errors++; end
    if (seen[1] !== 64'h3_0000_0000) begin $display("FAIL page1 %0h", seen[1]); errors++; end
    if (seen[2] !== 64'h4_0000_0000) begin $display("FAIL page2 %0h", seen[2]); errors++; end

    if (errors == 0) $display("TB_DMA_PRP: PASS");
    else             $display("TB_DMA_PRP: FAIL (%0d)", errors);
    $finish;
  end

  initial begin #100000; $display("TB_DMA_PRP: TIMEOUT"); $finish; end
endmodule
