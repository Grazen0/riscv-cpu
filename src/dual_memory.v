`default_nettype none

module dual_memory #(
    parameter SIZE = 2 ** 12,
    parameter ADDR_MASK = SIZE - 1
) (
    input wire clk,

    input wire [31:0] addr_1,
    input wire [31:0] addr_2,
    input wire [31:0] wdata_1,
    input wire [ 3:0] wenable_1,

    output wire [31:0] rdata_1,
    output wire [31:0] rdata_2
);
  reg [31:0] mem[0:SIZE-1];

  wire [29:0] word_addr_1 = addr_1[31:2] & ADDR_MASK[31:2];
  wire [1:0] offset_1 = addr_1[1:0];

  wire [29:0] word_addr_2 = addr_2[31:2] & ADDR_MASK[31:2];
  wire [1:0] offset_2 = addr_2[1:0];

  reg [31:0] wvalue;

  always @(*) begin
    wvalue = mem[word_addr_1];

    if (wenable_1[0]) wvalue[7+(8*offset_1)-:8] = wdata_1[7:0];
    if (wenable_1[1]) wvalue[15+(8*offset_1)-:8] = wdata_1[15:8];
    if (wenable_1[2]) wvalue[23+(8*offset_1)-:8] = wdata_1[23:16];
    if (wenable_1[3]) wvalue[31+(8*offset_1)-:8] = wdata_1[31:24];
  end

  always @(posedge clk) begin
    if (|wenable_1) mem[word_addr_1] <= wvalue;
  end

  assign rdata_1 = mem[word_addr_1] >> (8 * offset_1);
  assign rdata_2 = mem[word_addr_2] >> (8 * offset_2);

  integer i;

  initial begin
    $readmemh("/home/jdgt/Code/utec/arqui/riscv-cpu/data/firmware.mem", mem);
  end
endmodule
