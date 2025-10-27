#include "lcd.h"
#include <stddef.h>

void start(void)
{
    lcd_send_instr(LCD_CLEAR);
    lcd_send_instr(LCD_RETURN_HOME);
    lcd_send_instr(LCD_DISPLAY_CONTROL(LCDDC_DISPLAY | LCDDC_CURSOR | LCDDC_BLINK));

    lcd_print("Hello, world!");
}
