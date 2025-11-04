#include "num.h"
#include "tachyon.h"
#include <stddef.h>
#include <stdint.h>

typedef enum : u8 {
    COLOR_BLACK = 0,
    COLOR_RED = 1,
    COLOR_GREEN = 2,
    COLOR_WHITE = 3,
} Color;

static const uint16_t palette_data[] = {
    0x000, // black
    0xF00, // red
    0x0F0, // green
    0xFFF, // white
};

#define FREQ_TO_HALF_PERIOD(freq) (100'000'000U / (2 * freq));

static constexpr size_t NOTE_A4 = FREQ_TO_HALF_PERIOD(392);

static bool enable_irq = false;

typedef enum : u8 {
    DIR_UP,
    DIR_RIGHT,
    DIR_DOWN,
    DIR_LEFT,
} Direction;

typedef struct {
    uint8_t y;
    uint8_t x;
} Position;

static constexpr size_t SNAKE_CAPACITY = VIDEO_TILES_H_VISIBLE * VIDEO_TILES_V;
static Position snake[SNAKE_CAPACITY];
static size_t snake_size;
static Direction snake_dir;
static Position apple;

static void set_tile(const Position *const tile_pos, const u8 color)
{
    const size_t tile_idx = (VIDEO_TILES_H * tile_pos->y) + tile_pos->x;

    const size_t byte_idx = tile_idx / 4;
    const size_t rem = tile_idx % 4;

    const u8 cur_byte = VRAM->data[byte_idx];
    const size_t bit_offset = 2 * rem;

    VRAM->data[byte_idx] = (cur_byte & ~(0b11 << bit_offset)) | (color << bit_offset);
}

static Direction dir_next = DIR_RIGHT;

static void game_tick(void)
{
    lcd_print("tick!\n");

    lcd_print("new dir: ");
    lcd_print_hex(dir_next);
    lcd_print("\n");

    lcd_print("\n");

    snake_dir = dir_next;

    set_tile(&snake[snake_size - 1], COLOR_BLACK);

    for (size_t i = 1; i < snake_size - 1; ++i)
        snake[i] = snake[i - 1];

    switch (snake_dir) {
    case DIR_RIGHT:
        ++snake[0].x;
        break;
    case DIR_LEFT:
        --snake[0].x;
        break;
    case DIR_UP:
        --snake[0].y;
        break;
    case DIR_DOWN:
        ++snake[0].y;
        break;
    }

    AUDIO->half_period = snake[0].x;
    set_tile(&snake[0], COLOR_WHITE);
}

void irq_handler(void) __attribute__((section(".irq_handler"), used, noinline, interrupt));

void irq_handler(void)
{
    static size_t timer = 0;

    if (!enable_irq)
        return;

    game_tick();
}

void start(void)
{
    AUDIO->half_period = NOTE_A4;
    VREGS->display_on = true;

    video_set_palette(palette_data);
    video_clear_vram();

    lcd_send_instr(LCD_CLEAR);
    lcd_send_instr(LCD_RETURN_HOME);
    lcd_send_instr(LCD_DISPLAY_CONTROL(LCDDC_DISPLAY | LCDDC_CURSOR | LCDDC_BLINK));

    // Initialize game
    snake[0] = (Position){.y = 0, .x = 0};
    snake_size = 1;
    snake_dir = DIR_RIGHT;
    dir_next = snake_dir;
    apple = (Position){.y = 12, .x = 10};

    set_tile(&snake[0], COLOR_WHITE);

    VREGS->display_on = true;
    enable_irq = true;
}

void loop(void)
{
    const u8 joypad = JOYPAD->data;

    if (snake_dir != DIR_DOWN && (joypad & JP_UP) != 0)
        dir_next = DIR_UP;
    else if (snake_dir != DIR_RIGHT && (joypad & JP_LEFT) != 0)
        dir_next = DIR_LEFT;
    else if (snake_dir != DIR_LEFT && (joypad & JP_RIGHT) != 0)
        dir_next = DIR_RIGHT;
    else if (snake_dir != DIR_UP && (joypad & JP_DOWN) != 0)
        dir_next = DIR_DOWN;
}
