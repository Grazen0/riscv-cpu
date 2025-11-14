`default_nettype none

module cpu_register_file #(
    parameter HARDWIRE_ZERO = 1
) (
    input wire clk,
    input wire rst_n,
    input wire [4:0] a1,
    input wire [4:0] a2,
    input wire [4:0] a3,
    input wire [31:0] wd3,
    input wire we3,

    output wire [31:0] rd1,
    output wire [31:0] rd2
);
  localparam REGS_START = HARDWIRE_ZERO ? 1 : 0;
  localparam REGS_SIZE = 32;

  reg [31:0] regs[REGS_START:REGS_SIZE-1];

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset registers
      // TODO: remove this eventually
      for (i = REGS_START; i < REGS_SIZE; i = i + 1) begin
        regs[i] <= 0;
      end
    end else begin
      if (we3 && (!HARDWIRE_ZERO || a3 != 0)) begin
        regs[a3] <= wd3;
      end
    end
  end

  if (HARDWIRE_ZERO) begin
    assign rd1 = a1 == 0 ? 0 : regs[a1];
    assign rd2 = a2 == 0 ? 0 : regs[a2];
  end else begin
    assign rd1 = regs[a1];
    assign rd2 = regs[a2];
  end

  generate
    genvar idx;
    for (idx = REGS_START; idx < 32; idx = idx + 1) begin : g_register
      wire [31:0] val = regs[idx];
    end
  endgenerate
endmodule

