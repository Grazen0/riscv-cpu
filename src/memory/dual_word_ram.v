`default_nettype none

module dual_word_ram #(
    parameter SIZE_WORDS  = 2 ** 12,
    parameter SOURCE_FILE = "/home/jdgt/Code/utec/arqui/riscv-cpu/build/firmware/firmware.mem",
    parameter ADDR_WIDTH  = $clog2(4 * SIZE_WORDS)
) (
    input wire clk,

    input  wire [ADDR_WIDTH-1:0] addr_1,
    input  wire [          31:0] wdata_1,
    input  wire [           3:0] wenable_1,
    output wire [          31:0] rdata_1,

    input  wire [ADDR_WIDTH-1:0] addr_2,
    output wire [          31:0] rdata_2
);
  reg [31:0] data[0:SIZE_WORDS-1];

  wire [29:0] word_addr_1 = addr_1[ADDR_WIDTH-1:2];
  wire [1:0] offset_1 = addr_1[1:0];

  wire [29:0] word_addr_2 = addr_2[ADDR_WIDTH-1:2];
  wire [1:0] offset_2 = addr_2[1:0];

  reg [31:0] wvalue;

  always @(*) begin
    wvalue = data[word_addr_1];

    if (wenable_1[0]) wvalue[7+(8*offset_1)-:8] = wdata_1[7:0];
    if (wenable_1[1]) wvalue[15+(8*offset_1)-:8] = wdata_1[15:8];
    if (wenable_1[2]) wvalue[23+(8*offset_1)-:8] = wdata_1[23:16];
    if (wenable_1[3]) wvalue[31+(8*offset_1)-:8] = wdata_1[31:24];
  end

  always @(posedge clk) begin
    if (|wenable_1) data[word_addr_1] <= wvalue;
  end

  assign rdata_1 = data[word_addr_1] >> (8 * offset_1);
  assign rdata_2 = data[word_addr_2] >> (8 * offset_2);

  initial begin
    $readmemh(SOURCE_FILE, data);
  end
endmodule
