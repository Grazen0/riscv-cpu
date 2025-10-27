`default_nettype none

module top_pl (
    input wire clk,
    input wire rst_n,

    output wire clk_out,
    output tri [7:0] lcd_data,
    output reg [1:0] lcd_ctrl,
    output reg lcd_enable
);
  clk_divider #(
      .PERIOD(400_000)
  ) divider (
      .clk_in (clk),
      .rst_n  (rst_n),
      .clk_out(clk_out)
  );

  wire [31:0] instr_data;
  wire [31:0] instr_addr;

  wire [31:0] data_addr, data_wdata, data_rdata;
  wire [3:0] data_wenable;

  dual_memory memory (
      .clk(clk_out),

      .addr_1(data_addr),
      .rdata_1(data_rdata),
      .wdata_1(data_wdata),
      .wenable_1(data_wenable & {4{~data_addr[31]}}),

      .addr_2 (instr_addr),
      .rdata_2(instr_data)
  );

  pipelined_cpu cpu (
      .clk  (clk_out),
      .rst_n(rst_n),

      .instr_addr(instr_addr),
      .instr_data(instr_data),

      .data_addr(data_addr),
      .data_wdata(data_wdata),
      .data_wenable(data_wenable),
      .data_rdata(data_rdata)
  );

  reg [7:0] lcd_data_out;

  // NOTE: consecutive writes don't work. Careful!
  always @(posedge clk_out or negedge rst_n) begin
    if (!rst_n) begin
      lcd_data_out <= 0;
      lcd_ctrl <= 2'b00;
      lcd_enable <= 0;
    end else begin
      if (data_wenable[0] && data_addr[31]) begin
        lcd_data_out <= data_wdata[7:0];
        lcd_ctrl <= {data_addr[0], 1'b0};
        lcd_enable <= 1;
      end else begin
        lcd_enable <= 0;
      end
    end
  end

  assign lcd_data = lcd_ctrl[0] ? 8'bxxxx_xxxx : lcd_data_out;
endmodule
