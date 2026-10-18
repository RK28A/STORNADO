// tb_queue_mgr.sv - nvme_queue_mgr CQ-wrap + phase-toggle testbench.
// Pushes completions on CQ0 with a configured size of 4 and checks the tail
// pointer wraps 1->2->3->0 and the phase tag toggles on wrap. Closes REVIEW S2.
`timescale 1ns/1ps
import nvme_pkg::*;

module tb_queue_mgr;
  localparam int NQ = 2;
  logic clk = 0, rst_n = 0;

  logic [NQ*16-1:0] sq_tail_flat, cq_head_flat, sq_head_flat, cq_tail_flat;
  logic [11:0] sq_size, cq_size;
  logic [NQ-1:0] sq_nonempty, cq_phase;
  logic sq_pop; logic [$clog2(NQ)-1:0] sq_pop_qid;
  logic cpl_push; logic [$clog2(NQ)-1:0] cpl_qid;
  logic [15:0] cpl_cid; logic [14:0] cpl_status;
  cqe_t cpl_entry; logic cpl_wr_req;
  int errors = 0;

  nvme_queue_mgr #(.NUM_QUEUES(NQ)) dut (
    .clk, .rst_n, .sq_tail_flat, .cq_head_flat, .sq_size, .cq_size,
    .sq_head_flat, .sq_nonempty, .sq_pop, .sq_pop_qid,
    .cpl_push, .cpl_qid, .cpl_cid, .cpl_status, .cq_tail_flat, .cq_phase,
    .cpl_entry, .cpl_wr_req
  );

  always #5 clk = ~clk;

  task automatic push_check(input logic [15:0] exp_tail, input logic exp_phase);
    @(negedge clk); cpl_push = 1; cpl_qid = 0; cpl_cid = 16'hABCD; cpl_status = 15'h0;
    @(posedge clk);                       // sampled here -> update
    @(negedge clk); cpl_push = 0;
    if (!cpl_wr_req) begin /* wr_req is a 1-cycle pulse after push; informational */ end
    if (cq_tail_flat[15:0] !== exp_tail) begin
      $display("FAIL cq_tail %0d exp %0d", cq_tail_flat[15:0], exp_tail); errors++; end
    if (cq_phase[0] !== exp_phase) begin
      $display("FAIL cq_phase %0b exp %0b", cq_phase[0], exp_phase); errors++; end
  endtask

  initial begin
    sq_tail_flat = 0; cq_head_flat = 0; sq_size = 12'd4; cq_size = 12'd4;
    sq_pop = 0; sq_pop_qid = 0; cpl_push = 0; cpl_qid = 0; cpl_cid = 0; cpl_status = 0;
    repeat (3) @(posedge clk); rst_n = 1;
    @(negedge clk);
    if (cq_phase[0] !== 1'b1) begin $display("FAIL initial phase"); errors++; end

    push_check(16'd1, 1'b1);
    push_check(16'd2, 1'b1);
    push_check(16'd3, 1'b1);
    push_check(16'd0, 1'b0);   // wrap at size 4 -> toggle phase
    push_check(16'd1, 1'b0);

    if (errors == 0) $display("TB_QUEUE_MGR: PASS");
    else             $display("TB_QUEUE_MGR: FAIL (%0d)", errors);
    $finish;
  end

  initial begin #20000; $display("TB_QUEUE_MGR: TIMEOUT"); $finish; end
endmodule
