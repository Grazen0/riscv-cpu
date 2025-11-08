`default_nettype none

module clk_divider #(
    parameter PERIOD = 2
) (
    input  wire clk_in,
    input  wire rst_n,
    output reg  clk_out
);
  localparam COUNTER_BITS = $clog2(PERIOD);
  reg [COUNTER_BITS-1:0] counter;

  always @(posedge clk_in)
    if (!rst_n) begin
      clk_out <= 0;
      counter <= 0;
    end else if (counter == (PERIOD / 2) - 1) begin
      clk_out <= ~clk_out;
      counter <= 0;
    end else counter <= counter + 1;
endmodule
