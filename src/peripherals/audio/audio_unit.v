`default_nettype none

module audio_unit #(
    parameter PWM_WIDTH = 8,
    parameter WAVE_DATA_SIZE = 256,
    parameter WAVE_DATA_SOURCE = "/home/jdgt/Code/utec/arqui/riscv-cpu/data/cosine.mem"
) (
    input wire clk,
    input wire rst_n,

    input wire [1:0] channel_sel,
    input wire pv_sel,

    input wire [31:0] wdata,
    input wire wenable,
    output reg [31:0] rdata,

    output wire [PWM_WIDTH:0] out
);
  localparam PWM_MAX = 2 ** PWM_WIDTH;
  localparam CHANNELS = 4;

  reg [       31:0] periods[0:CHANNELS-1];
  reg [PWM_WIDTH:0] volumes[0:CHANNELS-1];

  wire [31:0] ctr_1, ctr_2, ctr_3, ctr_4;

  reg [$clog2(WAVE_DATA_SIZE)-1:0] wave_data[0:WAVE_DATA_SIZE-1];

  integer i;

  always @(posedge clk) begin
    if (!rst_n) begin
      for (i = 0; i < CHANNELS; i = i + 1) begin
        periods[i] <= 0;
        volumes[i] <= PWM_MAX;
      end
    end else begin
      if (wenable) begin
        if (!pv_sel) begin
          periods[channel_sel] <= wdata;
        end else begin
          volumes[channel_sel] <= wdata[PWM_WIDTH:0];
        end
      end
    end
  end

  always @(*) begin
    if (!pv_sel) begin
      rdata = periods[channel_sel];
    end else begin
      rdata = {{(32 - PWM_WIDTH + 1) {1'b0}}, volumes[channel_sel]};
    end
  end

  counter cnt1 (
      .clk(clk),
      .rst_n(rst_n),
      .compare(periods[0]),
      .out(ctr_1)
  );

  counter cnt2 (
      .clk(clk),
      .rst_n(rst_n),
      .compare(periods[1]),
      .out(ctr_2)
  );

  counter cnt3 (
      .clk(clk),
      .rst_n(rst_n),
      .compare(periods[2]),
      .out(ctr_3)
  );

  counter cnt4 (
      .clk(clk),
      .rst_n(rst_n),
      .compare(periods[3]),
      .out(ctr_4)
  );


  wire channel_1 = periods[0] != 0 && ctr_1 >= (periods[0] / 2);
  wire channel_2 = periods[1] != 0 && ctr_2 >= (periods[1] / 2);
  wire [31:0] channel_3 = (periods[2] == 0) ? 0 : ctr_3;

  wire [$clog2(WAVE_DATA_SIZE)-1:0] wave_idx = (ctr_4 * (WAVE_DATA_SIZE - 1)) / (periods[3] - 1);
  wire [7:0] channel_4 = wave_data[wave_idx];

  wire [PWM_WIDTH+1:0] channel_1_norm = channel_1 ? volumes[0] : 0;
  wire [PWM_WIDTH+1:0] channel_2_norm = channel_2 ? volumes[1] : 0;
  wire [PWM_WIDTH+1:0] channel_3_norm = (channel_3 * volumes[2]) / (periods[2] - 1);
  wire [PWM_WIDTH+1:0] channel_4_norm = (channel_4 * volumes[3]) / 255;

  wire [PWM_WIDTH+2:0] sum = channel_1_norm + channel_2_norm + channel_3_norm + channel_4_norm;
  assign out = sum / 4;

  initial begin
    $readmemh(WAVE_DATA_SOURCE, wave_data);
  end
endmodule
