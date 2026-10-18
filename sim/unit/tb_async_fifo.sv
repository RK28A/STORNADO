// tb_async_fifo.sv - Dual-clock async_fifo testbench (Icarus/Verilator).
// Write domain faster than read domain; checks data integrity and ordering
// across the CDC. Portable constructs only.
`timescale 1ns/1ps
module tb_async_fifo;
  localparam int W = 16, D = 8, N = 32;
  logic wr_clk = 0, rd_clk = 0, wr_rst_n = 0, rd_rst_n = 0;
  logic wr_valid, wr_ready, rd_valid, rd_ready;
  logic [W-1:0] wr_data, rd_data;
  int errors = 0;

  async_fifo #(.WIDTH(W), .DEPTH(D)) dut (
    .wr_clk, .wr_rst_n, .wr_valid, .wr_ready, .wr_data,
    .rd_clk, .rd_rst_n, .rd_valid, .rd_ready, .rd_data
  );

  always #5  wr_clk = ~wr_clk;   // 100 MHz
  always #17 rd_clk = ~rd_clk;   // ~29 MHz (asynchronous ratio)

  // producer
  initial begin
    wr_valid = 0; wr_data = 0;
    repeat (3) @(posedge wr_clk); wr_rst_n = 1;
    for (int i = 0; i < N; i++) begin
      wr_data = i[W-1:0]; wr_valid = 1;
      @(posedge wr_clk);
      while (!wr_ready) @(posedge wr_clk);
      wr_valid = 0;
      @(posedge wr_clk);
    end
  end

  // consumer + checker
  logic [W-1:0] got;
  initial begin
    rd_ready = 0;
    repeat (3) @(posedge rd_clk); rd_rst_n = 1;
    for (int i = 0; i < N; i++) begin
      rd_ready = 1;
      @(posedge rd_clk);
      while (!rd_valid) @(posedge rd_clk);
      got = rd_data;
      if (got !== i[W-1:0]) begin
        $display("FAIL order @%0d: got %0d", i, got); errors++;
      end
      rd_ready = 0;
      @(posedge rd_clk);
    end
    if (errors == 0) $display("TB_ASYNC_FIFO: PASS");
    else             $display("TB_ASYNC_FIFO: FAIL (%0d)", errors);
    $finish;
  end

  initial begin #200000; $display("TB_ASYNC_FIFO: TIMEOUT"); $finish; end
endmodule
