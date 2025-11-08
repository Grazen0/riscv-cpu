`default_nettype none

module dual_hword_ram #(
    parameter SIZE_HWORDS = 2 ** 12,
    parameter ADDR_WIDTH = $clog2(2 * SIZE_HWORDS) 
) (
    input wire clk,

    input wire [ADDR_WIDTH-1:0] addr_1,
    input wire [15:0] wdata_1,
    input wire [1:0] wenable_1,
    output wire [15:0] rdata_1,

    input wire [ADDR_WIDTH-1:0] addr_2,
    output wire [15:0] rdata_2
);
  reg [15:0] data[0:SIZE_HWORDS-1];

  wire [ADDR_WIDTH-2:0] hword_addr_1 = addr_1[ADDR_WIDTH-1:1];
  wire offset_1 = addr_1[0];

  wire [ADDR_WIDTH-2:0] hword_addr_2 = addr_2[ADDR_WIDTH-1:1];
  wire offset_2 = addr_2[0];

  reg [15:0] wvalue;

  always @(*) begin
    wvalue = data[hword_addr_1];

    if (wenable_1[0]) wvalue[7+(8*offset_1)-:8] = wdata_1[7:0];
    if (wenable_1[1]) wvalue[15+(8*offset_1)-:8] = wdata_1[15:8];
  end

  always @(posedge clk) begin
    if (|wenable_1) data[hword_addr_1] <= wvalue;
  end

  assign rdata_1 = data[hword_addr_1] >> (8 * offset_1);
  assign rdata_2 = data[hword_addr_2] >> (8 * offset_2);
endmodule
