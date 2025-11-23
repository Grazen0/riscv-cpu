module matmul_control #(
    parameter SOURCE_FILE  = "/home/jdgt/Code/utec/arqui/riscv-cpu/data/matmul.mem",
    parameter PRG_CAPACITY = 2 ** 6
) (
    input wire clk,
    input wire rst_n,

    input wire start,

    input wire stall_f,

    output wire [31:0] instr,
    output wire done
);
  localparam ADR_WIDTH = $clog2(PRG_CAPACITY);

  reg [ADR_WIDTH-1:0] spc;
  reg [31:0] rom[0:PRG_CAPACITY-1];

  always @(posedge clk) begin
    if (!rst_n) begin
      spc <= 0;
    end else begin
      if (start) begin
        spc <= 0;
      end else if (!done && !stall_f) begin
        spc <= spc + 4;
      end
    end
  end

  assign done  = spc == (4 * prg_size);
  assign instr = rom[spc];

  integer i;
  integer prg_size;

  initial begin
    for (i = 0; i < PRG_CAPACITY; i = i + 1) begin
      rom[i] = 32'h0000_0000;
    end

    $readmemh(SOURCE_FILE, rom);

    begin : prg_measure
      for (i = 0; i < PRG_CAPACITY; i = i + 1) begin
        if (rom[i] == 32'h0000_0000) begin
          prg_size = i;
          disable prg_measure;
        end
      end
    end

  end
endmodule
