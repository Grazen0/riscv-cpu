#include "lcd.h"
#include <stddef.h>
#include <stdint.h>

typedef struct Lcd {
    volatile uint8_t data;
    volatile uint8_t opts;
    volatile bool enable;
} Lcd;

static constexpr size_t LCD_BASE = 0x8000'0000;
#define LCD ((Lcd *)LCD_BASE)

static constexpr uint8_t LCD_WRITE_INSTR = 0b00;
static constexpr uint8_t LCD_WRITE_DATA = 0b10;

static inline void lcd_send(const uint8_t data)
{
    LCD->data = data;
    LCD->enable = true;
    LCD->enable = false;
}

void lcd_send_instr(const uint8_t instr)
{
    LCD->opts = LCD_WRITE_INSTR;
    lcd_send(instr);
}

void lcd_print_char(const char c)
{
    LCD->opts = LCD_WRITE_DATA;
    lcd_send(c);
}

void lcd_print(const char *restrict s)
{
    LCD->opts = LCD_WRITE_DATA;

    while (*s != '\0')
        lcd_send(*s++);
}

void lcd_print_n(const char *s, const size_t n)
{
    LCD->opts = LCD_WRITE_DATA;

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

    LCD->opts = LCD_WRITE_DATA;

    if (negative)
        lcd_send('-');

    for (size_t j = i; j < MAX_DIGITS; ++j)
        lcd_send('0' + digits[j]);
}

void lcd_print_hex(uint32_t n)
{
    LCD->opts = LCD_WRITE_DATA;

    for (size_t i = 0; i < 8; ++i) {
        const uint8_t nib = (n >> (4 * (7 - i))) & 0xF;
        lcd_send(nib < 10 ? '0' + nib : 'A' + (nib - 10));
    }
}
