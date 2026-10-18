// tb_init_sequence.sv — Intégration légère : registres + doorbells câblés.
// Sonne la doorbell SQ admin après init et vérifie le pointeur sq_tail.
// Ne couvre PAS le fetch DMA réel (dépend de l'IP PCIe) : cf. docs/test-plan.md.
// Bus de pointeurs packés (sq_tail_flat/cq_head_flat).
`timescale 1ns/1ps
import nvme_pkg::*;

module tb_init_sequence;
  localparam int NQ = 2;
  logic clk = 0, rst_n = 0;

  logic sel, we;
  logic [REG_AW-1:0] addr;
  logic [REG_DW-1:0] wdata, rdata, reg_rd, db_rd;
  logic [3:0] wstrb;
  logic reg_ack, db_ack;
  int errors = 0;

  wire sel_db  = sel && (addr >= OFF_DBRANGE);
  wire sel_reg = sel && (addr <  OFF_DBRANGE);
  assign rdata = sel_db ? db_rd : reg_rd;

  logic [63:0] asq_base, acq_base; logic [11:0] asq_size, acq_size;
  logic ctrl_enabled, ctrl_ready;

  logic sq_rung; logic [$clog2(NQ)-1:0] sq_rung_qid;
  logic [NQ*16-1:0] sq_tail_flat, cq_head_flat;

  nvme_regs u_regs (
    .clk, .rst_n, .reg_sel(sel_reg), .reg_we(we), .reg_addr(addr),
    .reg_wdata(wdata), .reg_wstrb(wstrb), .reg_rdata(reg_rd), .reg_ack(reg_ack),
    .asq_base, .acq_base, .asq_size, .acq_size,
    .ctrl_enabled, .ctrl_ready, .fatal_error(1'b0)
  );
  nvme_doorbells #(.NUM_QUEUES(NQ)) u_db (
    .clk, .rst_n, .db_sel(sel_db), .db_we(we), .db_addr(addr),
    .db_wdata(wdata), .db_rdata(db_rd), .db_ack(db_ack),
    .sq_rung, .sq_rung_qid, .sq_tail_flat, .cq_head_flat
  );

  always #5 clk = ~clk;
  task automatic wr(input logic [REG_AW-1:0] a, input logic [31:0] d);
    @(posedge clk); sel=1; we=1; addr=a; wdata=d; wstrb=4'hF;
    @(posedge clk); sel=0; we=0;
  endtask

  initial begin
    sel=0; we=0; wstrb=0; addr=0; wdata=0;
    repeat(3) @(posedge clk); rst_n=1;
    wr(OFF_AQA, 32'h001F_001F);
    wr(OFF_CC, 32'h0046_0001);
    repeat(20) @(posedge clk);
    if (!ctrl_ready) begin $display("FAIL ctrl pas pret"); errors++; end

    // sonne SQ0 tail = 1
    wr(OFF_DBRANGE, 32'h0000_0001);
    @(posedge clk);
    if (sq_tail_flat[15:0] !== 16'd1) begin $display("FAIL sq_tail: %0d", sq_tail_flat[15:0]); errors++; end
    if (!sq_rung) begin $display("NOTE: sq_rung impulsion deja retombee (ok si 1 cycle)"); end

    if (errors==0) $display("TB_INIT_SEQUENCE: PASS");
    else            $display("TB_INIT_SEQUENCE: FAIL (%0d)", errors);
    $finish;
  end
  initial begin #50000; $display("TB_INIT_SEQUENCE: TIMEOUT"); $finish; end
endmodule
