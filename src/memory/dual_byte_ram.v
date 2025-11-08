`default_nettype none

module dual_byte_ram #(
    parameter SIZE = 2 ** 12,
    parameter ADDR_WIDTH = $clog2(SIZE)
) (
    input wire clk,

    input  wire [ADDR_WIDTH-1:0] addr_1,
    input  wire [           7:0] wdata_1,
    input  wire                  wenable_1,
    output wire [           7:0] rdata_1,

    input  wire [ADDR_WIDTH-1:0] addr_2,
    output wire [           7:0] rdata_2
);
  reg [7:0] data[0:SIZE-1];

  always @(posedge clk) begin
    if (wenable_1) data[addr_1] <= wdata_1;
  end

  assign rdata_1 = data[addr_1];
  assign rdata_2 = data[addr_2];
endmodule
