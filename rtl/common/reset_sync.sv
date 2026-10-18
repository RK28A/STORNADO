// reset_sync.sv — Dé-assertion synchrone d'un reset asynchrone (actif bas).
// Assertion immédiate, relâchement resynchronisé sur clk (double bascule).
module reset_sync #(
  parameter int STAGES = 2
)(
  input  logic clk,
  input  logic arst_n,   // reset asynchrone actif bas
  output logic srst_n    // reset synchrone actif bas
);
  (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] sync;
  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) sync <= '0;
    else         sync <= {sync[STAGES-2:0], 1'b1};
  end
  assign srst_n = sync[STAGES-1];
endmodule
