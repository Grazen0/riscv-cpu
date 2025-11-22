`default_nettype none `timescale 1ns / 1ps

module pwm_generator_tb ();
  reg clk, rst_n;
  always #5 clk = ~clk;

  wire out;

  pwm_generator pwm (
      .clk  (clk),
      .rst_n(rst_n),

      .duty(9'd3),

      .out(out)
  );

  initial begin
    $dumpvars(0, pwm_generator_tb);

    clk   = 1;
    rst_n = 0;
    #5 rst_n = 1;

    #1000 $finish();
  end
endmodule
