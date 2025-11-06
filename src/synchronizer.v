`default_nettype none

module synchronizer #(
    parameter WIDTH = 1
) (
    input  wire             clk,
    input  wire [WIDTH-1:0] in,
    output reg  [WIDTH-1:0] out
);
  reg [WIDTH-1:0] tmp;

  always @(posedge clk) begin
    tmp <= in;
    out <= tmp;
  end
endmodule
