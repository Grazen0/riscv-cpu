`default_nettype none

module clk_divider #(
    parameter PERIOD = 2
) (
    input  wire clk_in,
    output reg  clk_out
);
  localparam HALF_PERIOD = PERIOD / 2;

  reg [$clog2(HALF_PERIOD)-1:0] counter;

  always @(posedge clk_in) begin
    if (counter >= HALF_PERIOD - 1) begin
      clk_out <= ~clk_out;
      counter <= 0;
    end else begin
      counter <= counter + 1;
    end
  end

  initial clk_out = 0;
  initial counter = 0;
endmodule
