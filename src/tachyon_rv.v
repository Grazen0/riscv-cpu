`default_nettype none

module tachyon_rv (
    input wire clk,
    input wire clk_vga,
    input wire rst_n,

    input wire [4:0] joypad,

    output wire [7:0] lcd_data,
    output wire [1:0] lcd_ctrl,
    output wire lcd_enable,

    output wire [3:0] vga_red,
    output wire [3:0] vga_green,
    output wire [3:0] vga_blue,
    output wire h_sync,
    output wire v_sync,

    output wire audio_out
);
  localparam SEL_RAM = 3'd0;
  localparam SEL_TRNG = 3'd1;
  localparam SEL_VRAM = 3'd2;
  localparam SEL_JOYPAD = 3'd3;
  localparam SEL_VPALETTE = 3'd4;
  localparam SEL_VCTRL = 3'd5;
  localparam SEL_LCD = 3'd6;
  localparam SEL_AUDIO = 3'd7;

  wire [31:0] instr_data;
  wire [31:0] instr_addr;

  wire [31:0] data_addr, data_wdata;
  wire [ 3:0] data_wenable;
  wire [31:0] mem_rdata;

  wire [31:0] trng_rdata;

  trng seija (
      .clk(clk),
      .out(trng_rdata)
  );

  dual_word_ram #(
      .SOURCE_FILE("/home/jdgt/Code/utec/arqui/riscv-cpu/data/firmware.mem")
  ) patchy (
      .clk(clk),

      .addr_1   (data_addr[11:0]),
      .wdata_1  (data_wdata),
      .wenable_1(data_wenable & {4{data_select == SEL_RAM}}),
      .rdata_1  (mem_rdata),

      .addr_2 (instr_addr[11:0]),
      .rdata_2(instr_data)
  );

  reg [ 2:0] data_select;
  reg [31:0] data_rdata;

  always @(*) begin
    casez (data_addr[31:29])
      3'b000:  data_select = SEL_RAM;
      3'b001:  data_select = SEL_TRNG;
      3'b010:  data_select = SEL_VRAM;
      3'b011:  data_select = SEL_JOYPAD;
      3'b100:  data_select = SEL_VPALETTE;
      3'b101:  data_select = SEL_VCTRL;
      3'b110:  data_select = SEL_LCD;
      3'b111:  data_select = SEL_AUDIO;
      default: data_select = {32{1'bx}};
    endcase

    case (data_select)
      SEL_RAM:      data_rdata = mem_rdata;
      SEL_TRNG:     data_rdata = trng_rdata;
      SEL_VRAM:     data_rdata = {24'b0, vram_rdata};
      SEL_JOYPAD:   data_rdata = {27'b0, joypad};
      SEL_VPALETTE: data_rdata = {20'b0, palette_rdata};
      SEL_LCD:      data_rdata = {24'b0, lcd_data};
      SEL_AUDIO:    data_rdata = audio_rdata;
      default:      data_rdata = {32{1'bx}};
    endcase
  end

  pipelined_cpu koishi (
      .clk  (clk),
      .rst_n(rst_n),

      .instr_addr(instr_addr),
      .instr_data(instr_data),

      .data_addr   (data_addr),
      .data_wdata  (data_wdata),
      .data_wenable(data_wenable),
      .data_rdata  (data_rdata),

      .irq(~h_sync)
  );

  wire [ 7:0] vram_rdata;
  wire [11:0] palette_rdata;

  video_unit keiki (
      .clk  (clk_vga),
      .wclk (clk),
      .rst_n(rst_n),

      .vram_addr(data_addr[6:0]),
      .vram_wdata(data_wdata[7:0]),
      .vram_wenable(data_wenable[0] && data_select == SEL_VRAM),
      .vram_rdata(vram_rdata),

      .palette_addr   (data_addr[2:1]),
      .palette_wdata  (data_wdata[11:0]),
      .palette_wenable(&data_wenable[1:0] && data_select == SEL_VPALETTE),
      .palette_rdata  (palette_rdata),

      .regs_wdata  (data_wdata[0]),
      .regs_wenable(data_wenable[0] && data_select == SEL_VCTRL),

      .vga_red  (vga_red),
      .vga_green(vga_green),
      .vga_blue (vga_blue),
      .h_sync   (h_sync),
      .v_sync   (v_sync)
  );

  lcd_unit nitori (
      .clk  (clk),
      .rst_n(rst_n),

      .rs(data_addr[0]),
      .wdata(data_wdata[7:0]),
      .wenable(data_wenable && data_select == SEL_LCD),

      .lcd_data  (lcd_data),
      .lcd_ctrl  (lcd_ctrl),
      .lcd_enable(lcd_enable)
  );

  wire [31:0] audio_rdata;

  audio_unit raiko (
      .clk  (clk),
      .rst_n(rst_n),

      .wenable(|data_wenable && data_select == SEL_AUDIO),
      .wdata  (data_wdata),
      .rdata  (audio_rdata),

      .out(audio_out)
  );
endmodule
