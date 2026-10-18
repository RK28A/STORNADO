// tb_nvme_regs.sv - Checks CAP/VS reads and the CC.EN -> CSTS.RDY sequence.
// Reproduces the start of NVMe controller init (section 3.1.5).
// Portable constructs only (no break/fork).
`timescale 1ns/1ps
import nvme_pkg::*;

module tb_nvme_regs;
  logic clk = 0, rst_n = 0;
  logic reg_sel, reg_we;
  logic [REG_AW-1:0] reg_addr;
  logic [REG_DW-1:0] reg_wdata, reg_rdata;
  logic [3:0] reg_wstrb;
  logic reg_ack;
  logic [63:0] asq_base, acq_base;
  logic [11:0] asq_size, acq_size;
  logic ctrl_enabled, ctrl_ready;
  int errors = 0;

  nvme_regs dut (
    .clk, .rst_n, .reg_sel, .reg_we, .reg_addr, .reg_wdata, .reg_wstrb,
    .reg_rdata, .reg_ack, .asq_base, .acq_base, .asq_size, .acq_size,
    .ctrl_enabled, .ctrl_ready, .fatal_error(1'b0)
  );

  always #5 clk = ~clk;

  task automatic rd(input logic [REG_AW-1:0] a, output logic [31:0] d);
    @(posedge clk); reg_sel = 1; reg_we = 0; reg_addr = a;
    @(posedge clk); d = reg_rdata; reg_sel = 0;
  endtask
  task automatic wr(input logic [REG_AW-1:0] a, input logic [31:0] d);
    @(posedge clk); reg_sel = 1; reg_we = 1; reg_addr = a; reg_wdata = d; reg_wstrb = 4'hF;
    @(posedge clk); reg_sel = 0; reg_we = 0;
  endtask

  logic [31:0] v;
  int guard;
  initial begin
    reg_sel = 0; reg_we = 0; reg_wstrb = 0; reg_addr = 0; reg_wdata = 0;
    repeat (3) @(posedge clk); rst_n = 1;

    rd(OFF_VS, v);
    if (v !== VS_VALUE) begin $display("FAIL VS: %08h", v); errors++; end

    rd(OFF_CSTS, v);
    if (v[0] !== 1'b0) begin $display("FAIL RDY should be 0 before EN"); errors++; end

    wr(OFF_AQA, 32'h001F_001F);          // 32 admin entries
    wr(OFF_ASQ0, 32'h0010_0000);
    wr(OFF_ACQ0, 32'h0020_0000);
    wr(OFF_CC, 32'h0046_0001);           // EN=1

    // wait for RDY (bounded polling)
    v = 0; guard = 0;
    while (v[0] !== 1'b1 && guard < 50) begin rd(OFF_CSTS, v); guard++; end
    if (v[0] !== 1'b1) begin $display("FAIL CSTS.RDY never reached"); errors++; end
    if (asq_size !== 12'd32) begin $display("FAIL ASQS: %0d", asq_size); errors++; end

    // clear EN -> RDY drops
    wr(OFF_CC, 32'h0046_0000);
    repeat (10) @(posedge clk);
    rd(OFF_CSTS, v);
    if (v[0] !== 1'b0) begin $display("FAIL RDY should drop"); errors++; end

    if (errors == 0) $display("TB_NVME_REGS: PASS");
    else             $display("TB_NVME_REGS: FAIL (%0d)", errors);
    $finish;
  end

  initial begin #50000; $display("TB_NVME_REGS: TIMEOUT"); $finish; end
endmodule
