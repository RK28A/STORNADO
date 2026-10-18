// nvme_regs.sv — Bloc de registres contrôleur NVMe (BAR0) + FSM d'init.
// Implémente CAP, VS, CC, CSTS, AQA, ASQ, ACQ, INTMS/INTMC et la logique
// CC.EN -> CSTS.RDY (NVMe 2.0, section 3.1.5 "Controller Initialization").
// Bus d'accès style MMIO 32 bits, aligné dword. Les doorbells sont gérés
// à part (nvme_doorbells.sv) car indexés par queue.
//
// Portabilité : module 100% synthétisable, sans primitive vendeur.
import nvme_pkg::*;

module nvme_regs (
  input  logic              clk,
  input  logic              rst_n,

  // ---- Interface MMIO (depuis le pont PCIe/TLP) ----
  input  logic              reg_sel,     // accès dans la plage registres (hors doorbells)
  input  logic              reg_we,      // 1 = write, 0 = read
  input  logic [REG_AW-1:0] reg_addr,    // offset dans BAR0
  input  logic [REG_DW-1:0] reg_wdata,
  input  logic [3:0]        reg_wstrb,   // par octet
  output logic [REG_DW-1:0] reg_rdata,
  output logic              reg_ack,

  // ---- Valeurs exposées au reste du cœur ----
  output logic [63:0]       asq_base,    // adresse DMA Admin SQ
  output logic [63:0]       acq_base,    // adresse DMA Admin CQ
  output logic [11:0]       asq_size,    // AQA.ASQS + 1 (entrées)
  output logic [11:0]       acq_size,    // AQA.ACQS + 1 (entrées)
  output logic              ctrl_enabled,// CC.EN propre (après RDY)
  output logic              ctrl_ready,  // CSTS.RDY

  // ---- Événements d'erreur rapportés par le cœur ----
  input  logic              fatal_error  // force CSTS.CFS=1
);

  // ------------------------------------------------------------------
  // CAP (Controller Capabilities) — lecture seule.
  //   MQES  [15:0]  = max queue entries - 1            -> 1023 (1024 entrées)
  //   CQR   [16]    = contiguous queues required       -> 1
  //   TO    [31:24] = timeout en unités de 500 ms      -> 20 (10 s)
  //   DSTRD [35:32] = doorbell stride (2^(2+DSTRD))     -> 0 (4 octets)
  //   CSS   [44:37] = command sets supported           -> NVM (bit37=1)
  //   MPSMIN[51:48] = page size min (2^(12+val))       -> 0 (4 KiB)
  //   MPSMAX[55:52] = page size max                    -> 0 (4 KiB)
  // TODO-SPEC : revérifier bit à bit avant gel du design.
  // ------------------------------------------------------------------
  localparam logic [63:0] CAP_VALUE = 64'h0000_0020_0014_03FF;

  // ------------------------------------------------------------------
  // Registres R/W
  // ------------------------------------------------------------------
  logic [31:0] cc_q;
  logic [31:0] csts_q;
  logic [31:0] intms_q;
  logic [31:0] aqa_q;
  logic [63:0] asq_q, acq_q;

  wire        cc_en   = cc_q[0];
  wire [3:0]  cc_mps  = cc_q[10:7];
  wire [2:0]  cc_css  = cc_q[6:4];

  assign asq_base     = asq_q;
  assign acq_base     = acq_q;
  assign asq_size     = aqa_q[11:0]  + 12'd1;  // AQA.ASQS
  assign acq_size     = aqa_q[27:16] + 12'd1;  // AQA.ACQS
  assign ctrl_ready   = csts_q[0];
  assign ctrl_enabled = cc_en & csts_q[0];

  // ------------------------------------------------------------------
  // FSM d'initialisation contrôleur
  //   RDY suit EN avec une latence (ici symbolique). Un passage EN 1->0
  //   déclenche un reset contrôleur : RDY retombe, queues invalidées.
  // ------------------------------------------------------------------
  typedef enum logic [1:0] {S_DISABLED, S_ENABLING, S_READY, S_RESETTING} init_e;
  init_e state, state_n;

  localparam int unsigned RDY_DELAY = 8; // cycles symboliques avant RDY
  logic [7:0] dly;

  always_comb begin
    state_n = state;
    unique case (state)
      S_DISABLED : if (cc_en) state_n = S_ENABLING;
      S_ENABLING : if (dly == RDY_DELAY) state_n = S_READY;
                   else if (!cc_en)      state_n = S_DISABLED;
      S_READY    : if (!cc_en) state_n = S_RESETTING;
      S_RESETTING: state_n = S_DISABLED;
      default    : state_n = S_DISABLED;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_DISABLED; dly <= '0; csts_q <= '0;
    end else begin
