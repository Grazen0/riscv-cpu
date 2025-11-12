#ifndef FIRMWARE_TACHYLIB_H
#define FIRMWARE_TACHYLIB_H

#include "num.h"
#include "tachyon.h"
#include <stddef.h>

#define FREQ_TO_HALF_PERIOD(freq) (CLOCK_FREQ / (2 * freq))

typedef enum : u32 {
    NOTE_NONE = 0,
    NOTE_F3 = FREQ_TO_HALF_PERIOD(174),
    NOTE_G3 = FREQ_TO_HALF_PERIOD(196),
    NOTE_A3 = FREQ_TO_HALF_PERIOD(220),
    NOTE_B3 = FREQ_TO_HALF_PERIOD(246),
    NOTE_C4 = FREQ_TO_HALF_PERIOD(261),
    NOTE_D4 = FREQ_TO_HALF_PERIOD(293),
    NOTE_E4 = FREQ_TO_HALF_PERIOD(329),
    NOTE_F4 = FREQ_TO_HALF_PERIOD(349),
    NOTE_G4 = FREQ_TO_HALF_PERIOD(392),
    NOTE_A4 = FREQ_TO_HALF_PERIOD(440),
} MusicNote;

void lcd_send_instr(u8 instr);

void lcd_print_char(char c);

void lcd_print(const char *restrict s);

void lcd_print_n(const char *restrict s, size_t size);

void lcd_print_int(int n);

void lcd_print_hex(u32 n);

void video_init(void);

void video_load_palette(size_t pal_idx, const u16 palette[]);

void video_load_tdata(const size_t tdata_idx, const u16 data[]);

void video_set_tile(u8 tx, u8 ty, u8 tattr);

void audio_init(void);

void audio_tick(void);

void audio_play_note(MusicNote note, size_t duration);

u8 joypad_read(void);

#endif
