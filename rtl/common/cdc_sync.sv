// cdc_sync.sv - Multi-flop synchronizer for a 1-bit signal (CDC).
// Use only for slow control signals. For a multi-bit bus, go through async_fifo
// or a gray-code handshake (see async_fifo.sv).
module cdc_sync #(
  parameter int STAGES = 2,
  parameter logic RESET_VAL = 1'b0
)(
  input  logic clk,
  input  logic rst_n,
  input  logic d,
  output logic q
);
  (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] sync;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) sync <= {STAGES{RESET_VAL}};
    else        sync <= {sync[STAGES-2:0], d};
  end
  assign q = sync[STAGES-1];
endmodule
