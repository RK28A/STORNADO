// sync_fifo.sv - Simple synchronous FIFO (single clock), valid/ready interface.
// First-word-fall-through. Depth must be a power of two.
module sync_fifo #(
  parameter int WIDTH = 32,
  parameter int DEPTH = 16
)(
  input  logic             clk,
  input  logic             rst_n,
  // write
  input  logic             wr_valid,
  output logic             wr_ready,
  input  logic [WIDTH-1:0] wr_data,
  // read
  output logic             rd_valid,
  input  logic             rd_ready,
  output logic [WIDTH-1:0] rd_data,
  // status
  output logic [$clog2(DEPTH):0] count
);
  localparam int AW = $clog2(DEPTH);

  logic [WIDTH-1:0] mem [DEPTH];
  logic [AW:0] wptr, rptr; // one guard bit for full/empty

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
  // Invariant: the count never exceeds DEPTH.
  always_comb assert (count <= DEPTH);
`endif
endmodule
