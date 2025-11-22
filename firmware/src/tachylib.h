#ifndef FIRMWARE_TACHYLIB_H
#define FIRMWARE_TACHYLIB_H

#include "num.h"
#include "tachyon.h"
#include <stddef.h>

typedef struct {
    u32 note;
    u32 duration;
} AudioSequencePart;

#define FREQ_TO_PERIOD(freq) (CLOCK_FREQ / (freq))

typedef enum : u32 {
    NOTE_NONE = 0,
    NOTE_G1 = FREQ_TO_PERIOD(49),
    NOTE_A1 = FREQ_TO_PERIOD(55),
    NOTE_AS1 = FREQ_TO_PERIOD(58),
    NOTE_B1 = FREQ_TO_PERIOD(61),
    NOTE_C2 = FREQ_TO_PERIOD(65),
    NOTE_D2 = FREQ_TO_PERIOD(73),
    NOTE_E2 = FREQ_TO_PERIOD(82),
    NOTE_F2 = FREQ_TO_PERIOD(87),
    NOTE_G2 = FREQ_TO_PERIOD(98),
    NOTE_A2 = FREQ_TO_PERIOD(110),
    NOTE_AS2 = FREQ_TO_PERIOD(116),
    NOTE_C3 = FREQ_TO_PERIOD(130),
    NOTE_CS3 = FREQ_TO_PERIOD(138),
    NOTE_D3 = FREQ_TO_PERIOD(146),
    NOTE_DS3 = FREQ_TO_PERIOD(155),
    NOTE_E3 = FREQ_TO_PERIOD(164),
    NOTE_F3 = FREQ_TO_PERIOD(174),
    NOTE_G3 = FREQ_TO_PERIOD(196),
    NOTE_A3 = FREQ_TO_PERIOD(220),
    NOTE_B3 = FREQ_TO_PERIOD(246),
    NOTE_C4 = FREQ_TO_PERIOD(261),
    NOTE_D4 = FREQ_TO_PERIOD(293),
    NOTE_E4 = FREQ_TO_PERIOD(329),
    NOTE_F4 = FREQ_TO_PERIOD(349),
    NOTE_G4 = FREQ_TO_PERIOD(392),
    NOTE_A4 = FREQ_TO_PERIOD(440),
    NOTE_AS4 = FREQ_TO_PERIOD(466),
    NOTE_B4 = FREQ_TO_PERIOD(493),
    NOTE_C5 = FREQ_TO_PERIOD(523),
    NOTE_CS5 = FREQ_TO_PERIOD(554),
    NOTE_D5 = FREQ_TO_PERIOD(587),
    NOTE_DS5 = FREQ_TO_PERIOD(622),
    NOTE_E5 = FREQ_TO_PERIOD(659),
    NOTE_F5 = FREQ_TO_PERIOD(698),
    NOTE_FS5 = FREQ_TO_PERIOD(739),
    NOTE_G5 = FREQ_TO_PERIOD(783),
    NOTE_GS5 = FREQ_TO_PERIOD(830),
    NOTE_A5 = FREQ_TO_PERIOD(880),
    NOTE_AS5 = FREQ_TO_PERIOD(932),
    NOTE_B5 = FREQ_TO_PERIOD(987),
    NOTE_C6 = FREQ_TO_PERIOD(1046),
    NOTE_CS6 = FREQ_TO_PERIOD(1108),
    NOTE_D6 = FREQ_TO_PERIOD(1174),
    NOTE_DS6 = FREQ_TO_PERIOD(1244),
    NOTE_E6 = FREQ_TO_PERIOD(1318),
    NOTE_F6 = FREQ_TO_PERIOD(1396),
} MusicNote;

void lcd_send_instr(u8 instr);

void lcd_print_char(char c);

void lcd_print(const char *restrict s);

void lcd_print_n(const char *restrict s, size_t size);

void lcd_print_int(int n);

void lcd_print_hex(u32 n);

void video_load_palette(size_t pal_idx, const u16 palette[]);

void video_load_tdata(const size_t tdata_idx, const u16 data[]);

void video_set_tile(u8 tx, u8 ty, u8 tattr);

void audio_init(void);

void audio_tick(void);

void audio_set_paused(size_t channel, bool paused);

void audio_set_volume(size_t channel, u16 volume);

void audio_play_note(size_t channel, MusicNote note, size_t duration);

void audio_play_sequence(size_t channel, const AudioSequencePart seq[], const size_t n, bool loop);

u8 joypad_read(void);

#endif
