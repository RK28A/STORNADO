// nvme_doorbells.sv - SQ/CQ doorbell registers (BAR0, base OFF_DBRANGE).
// NVMe layout: for queue y, SQyTDBL at (0x1000 + 2y*(4<<DSTRD)),
// CQyHDBL at (0x1000 + (2y+1)*(4<<DSTRD)). DSTRD=0 -> 4-byte stride.
//
// Pointers are exposed as a PACKED BUS (sq_tail_flat/cq_head_flat) rather than
// an unpacked array: more portable (Icarus handles array ports poorly).
// Access queue q: flat[q*16 +: 16].
import nvme_pkg::*;

module nvme_doorbells #(
  parameter int NUM_QUEUES = 2  // 0 = Admin, 1 = first I/O pair
)(
  input  logic              clk,
  input  logic              rst_n,

  input  logic              db_sel,
  input  logic              db_we,
  input  logic [REG_AW-1:0] db_addr,
  input  logic [REG_DW-1:0] db_wdata,
  output logic [REG_DW-1:0] db_rdata,
  output logic              db_ack,

  // event: an SQ doorbell was rung (triggers the command fetch)
  output logic                          sq_rung,
  output logic [$clog2(NUM_QUEUES)-1:0] sq_rung_qid,

  output logic [NUM_QUEUES*16-1:0] sq_tail_flat,
  output logic [NUM_QUEUES*16-1:0] cq_head_flat
);
  // relative index = (addr - 0x1000) >> 2
  wire [REG_AW-1:0] rel   = db_addr - OFF_DBRANGE;
  wire [15:0]       idx   = rel[17:2];
  wire              is_cq = idx[0];          // odd = CQ head
  wire [15:0]       qid   = idx >> 1;
  wire              in_range = db_sel && (qid < NUM_QUEUES);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sq_tail_flat <= '0;
      cq_head_flat <= '0;
      sq_rung <= 1'b0; sq_rung_qid <= '0;
    end else begin
      sq_rung <= 1'b0;
      if (in_range && db_we) begin
        if (is_cq) cq_head_flat[qid*16 +: 16] <= db_wdata[15:0];
        else begin
          sq_tail_flat[qid*16 +: 16] <= db_wdata[15:0];
          sq_rung      <= 1'b1;
          sq_rung_qid  <= qid[$clog2(NUM_QUEUES)-1:0];
`ifdef STORNADO_DEBUG
          $display("[%0t] DOORBELL SQ%0d tail<=%0d", $time, qid, db_wdata[15:0]);
`endif
        end
      end
    end
  end

  always_comb begin
    db_rdata = 32'h0; // doorbells are write-only on the host side; readback = 0
    db_ack   = db_sel;
  end
endmodule : nvme_doorbells
