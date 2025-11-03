`default_nettype none

module dual_word_rom #(
    parameter SIZE = 2 ** 12,
    parameter SOURCE_FILE = ""
) (
    input wire [ADDR_WIDTH-1:0] addr_1,
    output wire [31:0] rdata_1,

    input wire [ADDR_WIDTH-1:0] addr_2,
    output wire [31:0] rdata_2
);
  localparam ADDR_WIDTH = $clog2(SIZE);

  reg [31:0] data[0:SIZE-1];

  wire [29:0] word_addr_1 = addr_1[ADDR_WIDTH-1:2];
  wire [1:0] offset_1 = addr_1[1:0];

  wire [29:0] word_addr_2 = addr_2[ADDR_WIDTH-1:2];
  wire [1:0] offset_2 = addr_2[1:0];

  assign rdata_1 = data[word_addr_1] >> (8 * offset_1);
  assign rdata_2 = data[word_addr_2] >> (8 * offset_2);

  initial begin
    $readmemh(SOURCE_FILE, data);
  end
endmodule
