#ifndef FIRMWARE_LCD_H
#define FIRMWARE_LCD_H

#include "num.h"
#include <stddef.h>

static constexpr u8 LCD_CLEAR = 0b0000'0001;
static constexpr u8 LCD_RETURN_HOME = 0b0000'0010;

#define LCD_DISPLAY_CONTROL(opts) ((u8)(0b1000 | opts))

static constexpr u8 LCDDC_DISPLAY = 0b100;
static constexpr u8 LCDDC_CURSOR = 0b010;
static constexpr u8 LCDDC_BLINK = 0b001;

typedef struct {
    union {
        volatile u8 instr;
        volatile u8 status;
    };
    volatile u8 data;
} LcdScreen;

static constexpr size_t LCD_BASE = 0xC000'0000;
#define LCD ((LcdScreen *)LCD_BASE)

void lcd_send_instr(u8 instr);

void lcd_print_char(char c);

void lcd_print(const char *restrict s);

void lcd_print_n(const char *restrict s, size_t size);

void lcd_print_int(int n);

void lcd_print_hex(u32 n);

#endif
