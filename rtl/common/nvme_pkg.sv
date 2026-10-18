// nvme_pkg.sv - Shared constants and types for STORNADO.
// References: NVMe Base Specification 2.0c, PCIe Base 4.0.
// Values marked TODO-SPEC must be re-checked against the spec before freeze.
package nvme_pkg;

  // ---- Generic widths ----
  localparam int unsigned REG_AW = 20;   // addressable BAR0 space (1 MiB)
  localparam int unsigned REG_DW = 32;

  // ---- NVMe register offsets (NVMe 2.0, section 3.1) ----
  localparam logic [REG_AW-1:0] OFF_CAP0    = 20'h0000; // CAP[31:0]
  localparam logic [REG_AW-1:0] OFF_CAP1    = 20'h0004; // CAP[63:32]
  localparam logic [REG_AW-1:0] OFF_VS      = 20'h0008;
  localparam logic [REG_AW-1:0] OFF_INTMS   = 20'h000C;
  localparam logic [REG_AW-1:0] OFF_INTMC   = 20'h0010;
  localparam logic [REG_AW-1:0] OFF_CC      = 20'h0014;
  localparam logic [REG_AW-1:0] OFF_CSTS    = 20'h001C;
  localparam logic [REG_AW-1:0] OFF_NSSR    = 20'h0020;
  localparam logic [REG_AW-1:0] OFF_AQA     = 20'h0024;
  localparam logic [REG_AW-1:0] OFF_ASQ0    = 20'h0028;
  localparam logic [REG_AW-1:0] OFF_ASQ1    = 20'h002C;
  localparam logic [REG_AW-1:0] OFF_ACQ0    = 20'h0030;
  localparam logic [REG_AW-1:0] OFF_ACQ1    = 20'h0034;
  localparam logic [REG_AW-1:0] OFF_DBRANGE = 20'h1000; // doorbell region base

  // ---- Version reported in VS: 2.0.0 ----
  localparam logic [31:0] VS_VALUE = 32'h0002_0000;

  // ---- CC (Controller Configuration) fields ----
  // CC.EN = bit 0 ; CC.CSS = [6:4] ; CC.MPS = [10:7] ; CC.IOSQES = [19:16] ; CC.IOCQES = [23:20]
  // ---- CSTS (Controller Status) fields ----
  // CSTS.RDY = bit 0 ; CSTS.CFS = bit 1 ; CSTS.SHST = [3:2]

  // ---- Admin opcodes (NVMe 2.0, Figure 139) ----
  localparam logic [7:0] ADM_DELETE_IO_SQ = 8'h00;
  localparam logic [7:0] ADM_CREATE_IO_SQ = 8'h01;
  localparam logic [7:0] ADM_GET_LOG_PAGE = 8'h02;
  localparam logic [7:0] ADM_DELETE_IO_CQ = 8'h04;
  localparam logic [7:0] ADM_CREATE_IO_CQ = 8'h05;
  localparam logic [7:0] ADM_IDENTIFY     = 8'h06;
  localparam logic [7:0] ADM_ABORT        = 8'h08;
  localparam logic [7:0] ADM_SET_FEATURES = 8'h09;
  localparam logic [7:0] ADM_GET_FEATURES = 8'h0A;

  // ---- I/O opcodes (NVM Command Set) ----
  localparam logic [7:0] IO_FLUSH = 8'h00;
  localparam logic [7:0] IO_WRITE = 8'h01;
  localparam logic [7:0] IO_READ  = 8'h02;

  // ---- Status Codes (Completion, SCT=0 Generic) ----
  localparam logic [7:0] SC_SUCCESS            = 8'h00;
  localparam logic [7:0] SC_INVALID_OPCODE     = 8'h01;
  localparam logic [7:0] SC_INVALID_FIELD      = 8'h02;
  localparam logic [7:0] SC_DATA_XFER_ERROR    = 8'h04;
  localparam logic [7:0] SC_LBA_OUT_OF_RANGE   = 8'h80; // SCT=1 (Command Specific) in reality, see TODO-SPEC

  // ---- Queue structures ----
  // SQ entry = 64 bytes (16 dwords), CQ entry = 16 bytes (4 dwords).
  typedef struct packed {
    logic [31:0] cdw3; logic [31:0] cdw2; logic [31:0] cdw1; logic [31:0] cdw0;
  } cqe_t; // Completion Queue Entry (16 B)

  // Default namespace (validation bench)
  localparam int unsigned LBA_SHIFT   = 9;          // 512 B/block
  localparam int unsigned LBA_BYTES   = 1 << LBA_SHIFT;

endpackage : nvme_pkg
