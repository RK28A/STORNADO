// tb_storage_backend.sv - storage_backend_ram testbench (Icarus/Verilator).
// Checks write-then-read on LBA0, a middle address and the last word, plus the
// out-of-bounds flag. Uses a small capacity so the sim stays light.
`timescale 1ns/1ps
module tb_storage_backend;
  localparam int ADDR_W = 64, DATA_W = 128, CAP = 4096; // 256 words
  logic clk = 0, rst_n = 0;
  logic req_valid, req_ready, we, rvalid, oob;
  logic [ADDR_W-1:0] addr;
  logic [DATA_W-1:0] wdata, rdata;
  int errors = 0;

  storage_backend_ram #(.ADDR_W(ADDR_W), .DATA_W(DATA_W), .CAP_BYTES(CAP)) dut (
    .clk, .rst_n, .req_valid, .req_ready, .we, .addr, .wdata, .rdata, .rvalid,
    .oob_error(oob)
  );

  always #5 clk = ~clk;

  task automatic wr(input logic [ADDR_W-1:0] a, input logic [DATA_W-1:0] d);
    @(posedge clk); req_valid = 1; we = 1; addr = a; wdata = d;
    @(posedge clk); req_valid = 0; we = 0;
  endtask

  task automatic rd(input logic [ADDR_W-1:0] a, output logic [DATA_W-1:0] d);
    @(posedge clk); req_valid = 1; we = 0; addr = a;
    @(posedge clk); req_valid = 0;
    @(posedge clk); d = rdata;           // rdata registered one cycle after req
  endtask

  logic [DATA_W-1:0] v;
  initial begin
    req_valid = 0; we = 0; addr = 0; wdata = 0;
    repeat (3) @(posedge clk); rst_n = 1;

    // LBA0, middle, last word (CAP-16)
    wr(64'h0,    128'hDEAD_BEEF_0000_0000_0000_0000_0000_0001);
    wr(64'h800,  128'h1122_3344_5566_7788_99AA_BBCC_DDEE_FF00);
    wr(CAP-16,   128'hCAFE_0000_0000_0000_0000_0000_0000_00FF);

    rd(64'h0, v);
    if (v[7:0] !== 8'h01) begin $display("FAIL rd LBA0: %032h", v); errors++; end
    rd(64'h800, v);
    if (v !== 128'h1122_3344_5566_7788_99AA_BBCC_DDEE_FF00) begin $display("FAIL rd mid"); errors++; end
    rd(CAP-16, v);
    if (v[7:0] !== 8'hFF) begin $display("FAIL rd last"); errors++; end

    // out of bounds
    @(posedge clk); req_valid = 1; we = 0; addr = CAP + 64'h100;
    @(posedge clk); req_valid = 0;
    @(posedge clk);
    if (!oob) begin $display("FAIL oob not flagged"); errors++; end

    if (errors == 0) $display("TB_STORAGE_BACKEND: PASS");
    else             $display("TB_STORAGE_BACKEND: FAIL (%0d)", errors);
    $finish;
  end

  initial begin #20000; $display("TB_STORAGE_BACKEND: TIMEOUT"); $finish; end
endmodule
