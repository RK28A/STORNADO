// stornado_top.sv — Top-level STORNADO : câblage des blocs portables.
// Assemble pcie_wrapper (spécifique IP) + nvme_regs + doorbells + queue_mgr +
// cmd_decoder + dma_engine + storage_backend + usb_packet_framer.
//
// ÉTAT : intégration de référence. Le chemin de données complet (fetch SQE réel,
// walk des PRP, exécution Read/Write, génération Identify) est partiellement
// squelettique — voir les TODO-IP / TODO-SPEC dans chaque sous-module et
// docs/REVIEW.md. Rien ici n'est "prêt à flasher".
import nvme_pkg::*;

module stornado_top #(
  parameter int LANES = 4,
  parameter int NUM_QUEUES = 2
)(
  input  logic              refclk_p, refclk_n, perst_n,
  input  logic [LANES-1:0]  pcie_rx_p, pcie_rx_n,
  output logic [LANES-1:0]  pcie_tx_p, pcie_tx_n,
  input  logic              usb_clk, usb_rst_n,
  input  logic              usb_rx_valid, input logic [7:0] usb_rx_data,
  output logic              usb_rx_ready,
  output logic              link_up
);
  logic user_clk, user_rst_n;

  // ---- MMIO ----
  logic              mmio_sel, mmio_we;
  logic [REG_AW-1:0] mmio_addr;
  logic [REG_DW-1:0] mmio_wdata, mmio_rdata, reg_rdata, db_rdata;
  logic [3:0]        mmio_wstrb;
  logic              mmio_ack, reg_ack, db_ack;

  wire sel_db  = mmio_sel && (mmio_addr >= OFF_DBRANGE);
  wire sel_reg = mmio_sel && (mmio_addr <  OFF_DBRANGE);
  assign mmio_rdata = sel_db ? db_rdata : reg_rdata;
  assign mmio_ack   = sel_db ? db_ack   : reg_ack;

  // ---- valeurs registres ----
  logic [63:0] asq_base, acq_base;
  logic [11:0] asq_size, acq_size;
  logic        ctrl_enabled, ctrl_ready, fatal_error;

  // ---- doorbells / queues (bus packés) ----
  logic                          sq_rung;
  logic [$clog2(NUM_QUEUES)-1:0] sq_rung_qid;
  logic [NUM_QUEUES*16-1:0]      sq_tail_flat, cq_head_flat;
  logic [NUM_QUEUES*16-1:0]      sq_head_flat, cq_tail_flat;
  logic [NUM_QUEUES-1:0]         sq_nonempty, cq_phase;

  // ---- DMA <-> PCIe ----
  logic         mem_req_valid, mem_req_ready, mem_req_we, mem_rvalid, mem_err;
  logic [63:0]  mem_req_addr;
  logic [10:0]  mem_req_len_dw;
  logic [127:0] mem_wdata, mem_rdata;

  // ---- DMA <-> backend ----
  logic         be_req_valid, be_req_ready, be_we, be_rvalid, be_oob;
  logic [63:0]  be_addr;
  logic [127:0] be_wdata, be_rdata;

  // ---- USB ----
  logic        frame_valid, frame_crc_ok;
  logic [15:0] frame_type;
  logic [31:0] frame_seq, frame_plen;

  pcie_wrapper #(.LANES(LANES)) u_pcie (
    .refclk_p, .refclk_n, .perst_n,
    .rx_p(pcie_rx_p), .rx_n(pcie_rx_n), .tx_p(pcie_tx_p), .tx_n(pcie_tx_n),
    .user_clk, .user_rst_n, .link_up, .link_width(), .link_speed(),
    .mmio_sel, .mmio_we, .mmio_addr, .mmio_wdata, .mmio_wstrb, .mmio_rdata, .mmio_ack,
    .mem_req_valid, .mem_req_ready, .mem_req_we, .mem_req_addr, .mem_req_len_dw,
    .mem_wdata, .mem_rdata, .mem_rvalid, .mem_err,
    .msix_req(1'b0), .msix_vector(11'd0)
  );

  nvme_regs u_regs (
    .clk(user_clk), .rst_n(user_rst_n),
    .reg_sel(sel_reg), .reg_we(mmio_we), .reg_addr(mmio_addr),
    .reg_wdata(mmio_wdata), .reg_wstrb(mmio_wstrb),
    .reg_rdata(reg_rdata), .reg_ack(reg_ack),
    .asq_base, .acq_base, .asq_size, .acq_size,
    .ctrl_enabled, .ctrl_ready, .fatal_error(fatal_error)
  );

  nvme_doorbells #(.NUM_QUEUES(NUM_QUEUES)) u_db (
    .clk(user_clk), .rst_n(user_rst_n),
    .db_sel(sel_db), .db_we(mmio_we), .db_addr(mmio_addr),
    .db_wdata(mmio_wdata), .db_rdata(db_rdata), .db_ack(db_ack),
    .sq_rung, .sq_rung_qid, .sq_tail_flat, .cq_head_flat
  );

  nvme_queue_mgr #(.NUM_QUEUES(NUM_QUEUES)) u_qm (
    .clk(user_clk), .rst_n(user_rst_n),
    .sq_tail_flat, .cq_head_flat, .sq_size(asq_size),
    .sq_head_flat, .sq_nonempty, .sq_pop(1'b0), .sq_pop_qid('0),
    .cpl_push(1'b0), .cpl_qid('0), .cpl_cid('0), .cpl_status('0),
    .cq_tail_flat, .cq_phase, .cpl_entry(), .cpl_wr_req()
  );

  dma_engine u_dma (
    .clk(user_clk), .rst_n(user_rst_n),
    .req_valid(1'b0), .req_ready(), .req_is_write(1'b0),
    .req_prp1('0), .req_prp2('0), .req_len_bytes('0), .req_backend_addr('0),
    .mem_req_valid, .mem_req_ready, .mem_req_we, .mem_req_addr, .mem_req_len_dw,
    .mem_wdata, .mem_rdata, .mem_rvalid, .mem_err,
    .be_req_valid, .be_req_ready, .be_we, .be_addr, .be_wdata, .be_rdata,
    .done(), .error()
  );

  storage_backend_ram u_be (
    .clk(user_clk), .rst_n(user_rst_n),
    .req_valid(be_req_valid), .req_ready(be_req_ready), .we(be_we),
    .addr(be_addr), .wdata(be_wdata), .rdata(be_rdata),
    .rvalid(be_rvalid), .oob_error(be_oob)
  );

  usb_packet_framer u_usb (
    .clk(usb_clk), .rst_n(usb_rst_n),
    .rx_valid(usb_rx_valid), .rx_ready(usb_rx_ready), .rx_data(usb_rx_data),
    .frame_valid, .frame_ready(1'b1),
    .frame_type, .frame_seq, .frame_plen, .frame_crc_ok
  );

  assign fatal_error = 1'b0; // relié aux détecteurs d'erreur lors de l'intégration
endmodule : stornado_top
