// usb_packet_framer.sv — Framing du protocole diagnostic STORNADO (côté FPGA).
// Décapsule le cadre binaire versionné décrit dans docs/usb-protocol.md :
//   MAGIC(4)|VER(1)|HDR_LEN(1)|MSG_TYPE(2)|FLAGS(2)|SEQ(4)|PLEN(4)|PAYLOAD|CRC32(4)
// Tout est little-endian. Octet-stream valid/ready fourni par le PHY USB
// (FT601/ULPI/soft-core) ; indépendant du PHY.
//
// PORTÉE : diagnostic uniquement, borné aux buffers embarqués / banc de test
// (cf. PARTIE H). Aucun accès à la mémoire hôte.
module usb_packet_framer #(
  parameter logic [31:0] MAGIC   = 32'h5354_524E, // "STRN"
  parameter int          MAX_PLEN = 4096
)(
  input  logic        clk,
  input  logic        rst_n,

  input  logic        rx_valid,
  output logic        rx_ready,
  input  logic [7:0]  rx_data,

  output logic        frame_valid,
  input  logic        frame_ready,
  output logic [15:0] frame_type,
  output logic [31:0] frame_seq,
  output logic [31:0] frame_plen,
  output logic        frame_crc_ok
);
  typedef enum logic [2:0] {
    U_MAGIC, U_HDR, U_DECIDE, U_PAYLOAD, U_CRC, U_EMIT
  } u_e;
  u_e st;

  logic [31:0] magic_sr;
  logic [31:0] crc_acc;   // CRC calculé sur VER..PAYLOAD
  logic [31:0] crc_rx;    // CRC reçu (assemblé LE)
  logic [7:0]  hcnt;
  logic [31:0] pcnt;
  logic [1:0]  ccnt;

  // CRC reçu complet au moment où arrive le 4e octet (évite une variable locale
  // de bloc, mal supportée par certains simulateurs).
  wire [31:0] crc_rx_full = (crc_rx >> 8) | ({24'h0, rx_data} << 24);

  function automatic logic [31:0] crc32_byte(input logic [31:0] c, input logic [7:0] d);
    logic [31:0] x; int i;
    x = c ^ {24'h0, d};
    for (i = 0; i < 8; i++) x = x[0] ? (x >> 1) ^ 32'hEDB8_8320 : (x >> 1);
    crc32_byte = x;
  endfunction

  assign rx_ready = (st != U_EMIT) && (st != U_DECIDE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= U_MAGIC; magic_sr <= '0; crc_acc <= 32'hFFFF_FFFF; crc_rx <= '0;
      hcnt <= '0; pcnt <= '0; ccnt <= '0;
      frame_valid <= 1'b0; frame_type <= '0; frame_seq <= '0;
      frame_plen <= '0; frame_crc_ok <= 1'b0;
    end else begin
      case (st)
        // État interne (aucun octet consommé) : plen est stable, on branche.
        U_DECIDE: begin
          pcnt <= '0;
          st   <= (frame_plen == 0) ? U_CRC : U_PAYLOAD;
        end
        U_EMIT: if (frame_ready) begin
          frame_valid <= 1'b0;
          crc_acc <= 32'hFFFF_FFFF; hcnt <= '0; pcnt <= '0; ccnt <= '0;
          st <= U_MAGIC;
        end
        default: if (rx_valid) begin
          unique case (st)
            U_MAGIC: begin
              magic_sr <= {magic_sr[23:0], rx_data};
              if ({magic_sr[23:0], rx_data} == MAGIC) begin
                st <= U_HDR; hcnt <= '0; crc_acc <= 32'hFFFF_FFFF;
              end
            end
            U_HDR: begin
              crc_acc <= crc32_byte(crc_acc, rx_data);
              unique case (hcnt)
                8'd2:  frame_type[7:0]   <= rx_data;
                8'd3:  frame_type[15:8]  <= rx_data;
                8'd6:  frame_seq[7:0]    <= rx_data;
                8'd7:  frame_seq[15:8]   <= rx_data;
                8'd8:  frame_seq[23:16]  <= rx_data;
                8'd9:  frame_seq[31:24]  <= rx_data;
                8'd10: frame_plen[7:0]   <= rx_data;
                8'd11: frame_plen[15:8]  <= rx_data;
                8'd12: frame_plen[23:16] <= rx_data;
                8'd13: frame_plen[31:24] <= rx_data;
                default: ; // VER, HDR_LEN, FLAGS : non stockés ici
              endcase
              if (hcnt == 8'd13) st <= U_DECIDE;
              hcnt <= hcnt + 8'd1;
            end
            U_PAYLOAD: begin
              crc_acc <= crc32_byte(crc_acc, rx_data);
              if (pcnt + 32'd1 >= frame_plen) st <= U_CRC;
              pcnt <= pcnt + 32'd1;
            end
            U_CRC: begin
              // assemblage little-endian : 1er octet = LSB
              crc_rx <= (crc_rx >> 8) | ({24'h0, rx_data} << 24);
              if (ccnt == 2'd3) begin
                frame_crc_ok <= ((crc_acc ^ 32'hFFFF_FFFF) == crc_rx_full);
                frame_valid  <= 1'b1;
                st <= U_EMIT;
`ifdef STORNADO_DEBUG
                $display("[%0t] USB frame type=%0h seq=%0d plen=%0d crc_ok=%0b",
                         $time, frame_type, frame_seq, frame_plen,
                         ((crc_acc ^ 32'hFFFF_FFFF) == crc_rx_full));
`endif
              end
              ccnt <= ccnt + 2'd1;
            end
            default: st <= U_MAGIC;
          endcase
        end
      endcase
    end
  end
endmodule : usb_packet_framer
