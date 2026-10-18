// reset_sync.sv - Synchronous de-assertion of an asynchronous (active-low) reset.
// Immediate assertion, release resynchronized onto clk (double flop).
module reset_sync #(
  parameter int STAGES = 2
)(
  input  logic clk,
  input  logic arst_n,   // asynchronous active-low reset
  output logic srst_n    // synchronous active-low reset
);
  (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] sync;
  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) sync <= '0;
    else         sync <= {sync[STAGES-2:0], 1'b1};
  end
  assign srst_n = sync[STAGES-1];
endmodule
