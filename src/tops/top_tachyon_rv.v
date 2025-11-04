`default_nettype none

module top_tachyon_rv (
    input wire clk,
    input wire rst_n,

    input wire [4:0] joypad,

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
  wire clk_cpu;
  wire clk_vga;

  clk_divider #(
      .PERIOD(2)
  ) cpu_divider (
      .clk_in (clk),
      .rst_n  (rst_n),
      .clk_out(clk_cpu)
  );

  clk_divider #(
      .PERIOD(2)
  ) vga_divider (
      .clk_in (clk),
      .rst_n  (rst_n),
      .clk_out(clk_vga)
  );

  tachyon_rv tachyon (
      .clk(clk_cpu),
      .clk_vga(clk_vga),
      .rst_n(rst_n),

      .joypad(joypad),

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
