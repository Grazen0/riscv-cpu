`default_nettype none

// Consecutive writes don't work. Careful!
module lcd_unit (
    input wire clk,
    input wire rst_n,

    input wire rs,
    input wire [7:0] wdata,
    input wire wenable,

    output reg [7:0] lcd_data,
    output reg [1:0] lcd_ctrl,
    output reg lcd_enable
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lcd_data   <= 0;
      lcd_ctrl   <= 2'b00;
      lcd_enable <= 0;
    end else begin
      if (wenable) begin
        lcd_data   <= wdata;
        lcd_ctrl   <= {rs, 1'b0};
        lcd_enable <= 1;
      end else begin
        lcd_enable <= 0;
      end
    end
  end
endmodule
