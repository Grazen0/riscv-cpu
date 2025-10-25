#include "lcd.h"
#include <stddef.h>
#include <stdlib.h>

void start(void)
{
    lcd_send_instr(LCD_CLEAR);
    lcd_send_instr(LCD_RETURN_HOME);
    lcd_send_instr(LCD_DISPLAY_CONTROL(LCDDC_DISPLAY | LCDDC_CURSOR | LCDDC_BLINK));

    int *arr_1 = malloc(sizeof(*arr_1) * 5);
    int *arr_2 = malloc(sizeof(*arr_2) * 8);
    int *arr_3 = malloc(sizeof(*arr_3) * 2);

    lcd_print("Hello, world!");
}
