// sync_fifo.sv — FIFO synchrone simple (même horloge), interface valid/ready.
// First-word-fall-through. Profondeur puissance de 2.
module sync_fifo #(
  parameter int WIDTH = 32,
  parameter int DEPTH = 16
)(
  input  logic             clk,
  input  logic             rst_n,
  // écriture
  input  logic             wr_valid,
  output logic             wr_ready,
  input  logic [WIDTH-1:0] wr_data,
  // lecture
  output logic             rd_valid,
  input  logic             rd_ready,
  output logic [WIDTH-1:0] rd_data,
  // statut
  output logic [$clog2(DEPTH):0] count
);
  localparam int AW = $clog2(DEPTH);

  logic [WIDTH-1:0] mem [DEPTH];
  logic [AW:0] wptr, rptr; // un bit de garde pour full/empty

  wire do_wr = wr_valid & wr_ready;
  wire do_rd = rd_valid & rd_ready;

  wire full  = (wptr[AW] != rptr[AW]) && (wptr[AW-1:0] == rptr[AW-1:0]);
  wire empty = (wptr == rptr);

  assign wr_ready = ~full;
  assign rd_valid = ~empty;
  assign rd_data  = mem[rptr[AW-1:0]];
  assign count    = wptr - rptr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wptr <= '0; rptr <= '0;
    end else begin
      if (do_wr) begin mem[wptr[AW-1:0]] <= wr_data; wptr <= wptr + 1'b1; end
      if (do_rd) rptr <= rptr + 1'b1;
    end
  end

`ifdef FORMAL
  // Invariant : le compteur ne dépasse jamais DEPTH.
  always_comb assert (count <= DEPTH);
`endif
endmodule
