#ifndef FIRMWARE_LCD_H
#define FIRMWARE_LCD_H

#include <stddef.h>
#include <stdint.h>

static constexpr uint8_t LCD_CLEAR = 0b0000'0001;
static constexpr uint8_t LCD_RETURN_HOME = 0b0000'0010;

#define LCD_DISPLAY_CONTROL(opts) ((uint8_t)(0b1000 | opts))
static constexpr uint8_t LCDDC_DISPLAY = 0b100;
static constexpr uint8_t LCDDC_CURSOR = 0b010;
static constexpr uint8_t LCDDC_BLINK = 0b001;

void lcd_send_instr(uint8_t instr);

void lcd_print_char(char c);

void lcd_print(const char *s);

void lcd_print_n(const char *s, size_t size);

void lcd_print_int(int n);

void lcd_print_hex(uint32_t n);

#endif
