`timescale 1ns / 1ps `default_nettype none

module top_tb ();
  reg clk, rst_n;
  always #5 clk = ~clk;

  wire clk_out;
  wire [7:0] lcd_data;
  wire [1:0] lcd_ctrl;
  wire lcd_enable;

  always @(posedge clk or posedge rst_n) begin
    #1;
    // $display("pc = %h, t2 = %h, mem = %h %h %h %h", t.instr_addr, t.c.register_file.regs[7],
    //          t.ram.mem[0], t.ram.mem[1], t.ram.mem[2], t.ram.mem[3]);
  end

  top t (
      .clk  (clk),
      .rst_n(rst_n),

      .clk_out(clk_out),
      .lcd_data(lcd_data),
      .lcd_ctrl(lcd_ctrl),
      .lcd_enable(lcd_enable)
  );

  initial begin
    $dumpvars(0, top_tb);
    $dumpvars(0, top_tb.t.c.register_file.regs[10]);
    $dumpvars(0, top_tb.t.c.register_file.regs[15]);

    clk   = 1;
    rst_n = 0;
    #1 rst_n = 1;

    #5000 $finish();
  end
endmodule
