#ifndef FIRMWARE_PERIPHERALS_H
#define FIRMWARE_PERIPHERALS_H

#include "num.h"
#include <stddef.h>
#include <stdint.h>

static constexpr u8 LCD_CLEAR = 0b0000'0001;
static constexpr u8 LCD_RETURN_HOME = 0b0000'0010;

#define LCD_DISPLAY_CONTROL(opts) ((u8)(0b1000 | opts))

static constexpr u8 LCDDC_DISPLAY = 0b100;
static constexpr u8 LCDDC_CURSOR = 0b010;
static constexpr u8 LCDDC_BLINK = 0b001;

typedef struct {
    union {
        volatile u8 instr;
        volatile u8 status;
    };
    volatile u8 data;
} LcdScreen;

static constexpr size_t LCD_BASE = 0xC000'0000;
#define LCD ((LcdScreen *)LCD_BASE)

static constexpr size_t VIDEO_TILES_H = 28;
static constexpr size_t VIDEO_TILES_H_VISIBLE = 25;
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

typedef struct {
    volatile uint32_t half_period;
} AudioUnit;

static constexpr size_t AUDIO_BASE = 0xE000'0000;
#define AUDIO ((AudioUnit *)AUDIO_BASE)

typedef struct {
    uint8_t data;
} Joypad;

static constexpr size_t JOYPAD_BASE = 0x6000'0000;
#define JOYPAD ((Joypad *)JOYPAD_BASE)

static constexpr u8 JP_CENTER = 1 << 0;
static constexpr u8 JP_UP = 1 << 1;
static constexpr u8 JP_LEFT = 1 << 2;
static constexpr u8 JP_RIGHT = 1 << 3;
static constexpr u8 JP_DOWN = 1 << 4;

void lcd_send_instr(u8 instr);

void lcd_print_char(char c);

void lcd_print(const char *restrict s);

void lcd_print_n(const char *restrict s, size_t size);

void lcd_print_int(int n);

void lcd_print_hex(u32 n);

void video_set_palette(const uint16_t palette[]);

void video_clear_vram(void);

#endif
