#include "num.h"
#include "rand.h"
#include "tachylib.h"
#include "tachyon.h"
#include <stddef.h>

// Ideas for VBlank use and draw buffering from https://www.nesdev.org/wiki/The_frame_and_NMIs

typedef enum : u8 {
    DIR_UP,
    DIR_RIGHT,
    DIR_DOWN,
    DIR_LEFT,
} Direction;

typedef struct {
    u8 x;
    u8 y;
} Position;

static constexpr u16 snake_palette[] = {
    0x000, // black
    0xFFF, // white
    0x00F, // blue
    0x11A, // darker blue
};

static constexpr u16 apple_palette[] = {
    0x000, // black
    0xFFF, // white
    0xF00, // red
    0x632, // brown-ish
};

static constexpr u8 TATTR_BACKGROUND = 0b0000'0000;
static constexpr u8 TATTR_APPLE = 0b0001'0010;

static constexpr u8 TATTR_SNAKE_HEAD[] = {
    // TODO: use correct tile data for up and down
    [DIR_UP] = 0b0000'0001,
    [DIR_RIGHT] = 0b0000'0001,
    [DIR_DOWN] = 0b1000'0001,
    [DIR_LEFT] = 0b1000'0001,
};

static constexpr size_t SNAKE_CAPACITY = VIDEO_TILES_H_VISIBLE * VIDEO_TILES_V;

static Position snake[SNAKE_CAPACITY];
static size_t snake_size;
static Direction snake_dir;
static Direction dir_next;
static Position apple;

typedef struct {
    u8 tx;
    u8 ty;
    u8 tattr;
} DrawBufEntry;

static constexpr size_t DRAW_BUF_CAPACITY = 16;

static DrawBufEntry draw_buf[DRAW_BUF_CAPACITY];
static size_t draw_buf_size = 0;

static void draw_buf_push(const u8 tx, const u8 ty, const u8 tattr)
{
    if (draw_buf_size >= DRAW_BUF_CAPACITY)
        return;

    draw_buf[draw_buf_size] = (DrawBufEntry){
        .tx = tx,
        .ty = ty,
        .tattr = tattr,
    };
    ++draw_buf_size;
}

static inline void draw_buf_flush(void)
{
    for (size_t i = 0; i < draw_buf_size; ++i) {
        const DrawBufEntry entry = draw_buf[i];
        VTATTR[(VIDEO_TILES_H * entry.ty) + entry.tx] = entry.tattr;
    }

    draw_buf_size = 0;
}

static inline void game_step(void)
{
    snake_dir = dir_next;

    const Position prev_tail = snake[snake_size - 1];

    for (size_t i = 1; i < snake_size; ++i)
        snake[i] = snake[i - 1];

    Position *const head = &snake[0];

    switch (snake_dir) {
    case DIR_RIGHT:
        if (head->x >= VIDEO_TILES_H_VISIBLE - 1)
            head->x = 0;
        else
            ++head->x;
        break;
    case DIR_LEFT:
        if (head->x == 0)
            head->x = VIDEO_TILES_H_VISIBLE - 1;
        else
            --head->x;
        break;
    case DIR_UP:
        if (head->y == 0)
            head->y = VIDEO_TILES_V - 1;
        else
            --head->y;
        break;
    case DIR_DOWN:
        if (head->y >= VIDEO_TILES_V - 1)
            head->y = 0;
        else
            ++head->y;
        break;
    }

    if (head->x == apple.x && head->y == apple.y) {
        // Ate an apple
        ++snake_size;
        snake[snake_size - 1] = prev_tail;

        // We need a new apple
        // TODO:generate random apple position
        ++apple.y;

        draw_buf_push(apple.x, apple.y, TATTR_APPLE);
        audio_play_note(NOTE_A4, 18);
    } else {
        draw_buf_push(prev_tail.x, prev_tail.y, TATTR_BACKGROUND);
    }

    draw_buf_push(snake[0].x, snake[0].y, TATTR_SNAKE_HEAD[snake_dir]);
}

static bool sleeping;

static void wait_frame(void (*const wait_fn)())
{
    sleeping = true;

    while (sleeping)
        (*wait_fn)();
}

static bool enable_irq;

__attribute__((interrupt)) void irq_handler(void)
{
    if (!enable_irq)
        return;

    draw_buf_flush();
    sleeping = false;
}

static void loop(void)
{
    rand_update();
}

// Runs at @ ~72 Hz
static inline void fixed_loop(void)
{
    audio_tick();

    const u8 joypad = 0;
    // const u8 joypad = joypad_read();

    lcd_print_hex(joypad);
    lcd_print("\n");

    if (snake_dir != DIR_DOWN && (joypad & JP_UP) == 0)
        dir_next = DIR_UP;
    else if (snake_dir != DIR_RIGHT && (joypad & JP_LEFT) == 0)
        dir_next = DIR_LEFT;
    else if (snake_dir != DIR_LEFT && (joypad & JP_RIGHT) == 0)
        dir_next = DIR_RIGHT;
    else if (snake_dir != DIR_UP && (joypad & JP_DOWN) == 0)
        dir_next = DIR_DOWN;

    static constexpr size_t STEP_DELAY = 1;
    static size_t step_timer = 0;

    ++step_timer;

    if (step_timer >= STEP_DELAY) {
        step_timer = 0;
        game_step();
    }
}

void main(void)
{
    enable_irq = false;
    VCTRL->display_on = false;

    audio_init();
    video_init();
    rand_seed();

    video_load_palette(0, snake_palette);
    video_load_palette(1, apple_palette);

    extern const u8 TDATA_BACKGROUND[];
    extern const u8 TDATA_SNAKE_HEAD_RIGHT[];
    extern const u8 TDATA_APPLE[];

    video_load_tdata(0, (const u16 *)TDATA_BACKGROUND);
    video_load_tdata(1, (const u16 *)TDATA_SNAKE_HEAD_RIGHT);
    video_load_tdata(2, (const u16 *)TDATA_APPLE);

    // Initialize game
    snake[0] = (Position){.y = 0, .x = 0};
    snake_size = 1;
    snake_dir = DIR_RIGHT;
    dir_next = snake_dir;
    apple = (Position){.y = 0, .x = 3};

    draw_buf_push(snake[0].x, snake[0].y, TATTR_SNAKE_HEAD[snake_dir]);
    draw_buf_push(apple.x, apple.y, TATTR_APPLE);

    draw_buf_flush();

    enable_irq = true;

    // Turn on display after next vblank
    wait_frame(rand_update);
    VCTRL->display_on = true;

    // Weeeeeeeeeeeeeeeeeee infinite loop
    while (true) {
        wait_frame(loop);
        fixed_loop();
    }
}
