// nvme_cmd_decoder.sv — Décodage d'une SQE de 64 octets et routage.
// Entrée : mot de commande dword 0 (CDW0) + champs extraits par le fetch DMA.
// Sortie : classification Admin/IO, opcode, validation de base. La validation
// fine (plages LBA, alignement) est faite par les moteurs en aval.
//
// NB : ce module ne lit pas lui-même la mémoire hôte ; il reçoit la SQE déjà
// rapatriée par le moteur DMA (séparation nette fetch / décodage).
import nvme_pkg::*;

module nvme_cmd_decoder (
  input  logic        clk,
  input  logic        rst_n,

  input  logic        cmd_valid,       // une SQE complète est présentée
  output logic        cmd_ready,
  input  logic        is_admin_queue,  // provient du qid (0 = admin)
  input  logic [31:0] cdw0,            // [7:0]=OPC, [15:14]=PSDT, [31:16]=CID
  input  logic [31:0] nsid,
  input  logic [63:0] prp1,
  input  logic [63:0] prp2,
  input  logic [63:0] slba,            // pour Read/Write (CDW10/11)
  input  logic [31:0] nlb_dw,          // CDW12 : NLB au bit [15:0]

  // commande classifiée vers l'exécuteur
  output logic        issue_valid,
  input  logic        issue_ready,
  output logic [7:0]  issue_opcode,
  output logic        issue_is_admin,
  output logic [15:0] issue_cid,
  output logic [63:0] issue_prp1,
  output logic [63:0] issue_prp2,
  output logic [63:0] issue_slba,
  output logic [15:0] issue_nlb,       // nombre de blocs (0-based dans la spec)
  output logic        issue_unsupported // opcode inconnu -> complétion erreur
);
  wire [7:0]  opc = cdw0[7:0];
  wire [15:0] cid = cdw0[31:16];

  function automatic logic admin_supported(input logic [7:0] o);
    admin_supported = (o inside {ADM_IDENTIFY, ADM_GET_FEATURES, ADM_SET_FEATURES,
                                 ADM_CREATE_IO_SQ, ADM_CREATE_IO_CQ,
                                 ADM_DELETE_IO_SQ, ADM_DELETE_IO_CQ,
                                 ADM_GET_LOG_PAGE, ADM_ABORT});
  endfunction
  function automatic logic io_supported(input logic [7:0] o);
    io_supported = (o inside {IO_READ, IO_WRITE, IO_FLUSH});
  endfunction

  assign cmd_ready    = issue_ready;        // flux simple 1:1
  assign issue_valid  = cmd_valid;
  assign issue_opcode = opc;
  assign issue_is_admin = is_admin_queue;
  assign issue_cid    = cid;
  assign issue_prp1   = prp1;
  assign issue_prp2   = prp2;
  assign issue_slba   = slba;
  assign issue_nlb    = nlb_dw[15:0];
  assign issue_unsupported = is_admin_queue ? ~admin_supported(opc)
                                            : ~io_supported(opc);
endmodule : nvme_cmd_decoder
