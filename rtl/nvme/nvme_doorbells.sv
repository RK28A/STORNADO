// nvme_doorbells.sv — Registres doorbell SQ/CQ (BAR0, base OFF_DBRANGE).
// Layout NVMe : pour la queue y, SQyTDBL à (0x1000 + 2y*(4<<DSTRD)),
// CQyHDBL à (0x1000 + (2y+1)*(4<<DSTRD)). DSTRD=0 -> stride 4 octets.
//
// Les pointeurs sont exposés en BUS PACKÉ (sq_tail_flat/cq_head_flat) plutôt
// qu'en tableau non-packé : plus portable (Icarus gère mal les ports tableaux).
// Accès queue q : flat[q*16 +: 16].
import nvme_pkg::*;

module nvme_doorbells #(
  parameter int NUM_QUEUES = 2  // 0 = Admin, 1 = première paire I/O
)(
  input  logic              clk,
  input  logic              rst_n,

  input  logic              db_sel,
  input  logic              db_we,
  input  logic [REG_AW-1:0] db_addr,
  input  logic [REG_DW-1:0] db_wdata,
  output logic [REG_DW-1:0] db_rdata,
  output logic              db_ack,

  // événement : une doorbell SQ a été sonnée (déclenche le fetch de commande)
  output logic                          sq_rung,
  output logic [$clog2(NUM_QUEUES)-1:0] sq_rung_qid,

  output logic [NUM_QUEUES*16-1:0] sq_tail_flat,
  output logic [NUM_QUEUES*16-1:0] cq_head_flat
);
  // index relatif = (addr - 0x1000) >> 2
  wire [REG_AW-1:0] rel   = db_addr - OFF_DBRANGE;
  wire [15:0]       idx   = rel[17:2];
  wire              is_cq = idx[0];          // impair = CQ head
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
    db_rdata = 32'h0; // doorbells write-only côté hôte ; relecture = 0
    db_ack   = db_sel;
  end
endmodule : nvme_doorbells
