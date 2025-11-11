`default_nettype none

module top_nes_bridge (
    input wire clk,
    input wire rst_n,

    output reg [7:0] led,
    inout wire scl_pin,
    inout wire sda_pin
);
  wire clk_half;

`ifdef IVERILOG
  clk_divider #(
      .PERIOD(2)
  ) divider (
      .clk_in (clk),
      .rst_n  (rst_n),
      .clk_out(clk_half)
  );
`else
  wire clkfb;

  MMCME2_BASE #(
      .CLKIN1_PERIOD(10.0),  // 100 MHz input
      .CLKFBOUT_MULT_F(8.0),
      .CLKOUT0_DIVIDE_F(16.0)  // 100 * 8 / 16 = 50 MHz
  ) u_mmcm (
      .CLKIN1  (clk),
      .CLKFBIN (clkfb),
      .CLKFBOUT(clkfb),
      .CLKOUT0 (clk_half),
      .LOCKED  ()
  );
`endif

  wire scl_out;
  wire sda_in;
  wire sda_out;

  wire start;

  nes_bridge bridge (
      .clk  (clk_half),
      .rst_n(rst_n),

      .start(start),

      .scl_out(scl_out),
      .sda_in (sda_in),
      .sda_out(sda_out)
  );

  assign start   = bridge.ready;
  assign scl_pin = ~scl_out ? 1'b0 : 1'bz;
  assign sda_pin = ~sda_out ? 1'b0 : 1'bz;
  assign sda_in  = sda_pin;

  always @(posedge clk_half or negedge rst_n) begin
    if (!rst_n) begin
      led <= 8'b0;
    end else begin
      if (bridge.joypad_valid) begin
        led <= bridge.joypad;
      end
    end
  end
endmodule
