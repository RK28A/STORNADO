// usb_packet_framer.sv — Framing du protocole diagnostic STORNADO (côté FPGA).
// Encapsule/décapsule le cadre binaire versionné décrit dans docs/usb-protocol.md :
//   MAGIC(4) | VER(1) | HDR_LEN(1) | MSG_TYPE(2) | FLAGS(2) | SEQ(4) | PLEN(4) | PAYLOAD | CRC32(4)
// Tout est little-endian. Ce module parle à un octet-stream (valid/ready) fourni
// par le PHY USB (FT601/ULPI/soft-core) ; il ne dépend pas d'un PHY précis.
//
// PORTÉE : commandes de diagnostic uniquement, restreintes aux buffers embarqués
// ou réservés au banc de test (cf. PARTIE H). Aucun accès à la mémoire hôte.
module usb_packet_framer #(
  parameter logic [31:0] MAGIC = 32'h5354_524E  // "STRN"
)(
  input  logic        clk,
  input  logic        rst_n,

  // flux octet entrant depuis le PHY USB
  input  logic        rx_valid,
  output logic        rx_ready,
  input  logic [7:0]  rx_data,

  // cadre décodé
  output logic        frame_valid,
  input  logic        frame_ready,
  output logic [15:0] frame_type,
  output logic [31:0] frame_seq,
  output logic [31:0] frame_plen,
  output logic        frame_crc_ok
);
  typedef enum logic [2:0] {
    U_MAGIC, U_HDR, U_PAYLOAD, U_CRC, U_EMIT
  } u_e;
  u_e st;

  logic [31:0] acc;
  logic [7:0]  cnt;

  // CRC32 (IEEE 802.3) calculé à la volée sur header+payload.
  logic [31:0] crc;
  function automatic logic [31:0] crc32_byte(input logic [31:0] c, input logic [7:0] d);
    logic [31:0] x; int i;
    x = c ^ {24'h0, d};
    for (i = 0; i < 8; i++)
      x = x[0] ? (x >> 1) ^ 32'hEDB8_8320 : (x >> 1);
    crc32_byte = x;
  endfunction

  assign rx_ready = (st != U_EMIT);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= U_MAGIC; acc <= '0; cnt <= '0; crc <= 32'hFFFF_FFFF;
      frame_valid <= 1'b0; frame_type <= '0; frame_seq <= '0;
      frame_plen <= '0; frame_crc_ok <= 1'b0;
    end else begin
      if (st == U_EMIT) begin
        if (frame_ready) begin frame_valid <= 1'b0; st <= U_MAGIC; crc <= 32'hFFFF_FFFF; cnt <= '0; end
      end else if (rx_valid) begin
        // accumulation MSG header simplifiée : le détail champ-à-champ est dans
        // docs/usb-protocol.md ; ici on illustre magic + CRC de bout en bout.
        if (st != U_MAGIC && st != U_CRC) crc <= crc32_byte(crc, rx_data);
        unique case (st)
          U_MAGIC  : begin
                       acc <= {acc[23:0], rx_data};
                       cnt <= cnt + 1'b1;
                       if (cnt == 8'd3) begin
                         cnt <= '0;
                         st  <= ({acc[23:0], rx_data} == MAGIC) ? U_HDR : U_MAGIC;
                       end
                     end
          U_HDR    : begin cnt <= cnt + 1'b1; if (cnt == 8'd13) begin cnt <= '0; st <= U_PAYLOAD; end end
          U_PAYLOAD: begin if (cnt >= frame_plen[7:0]) begin cnt <= '0; st <= U_CRC; end else cnt <= cnt + 1'b1; end
          U_CRC    : begin
                       acc <= {acc[23:0], rx_data};
                       cnt <= cnt + 1'b1;
                       if (cnt == 8'd3) begin
                         frame_crc_ok <= ((crc ^ 32'hFFFF_FFFF) == {acc[23:0], rx_data});
                         frame_valid  <= 1'b1;
                         st <= U_EMIT;
                       end
                     end
          default  : st <= U_MAGIC;
        endcase
      end
    end
  end
endmodule : usb_packet_framer
