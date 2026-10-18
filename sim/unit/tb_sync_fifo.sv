// tb_sync_fifo.sv — Testbench unitaire sync_fifo (Icarus/Verilator).
`timescale 1ns/1ps
module tb_sync_fifo;
  localparam int W = 8, D = 4;
  logic clk = 0, rst_n = 0;
  logic wr_valid, wr_ready, rd_valid, rd_ready;
  logic [W-1:0] wr_data, rd_data;
  logic [$clog2(D):0] count;
  int errors = 0;

  sync_fifo #(.WIDTH(W), .DEPTH(D)) dut (.*);

  always #5 clk = ~clk;

  task automatic push(input logic [W-1:0] d);
    wr_data = d; wr_valid = 1;
    do @(posedge clk); while (!wr_ready);
    wr_valid = 0;
  endtask

  task automatic pop(output logic [W-1:0] d);
    rd_ready = 1;
    do @(posedge clk); while (!rd_valid);
    d = rd_data; @(posedge clk); rd_ready = 0;
  endtask

  logic [W-1:0] got;
  initial begin
    wr_valid = 0; rd_ready = 0; wr_data = 0;
    repeat (3) @(posedge clk); rst_n = 1;

    for (int i = 0; i < D; i++) push(i + 8'hA0);
    if (wr_ready) begin $error("FIFO devrait etre plein"); errors++; end

    for (int i = 0; i < D; i++) begin
      pop(got);
      if (got !== (i + 8'hA0)) begin $error("ordre FIFO KO: %0h", got); errors++; end
    end

    if (errors == 0) $display("TB_SYNC_FIFO: PASS");
    else             $display("TB_SYNC_FIFO: FAIL (%0d)", errors);
    $finish;
  end

  initial begin #10000; $display("TB_SYNC_FIFO: TIMEOUT"); $finish; end
endmodule
