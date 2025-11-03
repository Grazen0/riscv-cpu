#include "video.h"
#include <stddef.h>
#include <stdint.h>
#include <string.h>

void video_set_palette(const uint16_t palette[])
{
    for (size_t i = 0; i < 4; ++i)
        PALETTE->data[i] = palette[i];
}

void video_clear_vram(void)
{
    for (size_t i = 0; i < VIDEO_VRAM_SIZE; ++i)
        VRAM->data[i] = 0;
}
