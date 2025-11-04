// 800x600 @ 72 Hz
module video_unit (
    input wire clk,
    input wire wclk,
    input wire rst_n,

    input wire [$clog2(VRAM_SIZE)-1:0] vram_addr,
    input wire [7:0] vram_wdata,
    input wire vram_wenable,
    output wire [7:0] vram_rdata,

    input wire [1:0] palette_addr,
    input wire [11:0] palette_wdata,
    input wire palette_wenable,
    output wire [11:0] palette_rdata,

    input wire regs_wdata,
    input wire regs_wenable,

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

  reg display_on;
  reg [11:0] palette[0:3];

  assign palette_rdata = palette[palette_addr];

  // 28 is nicer than 25. Produces some leftover tiles, but sacrifices must be made.
  localparam TILES_H = 28;
  localparam TILES_V = 18;
  localparam TILES_TOTAL = TILES_H * TILES_V;
  localparam VRAM_SIZE = (TILES_TOTAL + 3) / 4;  // = ceil(total / 4)

  wire [7:0] vram_show_data;

  dual_byte_ram #(
      .SIZE(VRAM_SIZE)
  ) vram (
      .clk(wclk),

      .addr_1(vram_addr),
      .wdata_1(vram_wdata),
      .wenable_1(vram_wenable),
      .rdata_1(vram_rdata),

      .addr_2 (vram_show_addr),
      .rdata_2(vram_show_data)
  );

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

  always @(posedge wclk) begin
    if (palette_wenable) begin
      palette[palette_addr] <= palette_wdata;
    end

    if (regs_wenable) begin
      display_on <= regs_wdata;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      display_on <= 0;

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
        vram.mem[2] <= vram.mem[2] + 1;
      end
    end
  end

  wire visible = h_visible & v_visible;
  wire [3:0] visible_mask = {4{visible & display_on}};

  wire [$clog2(VRAM_SIZE)-1:0] vram_show_addr = tile_idx[TILE_IDX_WIDTH-1:2];

  wire [1:0] byte_offset = tile_idx[1:0];
  wire [1:0] pal_idx = vram_show_data >> (2 * byte_offset);
  wire [11:0] cur_color = palette[pal_idx];

  assign vga_red   = cur_color[11:8] & visible_mask;
  assign vga_green = cur_color[7:4] & visible_mask;
  assign vga_blue  = cur_color[3:0] & visible_mask;
endmodule
