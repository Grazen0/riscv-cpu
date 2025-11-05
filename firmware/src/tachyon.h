#ifndef FIRMWARE_PERIPHERALS_H
#define FIRMWARE_PERIPHERALS_H

#include "num.h"
#include <stddef.h>

constexpr size_t CLOCK_FREQ = 50'000'000U;

constexpr u8 LCD_CLEAR = 0b0000'0001;
constexpr u8 LCD_RETURN_HOME = 0b0000'0010;

#define LCD_DISPLAY_CONTROL(opts) ((u8)(0b1000 | opts))

constexpr u8 LCDDC_DISPLAY = 0b100;
constexpr u8 LCDDC_CURSOR = 0b010;
constexpr u8 LCDDC_BLINK = 0b001;

constexpr size_t VIDEO_TILES_H = 28;
constexpr size_t VIDEO_TILES_H_VISIBLE = 25;
constexpr size_t VIDEO_TILES_V = 18;
constexpr size_t VIDEO_TILES_TOTAL = VIDEO_TILES_H * VIDEO_TILES_V;

constexpr size_t VIDEO_VRAM_SIZE = (VIDEO_TILES_TOTAL + 3) / 4; // = ceil(total / 4)
constexpr size_t VIDEO_PALETTE_SIZE = 4;

typedef struct {
    union {
        volatile u8 instr;
        volatile u8 status;
    };
    volatile u8 data;
} Lcd;

typedef struct {
    volatile bool display_on;
} VideoControl;

typedef struct {
    volatile u32 half_period;
} AudioControl;

constexpr u8 JP_CENTER = 1 << 0;
constexpr u8 JP_UP = 1 << 1;
constexpr u8 JP_LEFT = 1 << 2;
constexpr u8 JP_RIGHT = 1 << 3;
constexpr u8 JP_DOWN = 1 << 4;

constexpr size_t TRNG_BASE = 0x2000'0000;
constexpr size_t VRAM_BASE = 0x4000'0000;
constexpr size_t JOYPAD_BASE = 0x6000'0000;
constexpr size_t VPALETTE_BASE = 0x8000'0000;
constexpr size_t VCTRL_BASE = 0xA000'0000;
constexpr size_t LCD_BASE = 0xC000'0000;
constexpr size_t AUDIOCTRL_BASE = 0xE000'0000;

#define TRNG (*(volatile u32 *)TRNG_BASE)
#define VRAM ((volatile u8 *)VRAM_BASE)
#define JOYPAD (*(volatile u8 *)JOYPAD_BASE)
#define VPALETTE ((volatile u16 *)VPALETTE_BASE)
#define VCTRL ((VideoControl *)VCTRL_BASE)
#define LCD ((Lcd *)LCD_BASE)
#define AUDIOCTRL ((AudioControl *)AUDIOCTRL_BASE)

#endif
