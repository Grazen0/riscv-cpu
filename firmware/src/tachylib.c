#include "tachylib.h"
#include "num.h"
#include "tachyon.h"
#include <stddef.h>

void lcd_send_instr(const u8 instr)
{
    LCD->instr = instr;
}

void lcd_print_char(const char c)
{
    LCD->data = c;
}

void lcd_print(const char *restrict s)
{
    while (*s != '\0')
        lcd_print_char(*s++);
}

void lcd_print_n(const char *restrict s, size_t n)
{
    while (n-- > 0)
        lcd_print_char(*s++);
}

void lcd_print_int(const int n)
{
    if (n == 0) {
        lcd_print_char('0');
        return;
    }

    static constexpr size_t MAX_DIGITS = 10;
    const bool negative = n < 0;
    int value = negative ? -n : n;

    u8 digits[MAX_DIGITS];
    size_t i = MAX_DIGITS;

    while (value != 0) {
        --i;
        digits[i] = value % 10;
        value /= 10;
    }

    if (negative)
        lcd_print_char('-');

    for (size_t j = i; j < MAX_DIGITS; ++j)
        lcd_print_char('0' + digits[j]);
}

void lcd_print_hex(const u32 n)
{
    for (size_t i = 0; i < 8; ++i) {
        const u8 nib = (n >> (4 * (7 - i))) & 0xF;
        lcd_print_char(nib < 10 ? '0' + nib : 'A' + (nib - 10));
    }
}

void video_load_palette(const size_t pal_idx, const u16 palette[])
{
    for (size_t i = 0; i < VIDEO_PALETTE_SIZE; ++i)
        VPALETTE[(VIDEO_PALETTE_SIZE * pal_idx) + i] = palette[i];
}

void video_load_tdata(const size_t tdata_idx, const u16 data[])
{
    for (size_t i = 0; i < 8; ++i)
        VTDATA[(8 * tdata_idx) + i] = data[i];
}

void video_set_tile(const u8 tx, const u8 ty, const u8 tattr)
{
    VTATTR[(ty * VIDEO_TILES_H) + tx] = tattr;
}

static const AudioSequencePart *audio_seq = nullptr;
static size_t audio_seq_size;
static size_t audio_timer = 0;
static size_t audio_idx_next = 0;
static bool audio_playing;

void audio_init(void)
{
    AUDIO->half_period = NOTE_NONE;
    audio_seq = nullptr;
    audio_seq_size = 0;
    audio_timer = 0;
    audio_idx_next = 0;
    audio_playing = false;
}

void audio_play_note(const MusicNote note, const size_t duration)
{
    audio_seq = nullptr;
    audio_seq_size = 0;

    AUDIO->half_period = note;
    audio_timer = duration;
    audio_idx_next = 0;
    audio_playing = true;
}

void audio_tick(void)
{
    if (!audio_playing)
        return;

    if (audio_timer == 0) {
        if (audio_idx_next >= audio_seq_size) {
            // Finished
            AUDIO->half_period = NOTE_NONE;
            audio_seq = nullptr;
            audio_seq_size = 0;
            audio_playing = false;
        } else {
            // Next note
            const AudioSequencePart part = audio_seq[audio_idx_next];
            AUDIO->half_period = part.half_period;
            audio_timer = part.duration;

            ++audio_idx_next;
        }
    }

    --audio_timer;
}

void audio_play_sequence(const AudioSequencePart seq[], const size_t n)
{
    audio_seq = seq;
    audio_seq_size = n;
    audio_idx_next = 0;
    audio_timer = 0;
    audio_playing = true;
}

u8 joypad_read(void)
{
    while (!JOYPAD->ready) {
    }

    JOYPAD->start_read = 1;

    while (!JOYPAD->data_valid) {
    }

    return JOYPAD->data;
}
