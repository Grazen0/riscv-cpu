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
} LcdScreen;

typedef struct {
    volatile bool display_on;
} VideoControl;

typedef struct {
    volatile u32 half_period;
} AudioUnit;

#define FREQ_TO_HALF_PERIOD(freq) (CLOCK_FREQ / (2 * freq))

typedef enum : size_t {
    NOTE_NONE = 0,
    NOTE_A4 = FREQ_TO_HALF_PERIOD(392),
} MusicNote;

constexpr size_t LCD_BASE = 0xC000'0000;
constexpr size_t VRAM_BASE = 0x4000'0000;
constexpr size_t PALETTE_BASE = 0x8000'0000;
constexpr size_t VCTRL_BASE = 0xA000'0000;
constexpr size_t AUDIO_BASE = 0xE000'0000;
constexpr size_t JOYPAD_BASE = 0x6000'0000;
constexpr size_t TRNG_BASE = 0x4000'0000;

#define LCD ((LcdScreen *)LCD_BASE)
#define VPALETTE ((volatile u16 *)PALETTE_BASE)
#define VRAM ((volatile u8 *)VRAM_BASE)
#define VCTRL ((VideoControl *)VCTRL_BASE)
#define AUDIO ((AudioUnit *)AUDIO_BASE)
#define JOYPAD (*(volatile u8 *)JOYPAD_BASE)
#define TRNG (*(volatile u32 *)TRNG_BASE)

constexpr u8 JP_CENTER = 1 << 0;
constexpr u8 JP_UP = 1 << 1;
constexpr u8 JP_LEFT = 1 << 2;
constexpr u8 JP_RIGHT = 1 << 3;
constexpr u8 JP_DOWN = 1 << 4;

void lcd_send_instr(u8 instr);

void lcd_print_char(char c);

void lcd_print(const char *restrict s);

void lcd_print_n(const char *restrict s, size_t size);

void lcd_print_int(int n);

void lcd_print_hex(u32 n);

void video_set_palette(const u16 palette[]);

void video_clear_vram(void);

void audio_init(void);

void audio_tick(void);

void audio_play_note(MusicNote note, size_t duration);

void rand_seed(void);

u64 rand_get(void);

#endif
