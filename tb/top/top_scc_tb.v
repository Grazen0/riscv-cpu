`timescale 1ns / 1ns `default_nettype none

module top_scc_tb ();
  reg clk, rst_n;
  always #5 clk = ~clk;

  wire clk_out;
  wire [7:0] lcd_data;
  wire [1:0] lcd_ctrl;
  wire lcd_enable;

  top_scc top (
      .clk  (clk),
      .rst_n(rst_n),

      .clk_out(clk_out),
      .lcd_data(lcd_data),
      .lcd_ctrl(lcd_ctrl),
      .lcd_enable(lcd_enable)
  );

  initial begin
    $dumpvars(0, top_scc_tb);

    $display("");

    clk   = 1;
    rst_n = 0;
    #1 rst_n = 1;

    #400;
    $display("");
    $display("");
    $finish();
  end
endmodule
