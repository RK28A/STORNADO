// nvme_cmd_decoder.sv - Decode a 64-byte SQE and route it.
// Input: command dword 0 (CDW0) plus the fields extracted by the DMA fetch.
// Output: Admin/IO classification, opcode, basic validation. Fine-grained
// validation (LBA ranges, alignment) is done by the downstream engines.
//
// Note: this module does not read host memory itself; it receives the SQE
// already fetched by the DMA engine (clean fetch / decode separation).
import nvme_pkg::*;

module nvme_cmd_decoder (
  input  logic        clk,
  input  logic        rst_n,

  input  logic        cmd_valid,       // a complete SQE is presented
  output logic        cmd_ready,
  input  logic        is_admin_queue,  // derived from qid (0 = admin)
  input  logic [31:0] cdw0,            // [7:0]=OPC, [15:14]=PSDT, [31:16]=CID
  input  logic [31:0] nsid,
  input  logic [63:0] prp1,
  input  logic [63:0] prp2,
  input  logic [63:0] slba,            // for Read/Write (CDW10/11)
  input  logic [31:0] nlb_dw,          // CDW12: NLB in bits [15:0]

  // classified command to the executor
  output logic        issue_valid,
  input  logic        issue_ready,
  output logic [7:0]  issue_opcode,
  output logic        issue_is_admin,
  output logic [15:0] issue_cid,
  output logic [63:0] issue_prp1,
  output logic [63:0] issue_prp2,
  output logic [63:0] issue_slba,
  output logic [15:0] issue_nlb,       // number of blocks (0-based in the spec)
  output logic        issue_unsupported // unknown opcode -> error completion
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

  assign cmd_ready    = issue_ready;        // simple 1:1 flow
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
