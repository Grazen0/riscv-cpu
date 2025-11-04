`default_nettype none

module top_pl (
    input wire clk,
    input wire rst_n,

    output wire [7:0] lcd_data,
    output wire [1:0] lcd_ctrl,
    output wire lcd_enable,

    output wire [3:0] vga_red,
    output wire [3:0] vga_green,
    output wire [3:0] vga_blue,
    output wire h_sync,
    output wire v_sync
);
  tachyon_rv tachyon (
      .clk  (clk),
      .rst_n(rst_n),

      .lcd_data  (lcd_data),
      .lcd_ctrl  (lcd_ctrl),
      .lcd_enable(lcd_enable),

      .vga_red(vga_red),
      .vga_green(vga_green),
      .vga_blue(vga_blue),
      .h_sync(h_sync),
      .v_sync(v_sync)
  );
endmodule
