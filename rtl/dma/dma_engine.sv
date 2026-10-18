// dma_engine.sv — Moteur DMA de stockage NVMe (SQUELETTE).
// Rôle LÉGITIME et UNIQUE : pour une commande NVMe donnée, lire la SQE,
// récupérer les PRP fournis par l'hôte, transférer les blocs de données entre
// la mémoire hôte DÉSIGNÉE PAR CES PRP et le backend de stockage, puis écrire
// la CQE. Il ne génère aucune adresse de son propre chef.
//
// IMPORTANT (cf. PARTIE G / règle qualité 5) : Bus Master Enable n'est PAS un
// droit de lecture arbitraire de la RAM. Ce moteur n'adresse que les pages
// listées dans les PRP de la commande en cours. Aucun chemin d'exfiltration,
// aucun accès à des processus tiers. Les traductions IOMMU (VT-d/AMD-Vi)
// restent maîtresses : un refus IOMMU se traduit par une complétion d'erreur.
//
// État : interface et FSM posées ; l'émission réelle des TLP mémoire dépend de
// l'IP PCIe retenue (voir rtl/pcie/pcie_wrapper.sv) et n'est pas simulée ici.
import nvme_pkg::*;

module dma_engine #(
  parameter int ADDR_W = 64,
  parameter int DATA_W = 128   // largeur du datapath AXI-stream vers l'IP PCIe
)(
  input  logic              clk,
  input  logic              rst_n,

  // ---- Requête de transfert (issue du décodeur de commandes) ----
  input  logic              req_valid,
  output logic              req_ready,
  input  logic              req_is_write, // 1 = hôte->backend, 0 = backend->hôte
  input  logic [ADDR_W-1:0] req_prp1,
  input  logic [ADDR_W-1:0] req_prp2,
  input  logic [31:0]       req_len_bytes,
  input  logic [ADDR_W-1:0] req_backend_addr,

  // ---- Côté IP PCIe : requête mémoire (Memory Read/Write TLP) ----
  output logic              mem_req_valid,
  input  logic              mem_req_ready,
  output logic              mem_req_we,
  output logic [ADDR_W-1:0] mem_req_addr,     // IOVA fournie par l'hôte (via PRP)
  output logic [10:0]       mem_req_len_dw,
  output logic [DATA_W-1:0] mem_wdata,
  input  logic [DATA_W-1:0] mem_rdata,
  input  logic              mem_rvalid,
  input  logic              mem_err,          // ex. refus IOMMU / completion abort

  // ---- Côté backend de stockage ----
  output logic              be_req_valid,
  input  logic              be_req_ready,
  output logic              be_we,
  output logic [ADDR_W-1:0] be_addr,
  output logic [DATA_W-1:0] be_wdata,
  input  logic [DATA_W-1:0] be_rdata,

  // ---- Fin de transfert ----
  output logic              done,
  output logic              error
);
  localparam int PAGE = 4096;

  typedef enum logic [2:0] {
    D_IDLE, D_PRP_SETUP, D_XFER, D_DONE, D_ERR
  } dma_e;
  dma_e st, st_n;

  logic [31:0]       remaining;
  logic [ADDR_W-1:0] cur_host_addr;
  logic [ADDR_W-1:0] cur_be_addr;

  assign req_ready = (st == D_IDLE);

  always_comb begin
    st_n = st;
    unique case (st)
      D_IDLE     : if (req_valid) st_n = D_PRP_SETUP;
      D_PRP_SETUP: st_n = D_XFER;                 // PRP list walk : TODO (PARTIE G)
      D_XFER     : if (mem_err)              st_n = D_ERR;
                   else if (remaining == 0)  st_n = D_DONE;
      D_DONE     : st_n = D_IDLE;
      D_ERR      : st_n = D_IDLE;
      default    : st_n = D_IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= D_IDLE; remaining <= '0; cur_host_addr <= '0; cur_be_addr <= '0;
    end else begin
      st <= st_n;
      unique case (st)
        D_IDLE : if (req_valid) begin
                   remaining     <= req_len_bytes;
                   cur_host_addr <= req_prp1;
                   cur_be_addr   <= req_backend_addr;
                 end
        D_XFER : if (mem_req_valid && mem_req_ready) begin
                   // avance symbolique ; le vrai pipeline dépend de l'IP PCIe
                   remaining     <= (remaining > PAGE) ? remaining - PAGE : '0;
                   cur_host_addr <= cur_host_addr + PAGE;
                   cur_be_addr   <= cur_be_addr + PAGE;
                 end
        default: ;
      endcase
    end
  end

  // Sorties (datapath réel à câbler sur l'IP PCIe lors de l'intégration)
  assign mem_req_valid = (st == D_XFER) && (remaining != 0);
  assign mem_req_we    = req_is_write ? 1'b0 : 1'b1; // write cmd -> on lit l'hôte
  assign mem_req_addr  = cur_host_addr;
  assign mem_req_len_dw= (remaining > PAGE) ? 11'd1024 : remaining[12:2];
  assign mem_wdata     = be_rdata;

  assign be_req_valid  = (st == D_XFER);
  assign be_we         = req_is_write;              // write cmd -> on écrit backend
  assign be_addr       = cur_be_addr;
  assign be_wdata      = mem_rdata;

  assign done  = (st == D_DONE);
  assign error = (st == D_ERR);
endmodule : dma_engine
