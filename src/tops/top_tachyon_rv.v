`default_nettype none

module top_tachyon_rv (
    input wire clk,
    input wire rst_n,

    output wire joypad_scl,
    output wire joypad_sda,

    output wire [7:0] lcd_data,
    output wire [1:0] lcd_ctrl,
    output wire lcd_enable,

    output wire [3:0] vga_red,
    output wire [3:0] vga_green,
    output wire [3:0] vga_blue,
    output wire h_sync,
    output wire v_sync,

    output wire audio_out
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

  tachyon_rv tachyon (
      .clk(clk_half),
      .clk_vga(clk_half),
      .rst_n(rst_n),

      .joypad_scl(joypad_scl),
      .joypad_sda(joypad_sda),

      .lcd_data  (lcd_data),
      .lcd_ctrl  (lcd_ctrl),
      .lcd_enable(lcd_enable),

      .vga_red(vga_red),
      .vga_green(vga_green),
      .vga_blue(vga_blue),
      .h_sync(h_sync),
      .v_sync(v_sync),

      .audio_out(audio_out)
  );
endmodule
