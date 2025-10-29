// 800x600 @ 72 Hz
module vga_controller (
    input wire clk,
    input wire rst_n,
    output wire [3:0] vga_red,
    output wire [3:0] vga_green,
    output wire [3:0] vga_blue,
    output reg h_sync,
    output reg v_sync
);
  localparam H_VISIBLE = 0;
  localparam H_FRONT = H_VISIBLE + 800;
  localparam H_SYNC = H_FRONT + 56;
  localparam H_BACK = H_SYNC + 120;
  localparam H_LINE = H_BACK + 64;

  localparam V_VISIBLE = 0;
  localparam V_FRONT = V_VISIBLE + 600;
  localparam V_SYNC = V_FRONT + 37;
  localparam V_BACK = V_SYNC + 6;
  localparam V_FRAME = V_BACK + 23;

  localparam BALL_SIZE = 20;

  reg [$clog2(V_FRAME):0] y_pos;
  reg [$clog2(H_LINE):0] x_pos;

  reg [7:0] ball_x;
  reg [7:0] ball_y;

  reg ball_intersect_x;
  reg ball_intersect_y;

  wire white = ball_intersect_x & ball_intersect_y;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x_pos <= 0;
      y_pos <= 0;
      h_sync <= 1;
      v_sync <= 1;

      ball_x <= 1;
      ball_y <= 1;

      ball_intersect_x <= 0;
      ball_intersect_y <= 0;
    end else begin

      if (x_pos != H_LINE - 1) begin
        x_pos <= x_pos + 1;
      end else begin
        x_pos <= 0;

        if (y_pos != V_FRAME - 1) begin
          y_pos <= y_pos + 1;
        end else begin
          y_pos <= 0;
        end

        if (y_pos + 1 == V_SYNC) begin
          v_sync <= 0;
        end else if (y_pos + 1 == V_BACK) begin
          // Frame finished
          ball_x <= ball_x + 1;
          ball_y <= ball_y + 1;
          v_sync <= 1;
        end

        if (y_pos + 1 == ball_y) begin
          ball_intersect_y <= 1;
        end else if (y_pos + 1 == ball_y + BALL_SIZE) begin
          ball_intersect_y <= 0;
        end
      end

      if (x_pos + 1 == H_SYNC) begin
        h_sync <= 0;
      end else if (x_pos + 1 == H_BACK) begin
        h_sync <= 1;
      end

      if (x_pos + 1 == ball_x) begin
        ball_intersect_x <= 1;
      end else if (x_pos + 1 == ball_x + BALL_SIZE) begin
        ball_intersect_x <= 0;
      end
    end
  end

  assign vga_red   = {4{white}};
  assign vga_green = {4{white}};
  assign vga_blue  = {4{white}};

endmodule
