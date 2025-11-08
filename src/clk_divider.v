`default_nettype none

module clk_divider #(
    parameter PERIOD = 2
) (
    input  wire clk_in,
    input  wire rst_n,
    output reg  clk_out
);
  localparam HALF_PERIOD = PERIOD / 2;
  reg [$clog2(HALF_PERIOD)-1:0] counter;

  always @(posedge clk_in or negedge rst_n)
    if (!rst_n) begin
      clk_out <= 0;
      counter <= 0;
    end else if (counter == HALF_PERIOD - 1) begin
      clk_out <= ~clk_out;
      counter <= 0;
    end else begin
      counter <= counter + 1;
    end

  initial clk_out <= 0;
endmodule
