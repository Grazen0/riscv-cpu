#include "tachylib.h"
#include "num.h"
#include "tachyon.h"
#include <stddef.h>

void video_set_palette(const u16 palette[])
{
    for (size_t i = 0; i < 4; ++i)
        VPALETTE[i] = palette[i];
}

void video_clear_vram(void)
{
    for (size_t i = 0; i < VIDEO_VRAM_SIZE; ++i)
        VRAM[i] = 0;
}

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

static size_t audio_timer = 0;

void audio_init(void)
{
    audio_timer = 0;
    AUDIOCTRL->half_period = NOTE_NONE;
}

void audio_tick(void)
{
    if (audio_timer == 0)
        return;

    --audio_timer;

    if (audio_timer == 0)
        AUDIOCTRL->half_period = NOTE_NONE;
}

void audio_play_note(const MusicNote note, const size_t duration)
{
    AUDIOCTRL->half_period = note;
    audio_timer = duration;
}

static u64 rand_state[4];

static u64 u64_from_trng(void)
{
    const u64 lo = TRNG;
    const u64 hi = TRNG;

    return lo | (hi << 32);
}

void rand_seed(void)
{
    bool zero = true;

    for (size_t i = 0; i < 4; ++i) {
        rand_state[i] = u64_from_trng();
        if (rand_state[i] != 0)
            zero = false;
    }

    // Care should be taken to not allow the initial state to be 0,
    // which is impossible to escape from.
    if (zero)
        rand_state[0] = 0xDEADBEEF;
}

static u64 rol64(const uint64_t x, const size_t k)
{
    return (x << k) | (x >> (64 - k));
}

u64 rand_get(void)
{
    // Credit: https://en.wikipedia.org/wiki/Xorshift#xoshiro256++
    const u64 result = rol64(rand_state[0] + rand_state[3], 23) + rand_state[0];
    const u64 t = rand_state[1] << 17;

    rand_state[2] ^= rand_state[0];
    rand_state[3] ^= rand_state[1];
    rand_state[1] ^= rand_state[2];
    rand_state[0] ^= rand_state[3];

    rand_state[2] ^= t;
    rand_state[3] = rol64(rand_state[3], 45);

    return result;
}
