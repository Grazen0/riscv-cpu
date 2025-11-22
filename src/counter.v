`default_nettype none

module counter #(
    parameter WIDTH = 32
) (
    input wire clk,
    input wire rst_n,

    input  wire [WIDTH-1:0] compare,
    output reg  [WIDTH-1:0] out
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out <= 0;
    end else begin
      if (out >= compare - 1) begin
        out <= 0;
      end else begin
        out <= out + 1;
      end
    end
  end
endmodule
