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

void lcd_print_n(const char *const restrict s, size_t n)
{
    for (size_t i = 0; i < n; ++i)
        lcd_print_char(s[i]);
}

void lcd_print_int(int n)
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

void lcd_print_hex(u32 n)
{
    for (size_t i = 0; i < 8; ++i) {
        const u8 nib = (n >> (4 * (7 - i))) & 0xF;
        lcd_print_char(nib < 10 ? '0' + nib : 'A' + (nib - 10));
    }
}

void video_init(void)
{
    for (size_t i = 0; i < VTATTR_SIZE; ++i)
        VTATTR[i] = 0;

    for (size_t i = 0; i < VIDEO_TDATA_SIZE; ++i)
        VTDATA[i] = 0;
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

static size_t audio_timer = 0;

void audio_init(void)
{
    audio_timer = 0;
    AUDIO->half_period = NOTE_NONE;
}

void audio_tick(void)
{
    if (audio_timer == 0)
        return;

    --audio_timer;

    if (audio_timer == 0)
        AUDIO->half_period = NOTE_NONE;
}

void audio_play_note(const MusicNote note, const size_t duration)
{
    AUDIO->half_period = note;
    audio_timer = duration;
}
