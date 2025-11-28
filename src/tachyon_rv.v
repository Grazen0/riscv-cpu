`default_nettype none

module tachyon_rv (
    input wire clk,
    input wire clk_vga,
    input wire rst_n,

    output wire joypad_scl_out,
    input  wire joypad_sda_in,
    output wire joypad_sda_out,

    output wire [7:0] lcd_data,
    output wire [1:0] lcd_ctrl,
    output wire       lcd_enable,

    output wire [3:0] vga_red,
    output wire [3:0] vga_green,
    output wire [3:0] vga_blue,
    output wire       h_sync,
    output wire       v_sync,

    output wire audio_out
);
  localparam SEL_RAM = 4'd0;
  localparam SEL_RNG = 4'd1;
  localparam SEL_VTATTR = 4'd2;
  localparam SEL_VTDATA = 4'd3;
  localparam SEL_JOYPAD = 4'd4;
  localparam SEL_VPAL = 4'd5;
  localparam SEL_VCTRL = 4'd6;
  localparam SEL_LCD = 4'd7;
  localparam SEL_AUDIO = 4'd8;

  wire rst_n_sync;

  synchronizer rst_synchronizer (
      .clk(clk),
      .in (rst_n),
      .out(rst_n_sync)
  );

  wire [31:0] instr_data;
  wire [31:0] instr_addr;

  wire [31:0] data_addr, data_wdata;
  wire [3:0] data_wenable;

  pipelined_cpu koishi (
      .clk  (clk),
      .rst_n(rst_n_sync),

      .instr_addr(instr_addr),
      .instr_data(instr_data),

      .data_addr   (data_addr),
      .data_wdata  (data_wdata),
      .data_wenable(data_wenable),
      .data_rdata  (data_rdata),

      .irq(~v_sync)
  );

  reg [ 3:0] data_select;
  reg [31:0] data_rdata;

  always @(*) begin
    casez (data_addr[31:28])
      4'b000z: data_select = SEL_RAM;
      4'b001z: data_select = SEL_RNG;
      4'b0100: data_select = SEL_VTATTR;
      4'b0101: data_select = SEL_VTDATA;
      4'b011z: data_select = SEL_JOYPAD;
      4'b100z: data_select = SEL_VPAL;
      4'b101z: data_select = SEL_VCTRL;
      4'b110z: data_select = SEL_LCD;
      4'b111z: data_select = SEL_AUDIO;
      default: data_select = {32{1'bx}};
    endcase

    case (data_select)
      SEL_RAM:    data_rdata = mem_rdata;
      SEL_RNG:    data_rdata = rng_data;
      SEL_VTATTR: data_rdata = {24'b0, tattr_rdata};
      SEL_VTDATA: data_rdata = {16'b0, tdata_rdata};
      SEL_JOYPAD: data_rdata = {24'b0, joypad_rdata};
      SEL_VPAL:   data_rdata = {20'b0, pal_rdata};
      SEL_LCD:    data_rdata = {24'b0, lcd_data};
      SEL_AUDIO:  data_rdata = audio_rdata;
      default:    data_rdata = {32{1'bx}};
    endcase
  end


  wire [31:0] mem_rdata;

  dual_word_ram #(
      .SOURCE_FILE("/home/jdgt/Code/utec/arqui/riscv-cpu/build/firmware/firmware.mem")
  ) patchy (
      .clk(clk),

      .addr_1   (data_addr[13:0]),
      .wdata_1  (data_wdata),
      .wenable_1(data_wenable & {4{data_select == SEL_RAM}}),
      .rdata_1  (mem_rdata),

      .addr_2 (instr_addr[13:0]),
      .rdata_2(instr_data)
  );

  wire [31:0] rng_data;

  rng seija (
      .clk(clk),
      .out(rng_data)
  );

  wire [ 7:0] tattr_rdata;
  wire [15:0] tdata_rdata;
  wire [11:0] pal_rdata;

  video_unit keiki (
      .clk  (clk_vga),
      .wclk (clk),
      .rst_n(rst_n_sync),

      .tattr_addr   (data_addr[8:0]),
      .tattr_wdata  (data_wdata[7:0]),
      .tattr_wenable(data_wenable[0] && data_select == SEL_VTATTR),
      .tattr_rdata  (tattr_rdata),

      .tdata_addr   (data_addr[7:0]),
      .tdata_wdata  (data_wdata[15:0]),
      .tdata_wenable(data_wenable[1:0] & {2{data_select == SEL_VTDATA}}),
      .tdata_rdata  (tdata_rdata),

      .pal_addr   (data_addr[4:1]),
      .pal_wdata  (data_wdata[11:0]),
      .pal_wenable(&data_wenable[1:0] && data_select == SEL_VPAL),
      .pal_rdata  (pal_rdata),

      .ctrl_wdata  (data_wdata[0]),
      .ctrl_wenable(data_wenable[0] && data_select == SEL_VCTRL),

      .vga_red  (vga_red),
      .vga_green(vga_green),
      .vga_blue (vga_blue),
      .h_sync   (h_sync),
      .v_sync   (v_sync)
  );

  lcd_unit nitori (
      .clk  (clk),
      .rst_n(rst_n_sync),

      .rs     (data_addr[0]),
      .wdata  (data_wdata[7:0]),
      .wenable(data_wenable[0] && data_select == SEL_LCD),

      .lcd_data  (lcd_data),
      .lcd_ctrl  (lcd_ctrl),
      .lcd_enable(lcd_enable)
  );

  wire [31:0] audio_rdata;
  wire [ 8:0] audio_duty;

  audio_unit raiko (
      .clk  (clk),
      .rst_n(rst_n_sync),

      .channel_sel(data_addr[4:3]),
      .pv_sel     (data_addr[2]),
      .wdata      (data_wdata),
      .wenable    (|data_wenable && data_select == SEL_AUDIO),
      .rdata      (audio_rdata),

      .out(audio_duty)
  );

  pwm_generator hina (
      .clk  (clk),
      .rst_n(rst_n_sync),

      .duty(audio_duty),
      .out (audio_out)
  );

  wire [7:0] joypad_rdata;

  nes_bridge sanae (
      .clk  (clk),
      .rst_n(rst_n_sync),

      .start(data_wenable[0] && data_select == SEL_JOYPAD),

      .rdata_addr(data_addr[1:0]),
      .rdata     (joypad_rdata),

      .scl_out(joypad_scl_out),
      .sda_in (joypad_sda_in),
      .sda_out(joypad_sda_out)
  );
endmodule
