`timescale 1ns / 1ps `default_nettype none

module video_unit_tb ();
  reg clk, rst_n;
  always #5 clk = ~clk;

  reg ctrl_wenable, ctrl_wdata;

  wire [3:0] vga_red;
  wire [3:0] vga_green;
  wire [3:0] vga_blue;
  wire h_sync;
  wire v_sync;

  video_unit keiki (
      .clk  (clk),
      .wclk (clk),
      .rst_n(rst_n),

      .tattr_wenable(1'b0),
      .pal_wenable  (1'b0),

      .ctrl_wdata  (ctrl_wdata),
      .ctrl_wenable(ctrl_wenable),

      .vga_red(vga_red),
      .vga_green(vga_green),
      .vga_blue(vga_blue),
      .h_sync(h_sync),
      .v_sync(v_sync)
  );

  initial begin
    $dumpvars(0, video_unit_tb);

    keiki.palette[0][0] = 12'h000;
    keiki.palette[0][1] = 12'hF00;
    keiki.palette[0][2] = 12'h0F0;
    keiki.palette[0][3] = 12'h00F;

    keiki.palette[1][0] = 12'hFFF;
    keiki.palette[1][1] = 12'h0FF;
    keiki.palette[1][2] = 12'hF0F;
    keiki.palette[1][3] = 12'hFF0;

    keiki.tattr_ram.data[0] = 8'bx000_1001;

    keiki.tdata_ram.data[(9*8)+0] = 16'h7E3C;
    keiki.tdata_ram.data[(9*8)+1] = 16'h4242;
    keiki.tdata_ram.data[(9*8)+2] = 16'h4242;
    keiki.tdata_ram.data[(9*8)+3] = 16'h4242;
    keiki.tdata_ram.data[(9*8)+4] = 16'h5E7E;
    keiki.tdata_ram.data[(9*8)+5] = 16'h0A7E;
    keiki.tdata_ram.data[(9*8)+6] = 16'h567C;
    keiki.tdata_ram.data[(9*8)+7] = 16'h7C38;

    ctrl_wdata = 1;
    clk = 1;
    rst_n = 0;
    #5 rst_n = 1;

    ctrl_wenable = 1;
    #10;
    ctrl_wenable = 0;

    #100_000 $finish();
  end
endmodule
