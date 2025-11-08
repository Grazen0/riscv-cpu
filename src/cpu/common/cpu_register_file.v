`default_nettype none

module cpu_register_file (
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
  localparam REGS_SIZE = 32;

  reg [31:0] regs[1:REGS_SIZE-1];

  integer i;

  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset registers
      for (i = 1; i < REGS_SIZE; i = i + 1) begin
        regs[i] <= 0;
      end
    end else begin
      if (we3 && a3 != 0) begin
        regs[a3] <= wd3;
      end
    end
  end

  assign rd1 = a1 == 0 ? 0 : regs[a1];
  assign rd2 = a2 == 0 ? 0 : regs[a2];

  generate
    genvar idx;
    for (idx = 1; idx < 32; idx = idx + 1) begin : g_register
      wire [31:0] val = regs[idx];
    end
  endgenerate
endmodule

