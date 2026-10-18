// tb_cmd_decoder.sv - nvme_cmd_decoder classification testbench.
// Checks opcode routing (admin vs I/O), the unsupported-opcode flag, and field
// pass-through. The decoder is combinational, so we drive and settle with #1.
`timescale 1ns/1ps
import nvme_pkg::*;

module tb_cmd_decoder;
  logic clk = 0, rst_n = 1;
  logic        cmd_valid, cmd_ready, is_admin_queue;
  logic [31:0] cdw0, nsid, nlb_dw;
  logic [63:0] prp1, prp2, slba;
  logic        issue_valid, issue_ready, issue_is_admin, issue_unsupported;
  logic [7:0]  issue_opcode;
  logic [15:0] issue_cid, issue_nlb;
  logic [63:0] issue_prp1, issue_prp2, issue_slba;
  int errors = 0;

  nvme_cmd_decoder dut (
    .clk, .rst_n, .cmd_valid, .cmd_ready, .is_admin_queue,
    .cdw0, .nsid, .prp1, .prp2, .slba, .nlb_dw,
    .issue_valid, .issue_ready, .issue_opcode, .issue_is_admin, .issue_cid,
    .issue_prp1, .issue_prp2, .issue_slba, .issue_nlb, .issue_unsupported
  );

  always #5 clk = ~clk;

  task automatic chk(input logic admin, input logic [7:0] opc, input logic [15:0] cid,
                     input logic exp_unsupported);
    cmd_valid = 1; issue_ready = 1; is_admin_queue = admin;
    cdw0 = {cid, 8'h0, opc};          // [31:16]=CID, [7:0]=OPC
    slba = 64'hCAFE_0000_0000_0001; nlb_dw = 32'h0000_0007;
    prp1 = 64'h1000; prp2 = 64'h2000; nsid = 32'd1;
    #1;
    if (issue_opcode !== opc)        begin $display("FAIL opcode %0h", issue_opcode); errors++; end
    if (issue_cid !== cid)           begin $display("FAIL cid %0h", issue_cid); errors++; end
    if (issue_is_admin !== admin)    begin $display("FAIL admin flag"); errors++; end
    if (issue_nlb !== 16'd7)         begin $display("FAIL nlb %0d", issue_nlb); errors++; end
    if (issue_slba !== slba)         begin $display("FAIL slba"); errors++; end
    if (issue_unsupported !== exp_unsupported)
      begin $display("FAIL unsupported %0b exp %0b (opc %0h admin %0b)",
                     issue_unsupported, exp_unsupported, opc, admin); errors++; end
    @(posedge clk);
  endtask

  initial begin
    cmd_valid = 0; issue_ready = 0; is_admin_queue = 0;
    cdw0 = 0; nsid = 0; nlb_dw = 0; prp1 = 0; prp2 = 0; slba = 0;
    @(posedge clk);

    chk(1'b1, ADM_IDENTIFY,     16'h0101, 1'b0); // admin Identify -> supported
    chk(1'b1, ADM_SET_FEATURES, 16'h0102, 1'b0); // admin Set Features -> supported
    chk(1'b1, 8'h7F,            16'h0103, 1'b1); // admin unknown -> unsupported
    chk(1'b0, IO_READ,          16'h0201, 1'b0); // I/O Read -> supported
    chk(1'b0, IO_WRITE,         16'h0202, 1'b0); // I/O Write -> supported
    chk(1'b0, 8'h09,            16'h0203, 1'b1); // 0x09 is admin opcode, not I/O

    if (errors == 0) $display("TB_CMD_DECODER: PASS");
    else             $display("TB_CMD_DECODER: FAIL (%0d)", errors);
    $finish;
  end

  initial begin #20000; $display("TB_CMD_DECODER: TIMEOUT"); $finish; end
endmodule
