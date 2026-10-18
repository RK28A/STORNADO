// nvme_queue_mgr.sv - SQ/CQ pointer tracking and completion generation.
// Keeps head/tail per queue, computes "SQ non-empty", handles the CQ phase tag
// and prepares CQEs. Actually reading SQEs and writing CQEs to host memory goes
// through the DMA engine (this module does not touch host RAM).
//
// Pointers as a PACKED BUS (Icarus portability). Access queue q: flat[q*16 +: 16].
import nvme_pkg::*;

module nvme_queue_mgr #(
  parameter int NUM_QUEUES = 2
)(
  input  logic              clk,
  input  logic              rst_n,

  // pointers coming from the doorbells
  input  logic [NUM_QUEUES*16-1:0] sq_tail_flat,
  input  logic [NUM_QUEUES*16-1:0] cq_head_flat,
  input  logic [11:0]              sq_size,

  // SQ head maintained locally (advances when an SQE is consumed)
  output logic [NUM_QUEUES*16-1:0] sq_head_flat,
  output logic [NUM_QUEUES-1:0]    sq_nonempty,
  input  logic                     sq_pop,
  input  logic [$clog2(NUM_QUEUES)-1:0] sq_pop_qid,

  // completions to write
  input  logic                     cpl_push,
  input  logic [$clog2(NUM_QUEUES)-1:0] cpl_qid,
  input  logic [15:0]              cpl_cid,
  input  logic [14:0]              cpl_status,
  output logic [NUM_QUEUES*16-1:0] cq_tail_flat,
  output logic [NUM_QUEUES-1:0]    cq_phase,
  output cqe_t                     cpl_entry,
  output logic                     cpl_wr_req
);
  // "non-empty" per queue (tail != head on each slice)
  genvar g;
  generate
    for (g = 0; g < NUM_QUEUES; g++) begin : gq
      assign sq_nonempty[g] =
        (sq_tail_flat[g*16 +: 16] != sq_head_flat[g*16 +: 16]);
    end
  endgenerate

  wire [15:0] sq_head_pop = sq_head_flat[sq_pop_qid*16 +: 16];
  wire [15:0] cq_tail_cur = cq_tail_flat[cpl_qid*16 +: 16];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sq_head_flat <= '0;
      cq_tail_flat <= '0;
      cq_phase     <= '1;        // initial phase = 1
      cpl_wr_req   <= 1'b0;
      cpl_entry    <= '0;
    end else begin
      cpl_wr_req <= 1'b0;

      if (sq_pop) begin
        sq_head_flat[sq_pop_qid*16 +: 16] <=
          (sq_head_pop + 16'd1 >= sq_size) ? 16'd0 : sq_head_pop + 16'd1;
      end

      if (cpl_push) begin
        cpl_entry.cdw0 <= 32'h0;
        cpl_entry.cdw1 <= 32'h0;
        cpl_entry.cdw2 <= {sq_head_flat[cpl_qid*16 +: 16], 16'h0};
        cpl_entry.cdw3 <= {cpl_status, cq_phase[cpl_qid], cpl_cid};
        cpl_wr_req     <= 1'b1;
        cq_tail_flat[cpl_qid*16 +: 16] <= cq_tail_cur + 16'd1;
        if (cq_tail_cur + 16'd1 == 16'd0) cq_phase[cpl_qid] <= ~cq_phase[cpl_qid];
`ifdef STORNADO_DEBUG
        $display("[%0t] CQ%0d push cid=%0d status=%0h phase=%0b",
                 $time, cpl_qid, cpl_cid, cpl_status, cq_phase[cpl_qid]);
`endif
      end
    end
  end
endmodule : nvme_queue_mgr
