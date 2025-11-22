#ifndef FIRMWARE_TACHYON_H
#define FIRMWARE_TACHYON_H

#include "num.h"
#include <stddef.h>

constexpr size_t CLOCK_FREQ = 50'000'000U;

constexpr u8 LCD_CLEAR = 0b0000'0001;
constexpr u8 LCD_RETURN_HOME = 0b0000'0010;

#define LCD_DISPLAY_CONTROL(opts) ((u8)(0b1000 | opts))

constexpr u8 LCDDC_DISPLAY = 0b100;
constexpr u8 LCDDC_CURSOR = 0b010;
constexpr u8 LCDDC_BLINK = 0b001;

constexpr size_t VIDEO_TILES_H = 25;
constexpr size_t VIDEO_TILES_V = 19;
constexpr size_t VIDEO_TILES_TOTAL = VIDEO_TILES_H * VIDEO_TILES_V;

constexpr size_t VTATTR_SIZE = VIDEO_TILES_TOTAL;

constexpr size_t VIDEO_VPAL_SIZE = 4;
constexpr size_t VIDEO_PALETTE_SIZE = 4;

typedef struct {
    union {
        volatile u8 instr;
        volatile const u8 status;
    };
    volatile u8 data;
} Lcd;

typedef struct {
    volatile bool display_on;
} VideoControl;

constexpr size_t AUDIO_CHANNELS = 4;
constexpr u16 AUDIO_MAX_VOLUME = 256;

typedef struct {
    volatile u32 note;
    volatile u16 volume;
} AudioChannel;

typedef struct {
    AudioChannel channels[AUDIO_CHANNELS];
} AudioControl;

typedef struct {
    union {
        volatile u8 start_read;
        volatile const bool ready;
    };
    volatile const bool data_valid;
    volatile const u8 data;
} Joypad;

constexpr size_t VIDEO_TDATA_SIZE = 16 * 8;

constexpr u8 JP_RIGHT = 1 << 0;
constexpr u8 JP_LEFT = 1 << 1;
constexpr u8 JP_DOWN = 1 << 2;
constexpr u8 JP_UP = 1 << 3;
constexpr u8 JP_START = 1 << 4;
constexpr u8 JP_SELECT = 1 << 5;
constexpr u8 JP_B = 1 << 6;
constexpr u8 JP_A = 1 << 7;

constexpr size_t RNG_BASE = 0x2000'0000;
constexpr size_t VTATTR_BASE = 0x4000'0000;
constexpr size_t VTDATA_BASE = 0x5000'0000;
constexpr size_t JOYPAD_BASE = 0x6000'0000;
constexpr size_t VPALETTE_BASE = 0x8000'0000;
constexpr size_t VCTRL_BASE = 0xA000'0000;
constexpr size_t LCD_BASE = 0xC000'0000;
constexpr size_t AUDIO_BASE = 0xE000'0000;

#define RNG (*(volatile u32 *)RNG_BASE)
#define VTATTR ((volatile u8 *)VTATTR_BASE)
#define VTDATA ((volatile u16 *)VTDATA_BASE)
#define JOYPAD ((Joypad *)JOYPAD_BASE)
#define VPALETTE ((volatile u16 *)VPALETTE_BASE)
#define VCTRL ((VideoControl *)VCTRL_BASE)
#define LCD ((Lcd *)LCD_BASE)
#define AUDIO ((AudioControl *)AUDIO_BASE)

#endif