`ifdef STORNADO_DEBUG
      if (state != state_n) $display("[%0t] NVMe init FSM %0d -> %0d (CC.EN=%0b)",
                                     $time, state, state_n, cc_en);
`endif
      state <= state_n;
      csts_q[1] <= fatal_error ? 1'b1 : csts_q[1]; // CFS collant jusqu'au reset
      case (state)
        S_ENABLING : dly <= dly + 1'b1;
        default    : dly <= '0;
      endcase
      csts_q[0] <= (state == S_READY); // CSTS.RDY
      if (state == S_RESETTING) csts_q[1] <= 1'b0; // CFS effacé au reset
    end
  end

  // ------------------------------------------------------------------
  // Accès registres (1 cycle, ack combinatoire)
  // ------------------------------------------------------------------
  function automatic logic [31:0] apply_strb
      (input logic [31:0] cur, input logic [31:0] nxt, input logic [3:0] s);
    apply_strb = cur;
    for (int i = 0; i < 4; i++)
      if (s[i]) apply_strb[i*8 +: 8] = nxt[i*8 +: 8];
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cc_q <= '0; intms_q <= '0; aqa_q <= '0; asq_q <= '0; acq_q <= '0;
    end else if (reg_sel && reg_we) begin
      unique case (reg_addr)
        OFF_CC    : cc_q    <= apply_strb(cc_q,    reg_wdata, reg_wstrb);
        OFF_INTMS : intms_q <= intms_q | reg_wdata;          // write-1-to-set
        OFF_INTMC : intms_q <= intms_q & ~reg_wdata;         // write-1-to-clear
        OFF_AQA   : aqa_q   <= apply_strb(aqa_q,   reg_wdata, reg_wstrb);
        OFF_ASQ0  : asq_q[31:0]  <= apply_strb(asq_q[31:0],  reg_wdata, reg_wstrb);
        OFF_ASQ1  : asq_q[63:32] <= apply_strb(asq_q[63:32], reg_wdata, reg_wstrb);
        OFF_ACQ0  : acq_q[31:0]  <= apply_strb(acq_q[31:0],  reg_wdata, reg_wstrb);
        OFF_ACQ1  : acq_q[63:32] <= apply_strb(acq_q[63:32], reg_wdata, reg_wstrb);
        default   : ; // écriture sur RO ou réservé : ignorée (cf. règle NVMe)
      endcase
    end
  end

  always_comb begin
    reg_rdata = 32'h0;
    unique case (reg_addr)
      OFF_CAP0 : reg_rdata = CAP_VALUE[31:0];
      OFF_CAP1 : reg_rdata = CAP_VALUE[63:32];
      OFF_VS   : reg_rdata = VS_VALUE;
      OFF_INTMS: reg_rdata = intms_q;
      OFF_INTMC: reg_rdata = intms_q;
      OFF_CC   : reg_rdata = cc_q;
      OFF_CSTS : reg_rdata = csts_q;
      OFF_AQA  : reg_rdata = aqa_q;
      OFF_ASQ0 : reg_rdata = asq_q[31:0];
      OFF_ASQ1 : reg_rdata = asq_q[63:32];
      OFF_ACQ0 : reg_rdata = acq_q[31:0];
      OFF_ACQ1 : reg_rdata = acq_q[63:32];
      default  : reg_rdata = 32'h0;
    endcase
  end

  assign reg_ack = reg_sel; // accès 1 cycle

endmodule : nvme_regs
