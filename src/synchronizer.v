`default_nettype none

module synchronizer #(
    parameter STAGES = 2,
    parameter WIDTH  = 1
) (
    input  wire             clk,
    input  wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
);
  reg [WIDTH-1:0] stages[0:STAGES-1];

  integer i;

  always @(posedge clk) begin
    stages[0] <= in;

    for (i = 1; i < STAGES; i = i + 1) begin
      stages[i] <= stages[i-1];
    end
  end

  assign out = stages[STAGES-1];
endmodule
