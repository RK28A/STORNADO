// async_fifo.sv - Dual-clock FIFO, resynchronized Gray pointers.
// Use: cross the CDC between the PCIe link domain (user clock) and the NVMe core
// domain, or between the core and the USB domain. Depth must be a power of two.
module async_fifo #(
  parameter int WIDTH = 32,
  parameter int DEPTH = 16
)(
  // write domain
  input  logic             wr_clk,
  input  logic             wr_rst_n,
  input  logic             wr_valid,
  output logic             wr_ready,
  input  logic [WIDTH-1:0] wr_data,
  // read domain
  input  logic             rd_clk,
  input  logic             rd_rst_n,
  output logic             rd_valid,
  input  logic             rd_ready,
  output logic [WIDTH-1:0] rd_data
);
  localparam int AW = $clog2(DEPTH);

  logic [WIDTH-1:0] mem [DEPTH];

  logic [AW:0] wbin, wgray, wgray_rd1, wgray_rd2;
  logic [AW:0] rbin, rgray, rgray_wr1, rgray_wr2;

  function automatic logic [AW:0] bin2gray(input logic [AW:0] b);
    return b ^ (b >> 1);
  endfunction

  // ---- write domain ----
  wire do_wr = wr_valid & wr_ready;
  wire [AW:0] wbin_next = wbin + (do_wr ? 1'b1 : 1'b0);
  wire wfull = (bin2gray(wbin_next) == {~rgray_wr2[AW:AW-1], rgray_wr2[AW-2:0]});

  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin wbin <= '0; wgray <= '0; end
    else begin
      if (do_wr) mem[wbin[AW-1:0]] <= wr_data;
      wbin  <= wbin_next;
      wgray <= bin2gray(wbin_next);
    end
  end
  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) {rgray_wr2, rgray_wr1} <= '0;
    else           {rgray_wr2, rgray_wr1} <= {rgray_wr1, rgray};
  end
  assign wr_ready = ~wfull;

  // ---- read domain ----
  wire [AW:0] rbin_next = rbin + ((rd_valid & rd_ready) ? 1'b1 : 1'b0);
  wire rempty = (rgray == wgray_rd2);

  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin rbin <= '0; rgray <= '0; end
    else begin
      rbin  <= rbin_next;
      rgray <= bin2gray(rbin_next);
    end
  end
  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) {wgray_rd2, wgray_rd1} <= '0;
    else           {wgray_rd2, wgray_rd1} <= {wgray_rd1, wgray};
  end
  assign rd_valid = ~rempty;
  assign rd_data  = mem[rbin[AW-1:0]];
endmodule
