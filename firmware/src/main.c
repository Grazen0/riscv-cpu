#include "num.h"
#include "tachyon.h"
#include <stddef.h>

typedef enum : u8 {
    COLOR_BLACK = 0,
    COLOR_RED = 1,
    COLOR_GREEN = 2,
    COLOR_WHITE = 3,
} Color;

static constexpr u16 palette_data[] = {
    0x000, // black
    0xF00, // red
    0x0F0, // green
    0xFFF, // white
};

typedef enum : u8 {
    DIR_UP,
    DIR_RIGHT,
    DIR_DOWN,
    DIR_LEFT,
} Direction;

typedef struct {
    u8 y;
    u8 x;
} Position;

static inline bool pos_equals(const Position a, const Position b)
{
    return a.x == b.x && a.y == b.y;
}

static void set_tile(const Position tile_pos, const u8 color)
{
    const size_t tile_idx = (VIDEO_TILES_H * tile_pos.y) + tile_pos.x;

    const size_t byte_idx = tile_idx / 4;
    const size_t rem = tile_idx % 4;

    const u8 cur_byte = VRAM[byte_idx];
    const size_t bit_offset = 2 * rem;

    VRAM[byte_idx] = (cur_byte & ~(0b11 << bit_offset)) | (color << bit_offset);
}

static constexpr size_t SNAKE_CAPACITY = VIDEO_TILES_H_VISIBLE * VIDEO_TILES_V;

static Position snake[SNAKE_CAPACITY];
static size_t snake_size;
static Direction snake_dir;
static Direction dir_next;
static Position apple;

static inline void game_step(void)
{
    snake_dir = dir_next;

    const Position prev_tail = snake[snake_size - 1];

    for (size_t i = 1; i < snake_size; ++i)
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

    if (pos_equals(snake[0], apple)) {
        // Ate an apple
        ++snake_size;
        snake[snake_size - 1] = prev_tail;

        // We need a new apple
        ++apple.y;
        set_tile(apple, COLOR_RED);

        audio_play_note(NOTE_A4, 2);
    } else {
        set_tile(prev_tail, COLOR_BLACK);
    }

    set_tile(snake[0], COLOR_WHITE);
}

static inline void game_tick(void)
{
    static constexpr size_t STEP_DELAY = 1;
    static size_t step_timer = 0;

    ++step_timer;

    if (step_timer >= STEP_DELAY) {
        step_timer = 0;
        game_step();
    }
}

static bool enable_irq = false;

__attribute__((interrupt)) void irq_handler(void)
{
    static size_t audio_timer;

    if (!enable_irq)
        return;

    audio_tick();
    game_tick();
}

void start(void)
{
    audio_init();

    AUDIO->half_period = NOTE_NONE;
    VCTRL->display_on = false;

    video_clear_vram();
    video_set_palette(palette_data);

    // lcd_send_instr(LCD_CLEAR);
    // lcd_send_instr(LCD_RETURN_HOME);
    // lcd_send_instr(LCD_DISPLAY_CONTROL(LCDDC_DISPLAY | LCDDC_CURSOR | LCDDC_BLINK));

    // Initialize game
    snake[0] = (Position){.y = 0, .x = 0};
    snake_size = 1;
    snake_dir = DIR_RIGHT;
    dir_next = snake_dir;
    apple = (Position){.y = 0, .x = 3};

    set_tile(snake[0], COLOR_WHITE);
    set_tile(apple, COLOR_RED);

    rand_seed();

    VCTRL->display_on = true;
    enable_irq = true;
}

void loop(void)
{
    rand_get(); // Update randomness

    const u8 joypad = JOYPAD;

    if (snake_dir != DIR_DOWN && (joypad & JP_UP) != 0)
        dir_next = DIR_UP;
    else if (snake_dir != DIR_RIGHT && (joypad & JP_LEFT) != 0)
        dir_next = DIR_LEFT;
    else if (snake_dir != DIR_LEFT && (joypad & JP_RIGHT) != 0)
        dir_next = DIR_RIGHT;
    else if (snake_dir != DIR_UP && (joypad & JP_DOWN) != 0)
        dir_next = DIR_DOWN;
}
