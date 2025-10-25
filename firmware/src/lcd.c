#include "lcd.h"
#include <stddef.h>
#include <stdint.h>

#define LCD_DATA (*(volatile uint8_t *)0x80000000)
#define LCD_OPTS (*(volatile uint8_t *)0x80000001)
#define LCD_ENABLE (*(volatile uint8_t *)0x80000002)

static constexpr uint8_t LCD_WRITE_INSTR = 0b00;
static constexpr uint8_t LCD_WRITE_DATA = 0b10;

static inline void lcd_send(const uint8_t data)
{
    LCD_DATA = data;
    LCD_ENABLE = 1;
    LCD_ENABLE = 0;
}

void lcd_send_instr(const uint8_t instr)
{
    LCD_OPTS = LCD_WRITE_INSTR;
    lcd_send(instr);
}

void lcd_print_char(const char c)
{
    LCD_OPTS = LCD_WRITE_DATA;
    lcd_send(c);
}

void lcd_print(const char *restrict s)
{
    LCD_OPTS = LCD_WRITE_DATA;

    while (*s != '\0')
        lcd_send(*s++);
}

void lcd_print_n(const char *s, const size_t n)
{
    LCD_OPTS = LCD_WRITE_DATA;

    for (size_t i = 0; i < n; ++i)
        lcd_send(*s++);
}

void lcd_print_int(int n)
{
    if (n == 0) {
        lcd_print_char('0');
        return;
    }

    static constexpr size_t MAX_DIGITS = 10;
    const bool negative = n < 0;
    long long value = negative ? -n : n;

    uint8_t digits[MAX_DIGITS];
    size_t i = MAX_DIGITS;

    while (value != 0) {
        --i;
        digits[i] = value % 10;
        value /= 10;
    }

    LCD_OPTS = LCD_WRITE_DATA;

    if (negative)
        lcd_send('-');

    for (size_t j = i; j < MAX_DIGITS; ++j)
        lcd_send('0' + digits[j]);
}

void lcd_print_hex(uint32_t n)
{
    LCD_OPTS = LCD_WRITE_DATA;

    for (size_t i = 0; i < 8; ++i) {
        const uint8_t nib = (n >> (4 * (7 - i))) & 0xF;
        lcd_send(nib < 10 ? '0' + nib : 'A' + (nib - 10));
    }
}
