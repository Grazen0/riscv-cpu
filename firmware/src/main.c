#include "lcd.h"
#include "video.h"
#include <stddef.h>
#include <stdint.h>

static const uint16_t palette_data[] = {
    0x000, // black
    0xF00, // red
    0x0F0, // green
    0x00F, // blue
};

void start(void)
{
    video_set_palette(palette_data);
    video_clear_vram();

    VRAM->data[0] = 0b00'01'10'11;
    VRAM->data[1] = 0b11'10'10'11;
    VRAM->data[2] = 0b11'11'11'11;
    VRAM->data[3] = 0b01'00'01'10;
    VRAM->data[4] = 0b01'00'01'10;
    VRAM->data[5] = 0b01'00'01'10;

    lcd_send_instr(LCD_CLEAR);
    lcd_send_instr(LCD_RETURN_HOME);
    lcd_send_instr(LCD_DISPLAY_CONTROL(LCDDC_DISPLAY | LCDDC_CURSOR | LCDDC_BLINK));

    static const char hello[] = "Hello, world!\n";
    lcd_print(hello);
    // lcd_print_hex(VRAM->data[4]);
}
