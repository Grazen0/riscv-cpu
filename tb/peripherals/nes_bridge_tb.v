`default_nettype none `timescale 1ns / 1ps

module nes_bridge_tb ();
  reg clk, rst_n;
  always #5 clk = ~clk;

  reg start;

  wire ready, data_valid;
  wire scl, sda;
  wire [7:0] joypad_data;

  nes_bridge bridge (
      .clk  (clk),
      .rst_n(rst_n),

      .start(start),

      .ready(ready),
      .joypad_rdata_valid(data_valid),
      .joypad_rdata(joypad_data),

      .scl(scl),
      .sda(sda)
  );

  initial begin
    $dumpvars(0, nes_bridge_tb);

    clk   = 1;
    rst_n = 0;
    start = 0;

    #5 rst_n = 1;

    #20 start = 1;
    #10 start = 0;

    #10_000 $finish();
  end
endmodule
