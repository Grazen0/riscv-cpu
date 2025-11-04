#ifndef FIRMWARE_VIDEO_H
#define FIRMWARE_VIDEO_H

#include <stddef.h>
#include <stdint.h>

static constexpr size_t VIDEO_TILES_H = 28;
static constexpr size_t VIDEO_TILES_V = 18;
static constexpr size_t VIDEO_TILES_TOTAL = VIDEO_TILES_H * VIDEO_TILES_V;

static constexpr size_t VIDEO_VRAM_SIZE = (VIDEO_TILES_TOTAL + 3) / 4; // = ceil(total / 4)
static constexpr size_t VIDEO_PALETTE_SIZE = 4;

typedef struct {
    volatile uint8_t data[VIDEO_VRAM_SIZE];
} VideoVRam;

typedef struct {
    volatile uint16_t data[VIDEO_PALETTE_SIZE];
} VideoPaletteRam;

typedef struct {
    volatile bool display_on;
} VideoRegisters;

static constexpr size_t VRAM_BASE = 0x4000'0000;
#define VRAM ((VideoVRam *)VRAM_BASE)

static constexpr size_t PALETTE_BASE = 0x8000'0000;
#define PALETTE ((VideoPaletteRam *)PALETTE_BASE)

static constexpr size_t VREGS_BASE = 0xA000'0000;
#define VREGS ((VideoRegisters *)VREGS_BASE)

void video_set_palette(const uint16_t palette[]);

void video_clear_vram(void);

#endif
