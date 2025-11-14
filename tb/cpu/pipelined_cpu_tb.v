`timescale 1ns / 1ns `default_nettype none

module pipelined_cpu_tb ();
  reg clk, rst_n;
  always #5 clk = ~clk;

  wire [31:0] instr_addr;
  wire [31:0] data_addr;
  wire [31:0] data_wdata;
  wire [ 3:0] data_wenable;

  wire [31:0] instr_rdata;
  wire [31:0] data_rdata;

  dual_word_ram ram (
      .clk(clk),

      .addr_1(data_addr[13:0]),
      .wdata_1(data_wdata),
      .wenable_1(data_wenable),
      .rdata_1(data_rdata),

      .addr_2 (instr_addr[13:0]),
      .rdata_2(instr_rdata)
  );

  pipelined_cpu cpu (
      .clk  (clk),
      .rst_n(rst_n),

      .instr_addr(instr_addr),
      .instr_data(instr_rdata),

      .data_addr(data_addr),
      .data_wdata(data_wdata),
      .data_wenable(data_wenable),
      .data_rdata(data_rdata),

      .irq(1'b0)
  );

  always @(posedge clk) begin
    #1;
    if (data_wenable[0]) begin
      $display("mem write: %h at addr %h", data_wdata, data_addr);
    end
  end

  initial begin
    $dumpvars(0, pipelined_cpu_tb);

    clk   = 1;
    rst_n = 0;
    #5 rst_n = 1;

    #1000 $finish();
  end
endmodule
