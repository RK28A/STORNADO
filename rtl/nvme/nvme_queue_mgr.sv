// nvme_queue_mgr.sv — Suivi des pointeurs SQ/CQ et génération des complétions.
// Maintient head/tail par queue, calcule "SQ non vide", gère le phase tag de
// la CQ et pousse les CQE. La lecture effective des SQE et l'écriture des CQE
// en mémoire hôte passent par le moteur DMA (ce module ne touche pas la RAM).
import nvme_pkg::*;

module nvme_queue_mgr #(
  parameter int NUM_QUEUES = 2
)(
  input  logic              clk,
  input  logic              rst_n,

  // pointeurs issus des doorbells
  input  logic [15:0]       sq_tail [NUM_QUEUES],
  input  logic [15:0]       cq_head [NUM_QUEUES],
  input  logic [11:0]       sq_size,   // taille queue admin (démo : 1 taille)

  // tête SQ maintenue localement (avance quand une SQE est consommée)
  output logic [15:0]       sq_head [NUM_QUEUES],
  output logic              sq_nonempty [NUM_QUEUES],
  input  logic              sq_pop,      // le fetch a consommé une SQE
  input  logic [$clog2(NUM_QUEUES)-1:0] sq_pop_qid,

  // complétions à écrire
  input  logic              cpl_push,
  input  logic [$clog2(NUM_QUEUES)-1:0] cpl_qid,
  input  logic [15:0]       cpl_cid,
  input  logic [14:0]       cpl_status,  // SF (status field) hors phase bit
  output logic [15:0]       cq_tail [NUM_QUEUES],
  output logic              cq_phase [NUM_QUEUES],
  output cqe_t              cpl_entry,   // CQE prête pour le DMA
  output logic              cpl_wr_req   // demande d'écriture CQE en mémoire hôte
);
  genvar g;
  generate
    for (g = 0; g < NUM_QUEUES; g++) begin : gq
      assign sq_nonempty[g] = (sq_tail[g] != sq_head[g]);
    end
  endgenerate

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < NUM_QUEUES; i++) begin
        sq_head[i] <= '0; cq_tail[i] <= '0; cq_phase[i] <= 1'b1;
      end
      cpl_wr_req <= 1'b0;
    end else begin
      cpl_wr_req <= 1'b0;

      if (sq_pop) begin
        sq_head[sq_pop_qid] <= (sq_head[sq_pop_qid] + 16'd1 >= sq_size)
                             ? 16'd0 : sq_head[sq_pop_qid] + 16'd1;
      end

      if (cpl_push) begin
        cpl_entry.cdw0 <= 32'h0;                       // Command specific (démo)
        cpl_entry.cdw1 <= 32'h0;
        cpl_entry.cdw2 <= {sq_head[cpl_qid], 16'h0};   // SQ Head Ptr + SQID (démo)
        cpl_entry.cdw3 <= {cpl_status, cq_phase[cpl_qid], cpl_cid};
        cpl_wr_req     <= 1'b1;
        cq_tail[cpl_qid] <= cq_tail[cpl_qid] + 16'd1;  // wrap simplifié (démo)
        if (cq_tail[cpl_qid] + 16'd1 == 16'd0) cq_phase[cpl_qid] <= ~cq_phase[cpl_qid];
      end
    end
  end
endmodule : nvme_queue_mgr
