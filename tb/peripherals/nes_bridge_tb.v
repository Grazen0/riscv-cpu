`default_nettype none `timescale 1ns / 1ps

module nes_bridge_tb ();
  reg clk, rst_n;
  always #5 clk = ~clk;

  wire scl, sda;
  wire [7:0] joypad_data;

  nes_bridge bridge (
      .clk  (clk),
      .rst_n(rst_n),

      // .wdata(),
      // .wenable(),

      .scl(scl),
      .sda(sda),

      .joypad_data(joypad_data)
  );

  initial begin
    $dumpvars(0, nes_bridge_tb);

    clk   = 1;
    rst_n = 0;
    #5 rst_n = 1;

    #1000 $finish();
  end
endmodule
