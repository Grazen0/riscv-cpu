// 800x600 @ 72 Hz
module vga_controller (
    input wire clk,
    input wire rst_n,

    input wire [$clog2(VRAM_SIZE)-1:0] vram_waddr,
    input wire [7:0] vram_wdata,

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

  reg [11:0] palette[0:3];

  // 28 is nicer than 25. Produces some leftover tiles, but sacrifices must be made.
  localparam TILES_H = 28;
  localparam TILES_V = 18;
  localparam TILES_TOTAL = TILES_H * TILES_V;
  localparam VRAM_SIZE = (TILES_TOTAL + 3) / 4;  // ceil(total / 4)

  reg [31:0] vram[0:VRAM_SIZE-1];

  integer i;

  initial begin
    palette[0] = 12'b0000_0000_0000;  // black
    palette[1] = 12'b1111_0000_0000;  // red
    palette[2] = 12'b0000_1111_0000;  // green
    palette[3] = 12'b0000_0000_1111;  // blue

    for (i = 0; i < VRAM_SIZE; i = i + 1) begin
      vram[i] = 32'b0;
    end

    vram[0] = 8'b00_01_10_11;
    vram[1] = 8'b00_01_10_11;
    vram[2] = 8'b00_01_10_11;
    vram[3] = 8'b00_01_10_11;
    vram[4] = 8'b11_10_01_00;
    vram[5] = 8'b11_10_01_00;
    vram[6] = 8'b11_10_01_00;
    vram[7] = 8'b11_10_01_00;
  end

  reg [$clog2(V_FRAME)-1:0] y_pos, y_pos_next;
  reg [$clog2(H_LINE)-1:0] x_pos, x_pos_next;
  reg h_visible, h_visible_next;
  reg v_visible, v_visible_next;

  reg h_sync_next, v_sync_next;

  localparam TILE_IDX_WIDTH = $clog2(TILES_TOTAL);
  reg [TILE_IDX_WIDTH-1:0] tile_idx_base, tile_idx_base_next;
  reg [TILE_IDX_WIDTH-1:0] tile_idx, tile_idx_next;

  always @(*) begin
    y_pos_next = y_pos;
    x_pos_next = x_pos + 1;

    tile_idx_base_next = tile_idx_base;
    tile_idx_next = tile_idx;

    h_visible_next = h_visible;
    v_visible_next = v_visible;

    if (x_pos[5] != x_pos_next[5] && h_visible) begin
      tile_idx_next = tile_idx + 1;
    end

    if (x_pos_next == H_FRONT) begin
      h_visible_next = 0;
    end else if (x_pos_next == H_LINE) begin
      // Next line
      h_visible_next = 1;

      x_pos_next = 0;
      y_pos_next = y_pos + 1;

      if (y_pos[5] != y_pos_next[5]) begin
        tile_idx_base_next = tile_idx_base + TILES_H;
      end

      if (y_pos_next == V_FRONT) begin
        v_visible_next = 0;
      end else if (y_pos_next == V_FRAME) begin
        // Next frame
        v_visible_next = 1;

        y_pos_next = 0;
        tile_idx_base_next = 0;
      end

      tile_idx_next = tile_idx_base_next;
    end

    case (x_pos_next)
      H_SYNC:  h_sync_next = 0;
      H_BACK:  h_sync_next = 1;
      default: h_sync_next = h_sync;
    endcase

    case (y_pos_next)
      V_SYNC:  v_sync_next = 0;
      V_BACK:  v_sync_next = 1;
      default: v_sync_next = v_sync;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x_pos <= 0;
      y_pos <= 0;

      h_sync <= 1;
      v_sync <= 1;

      tile_idx_base <= 0;
      tile_idx <= 0;

      h_visible <= 1;
      v_visible <= 1;
    end else begin
      x_pos <= x_pos_next;
      y_pos <= y_pos_next;

      h_sync <= h_sync_next;
      v_sync <= v_sync_next;

      tile_idx_base <= tile_idx_base_next;
      tile_idx <= tile_idx_next;

      h_visible <= h_visible_next;
      v_visible <= v_visible_next;

      // 72 Hz change on vram to test if the screen changes.
      if (y_pos != 0 && y_pos_next == 0) begin
        vram[2] <= vram[2] + 1;
      end
    end
  end

  wire visible = h_visible & v_visible;
  wire [3:0] visible_mask = {4{visible}};

  wire [$clog2(VRAM_SIZE)-1:0] vram_addr = tile_idx[TILE_IDX_WIDTH-1:2];
  wire [7:0] cur_byte = vram[vram_addr];

  wire [1:0] byte_offset = tile_idx[1:0];
  wire [1:0] pal_idx = cur_byte >> (2 * byte_offset);  // Should optimize to byte_offset << 1
  wire [11:0] cur_color = palette[pal_idx];

  assign vga_red   = cur_color[11:8] & visible_mask;
  assign vga_green = cur_color[7:4] & visible_mask;
  assign vga_blue  = cur_color[3:0] & visible_mask;
endmodule
