`default_nettype none

module top_mcc (
    input wire clk,
    input wire rst_n,

    output wire clk_out,
    output reg [7:0] lcd_data,
    output reg [1:0] lcd_ctrl,
    output reg lcd_enable
);
  clk_divider #(
      .PERIOD(2)
  ) divider (
      .clk_in (clk),
      .rst_n  (rst_n),
      .clk_out(clk_out)
  );

  wire [31:0] mem_addr;
  wire [31:0] mem_rdata;
  wire [31:0] mem_wdata;
  wire [ 3:0] mem_wenable;

  dual_word_ram #(
      .SOURCE_FILE("/home/jdgt/Code/utec/arqui/riscv-cpu/data/firmware.mem")
  ) ram (
      .clk(clk),

      .addr_1(mem_addr[13:0]),
      .wdata_1(mem_wdata),
      .wenable_1(mem_wenable & {4{~mem_addr[31]}}),

      .rdata_1(mem_rdata)
  );

  multi_cycle_cpu cpu (
      .clk  (clk_out),
      .rst_n(rst_n),

      .mem_addr(mem_addr),
      .mem_wdata(mem_wdata),
      .mem_wenable(mem_wenable),
      .mem_rdata(mem_rdata)
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lcd_data   <= 0;
      lcd_ctrl   <= 0;
      lcd_enable <= 0;
    end else if (mem_wenable[0] && mem_addr[31]) begin
      case (mem_addr[1:0])
        2'b00: lcd_data <= mem_wdata[7:0];
        2'b01: lcd_ctrl <= mem_wdata[1:0];
        2'b10: lcd_enable <= mem_wdata[0];
        default: begin
        end
      endcase
    end
  end

  always @(negedge lcd_enable) begin
    if (lcd_ctrl == 2'b10) begin
      $write("%c", lcd_data);
    end
  end

endmodule
