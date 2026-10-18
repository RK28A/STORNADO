// tb_usb_framer.sv - Byte-stream testbench for usb_packet_framer.
// Builds a full STORNADO frame with a correct CRC, feeds it byte by byte, and
// checks the decoded type/seq/plen and crc_ok. Then a corrupted-CRC frame, then
// an empty-payload frame. CRC function mirrors the RTL exactly. No fork/cast.
`timescale 1ns/1ps
module tb_usb_framer;
  logic clk = 0, rst_n = 0;
  logic rx_valid, rx_ready, frame_ready;
  logic [7:0] rx_data;
  logic frame_valid, frame_crc_ok;
  logic [15:0] frame_type;
  logic [31:0] frame_seq, frame_plen;
  int errors = 0;

  usb_packet_framer dut (
    .clk, .rst_n, .rx_valid, .rx_ready, .rx_data,
    .frame_valid, .frame_ready,
    .frame_type, .frame_seq, .frame_plen, .frame_crc_ok
  );

  always #5 clk = ~clk;

  function automatic logic [31:0] crc32_byte(input logic [31:0] c, input logic [7:0] d);
    logic [31:0] x; int i;
    x = c ^ {24'h0, d};
    for (i = 0; i < 8; i++) x = x[0] ? (x >> 1) ^ 32'hEDB8_8320 : (x >> 1);
    crc32_byte = x;
  endfunction

  byte unsigned frame [0:63];
  int flen;

  task automatic build(input logic [15:0] mtype, input logic [31:0] seq,
                       input int pl, input bit corrupt);
    logic [31:0] crc; int i;
    frame[0]=8'h53; frame[1]=8'h54; frame[2]=8'h52; frame[3]=8'h4E; // STRN
    frame[4]=8'd1;  frame[5]=8'd18;
    frame[6]=mtype[7:0];  frame[7]=mtype[15:8];
    frame[8]=8'h0;  frame[9]=8'h0;
    frame[10]=seq[7:0]; frame[11]=seq[15:8]; frame[12]=seq[23:16]; frame[13]=seq[31:24];
    frame[14]=pl[7:0]; frame[15]=pl[15:8]; frame[16]=pl[23:16]; frame[17]=pl[31:24];
    for (i = 0; i < pl; i++) frame[18+i] = i + 1;
    crc = 32'hFFFF_FFFF;
    for (i = 4; i < 18 + pl; i++) crc = crc32_byte(crc, frame[i]);
    crc = crc ^ 32'hFFFF_FFFF;
    frame[18+pl+0]=crc[7:0]; frame[18+pl+1]=crc[15:8];
    frame[18+pl+2]=crc[23:16]; frame[18+pl+3]=crc[31:24];
    if (corrupt) frame[18+pl+0] = frame[18+pl+0] ^ 8'hFF;
    flen = 18 + pl + 4;
  endtask

  task automatic send_byte(input byte unsigned b);
    @(posedge clk);
    while (!rx_ready) @(posedge clk);
    rx_valid = 1; rx_data = b;
    @(posedge clk);
    rx_valid = 0;
  endtask

  task automatic feed_and_check(input logic [15:0] mtype, input logic [31:0] seq,
                                input int pl, input bit corrupt, input bit exp_ok);
    int i; int guard;
    build(mtype, seq, pl, corrupt);
    for (i = 0; i < flen; i++) send_byte(frame[i]);
    // frame_ready is held 0, so frame_valid latches and holds until released
    guard = 0;
    while (!frame_valid && guard < 100) begin @(posedge clk); guard++; end
    if (!frame_valid) begin $display("FAIL no frame emitted"); errors++; end
    if (frame_type !== mtype) begin $display("FAIL type %0h", frame_type); errors++; end
    if (frame_seq  !== seq)   begin $display("FAIL seq %0h", frame_seq);  errors++; end
    if (frame_plen !== pl)    begin $display("FAIL plen %0d", frame_plen); errors++; end
    if (frame_crc_ok !== exp_ok) begin $display("FAIL crc_ok %0b exp %0b", frame_crc_ok, exp_ok); errors++; end
    // release the frame
    frame_ready = 1; @(posedge clk); frame_ready = 0; @(posedge clk);
  endtask

  initial begin
    rx_valid = 0; rx_data = 0; frame_ready = 0;
    repeat (3) @(posedge clk); rst_n = 1;

    feed_and_check(16'h0003, 32'h1122_3344, 4, 1'b0, 1'b1);  // good CRC
    feed_and_check(16'h000C, 32'h0000_0001, 8, 1'b1, 1'b0);  // corrupted CRC
    feed_and_check(16'h0001, 32'hDEAD_0000, 0, 1'b0, 1'b1);  // empty payload

    if (errors == 0) $display("TB_USB_FRAMER: PASS");
    else             $display("TB_USB_FRAMER: FAIL (%0d)", errors);
    $finish;
  end

  initial begin #200000; $display("TB_USB_FRAMER: TIMEOUT"); $finish; end
endmodule
