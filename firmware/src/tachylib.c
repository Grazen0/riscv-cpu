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

typedef struct {
    const AudioSequencePart *seq;
    u32 cur_note;
    size_t seq_size;
    size_t seq_idx_next;
    size_t timer;
    bool is_playing;
    bool loop;
    bool paused;
} AudioChannelPlayer;

static AudioChannelPlayer audio_ctrl[AUDIO_CHANNELS];

void audio_init(void)
{
    for (size_t i = 0; i < AUDIO_CHANNELS; ++i) {
        AUDIO->channels[i].note = NOTE_NONE;

        audio_ctrl[i] = (AudioChannelPlayer){
            .seq = nullptr,
            .cur_note = NOTE_NONE,
            .seq_size = 0,
            .seq_idx_next = 0,
            .timer = 0,
            .is_playing = false,
            .loop = false,
            .paused = false,
        };
    }
}

void audio_play_note(const size_t channel, const MusicNote note, const size_t duration)
{
    audio_ctrl[channel].seq = nullptr;
    audio_ctrl[channel].cur_note = note;
    audio_ctrl[channel].seq_size = 0;
    audio_ctrl[channel].seq_idx_next = 0;
    audio_ctrl[channel].timer = duration;
    audio_ctrl[channel].is_playing = true;

    AUDIO->channels[channel].note = note;
}

void audio_play_sequence(const size_t channel, const AudioSequencePart seq[], const size_t n,
                         const bool loop)
{
    audio_ctrl[channel].seq = seq;
    audio_ctrl[channel].seq_size = n;
    audio_ctrl[channel].seq_idx_next = 0;
    audio_ctrl[channel].timer = 0;
    audio_ctrl[channel].is_playing = true;
    audio_ctrl[channel].loop = loop;
}

void audio_set_paused(const size_t channel, const bool paused)
{
    audio_ctrl[channel].paused = paused;

    if (paused)
        AUDIO->channels[channel].note = NOTE_NONE;
    else
        AUDIO->channels[channel].note = audio_ctrl[channel].cur_note;
}

void audio_set_volume(const size_t channel, const u16 volume)
{
    AUDIO->channels[channel].volume = volume;
}

void audio_tick(void)
{
    for (size_t i = 0; i < AUDIO_CHANNELS; ++i) {
        AudioChannelPlayer *const ctrl = &audio_ctrl[i];

        if (!ctrl->is_playing || ctrl->paused)
            continue;

        if (ctrl->timer == 0) {
            if (ctrl->seq_idx_next >= ctrl->seq_size) {
                // Finished sound/sequence
                AUDIO->channels[i].note = NOTE_NONE;

                ctrl->seq = nullptr;
                ctrl->cur_note = NOTE_NONE;
                ctrl->seq_size = 0;
                ctrl->seq_idx_next = 0;
                ctrl->is_playing = false;
            } else {
                // Next sequence part
                const AudioSequencePart part = ctrl->seq[ctrl->seq_idx_next];
                AUDIO->channels[i].note = part.note;

                ctrl->cur_note = part.note;
                ctrl->timer = part.duration;
                ++ctrl->seq_idx_next;

                if (ctrl->loop && ctrl->seq_idx_next >= ctrl->seq_size)
                    ctrl->seq_idx_next = 0;
            }
        }

        if (ctrl->is_playing)
            --ctrl->timer;
    }
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
