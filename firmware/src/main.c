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

static constexpr u16 bg_palette[] = {
    0x000, // black
    0x000, // black
    0x000, // black
    0x666, // gray
};

static constexpr u8 TATTR_BACKGROUND = 0b0010'0000;
static constexpr u8 TATTR_WALL = 0b0010'0110;
static constexpr u8 TATTR_APPLE = 0b0001'0001;

static constexpr u8 TATTR_SNAKE_HEAD[] = {
    [DIR_UP] = 0b0100'0011,
    [DIR_RIGHT] = 0b0000'0010,
    [DIR_DOWN] = 0b0000'0011,
    [DIR_LEFT] = 0b1000'0010,
};

static constexpr u8 TATTR_SNAKE_BODY[] = {
    [DIR_UP] = 0b0100'0101,
    [DIR_RIGHT] = 0b0000'0100,
    [DIR_DOWN] = 0b0000'0101,
    [DIR_LEFT] = 0b1000'0100,
};

static constexpr size_t SNAKE_CAPACITY = VIDEO_TILES_H * VIDEO_TILES_V;

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
        video_set_tile(entry.tx, entry.ty, entry.tattr);
    }

    draw_buf_size = 0;
}

static inline void game_step(void)
{
    const Direction prev_dir = snake_dir;
    snake_dir = dir_next;

    const Position prev_tail = snake[snake_size - 1];

    for (size_t i = snake_size - 1; i > 0; --i)
        snake[i] = snake[i - 1];

    Position *const head = &snake[0];

    switch (snake_dir) {
    case DIR_RIGHT:
        if (head->x >= VIDEO_TILES_H - 1)
            head->x = 0;
        else
            ++head->x;
        break;
    case DIR_LEFT:
        if (head->x == 0)
            head->x = VIDEO_TILES_H - 1;
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

    if (snake_size >= 2)
        draw_buf_push(snake[1].x, snake[1].y, TATTR_SNAKE_BODY[prev_dir]);

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
static bool paused;

__attribute__((interrupt)) void irq_handler(void)
{
    if (!enable_irq)
        return;

    static i32 audio_timer = 0;
    static u32 audio_idx = 0;

    draw_buf_flush();
    sleeping = false;

    if (audio_timer-- <= 0) {
        switch (audio_idx) {
        case 0:
            audio_play_note(NOTE_E4, 30);
            audio_timer = 36;
            break;
        case 1:
            audio_play_note(NOTE_B3, 12);
            audio_timer = 18;
            break;
        case 2:
            audio_play_note(NOTE_C4, 12);
            audio_timer = 18;
            break;
        case 3:
            audio_play_note(NOTE_D4, 30);
            audio_timer = 36;
            break;
        case 4:
            audio_play_note(NOTE_C4, 12);
            audio_timer = 18;
            break;
        case 5:
            audio_play_note(NOTE_B3, 12);
            audio_timer = 18;
            break;
        case 6:
            audio_play_note(NOTE_A3, 30);
            audio_timer = 36;
            break;
        default:
            break;
        }

        ++audio_idx;
    }
}

static void loop(void)
{
    rand_update();
}

// Runs at @ ~72 Hz
static inline void fixed_loop(void)
{
    audio_tick();

    static u8 prev_joypad = 0xFF;

    const u8 joypad = joypad_read();
    const u8 joypad_pressed = ~prev_joypad | joypad;

    prev_joypad = joypad;

    const bool up = (joypad & JP_UP) == 0;
    const bool left = (joypad & JP_LEFT) == 0;
    const bool right = (joypad & JP_RIGHT) == 0;
    const bool down = (joypad & JP_DOWN) == 0;
    const bool select = (joypad & JP_SELECT) == 0;
    const bool start = (joypad & JP_START) == 0;
    const bool btn_a = (joypad & JP_A) == 0;
    const bool btn_b = (joypad & JP_B) == 0;

    const bool up_pressed = (joypad_pressed & JP_UP) == 0;
    const bool left_pressed = (joypad_pressed & JP_LEFT) == 0;
    const bool right_pressed = (joypad_pressed & JP_RIGHT) == 0;
    const bool down_pressed = (joypad_pressed & JP_DOWN) == 0;
    const bool select_pressed = (joypad_pressed & JP_SELECT) == 0;
    const bool start_pressed = (joypad_pressed & JP_START) == 0;
    const bool btn_a_pressed = (joypad_pressed & JP_A) == 0;
    const bool btn_b_pressed = (joypad_pressed & JP_B) == 0;

    if (paused) {
        if (start_pressed)
            paused = false;

        return;
    }

    if (start_pressed) {
        paused = true;
        return;
    }

    if (snake_dir != DIR_DOWN && up)
        dir_next = DIR_UP;
    else if (snake_dir != DIR_RIGHT && left)
        dir_next = DIR_LEFT;
    else if (snake_dir != DIR_LEFT && right)
        dir_next = DIR_RIGHT;
    else if (snake_dir != DIR_UP && down)
        dir_next = DIR_DOWN;

    static constexpr size_t STEP_DELAY = 18;
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
    video_load_palette(2, bg_palette);

    extern const u8 TDATA_BACKGROUND[];
    extern const u8 TDATA_APPLE[];
    extern const u8 TDATA_SNAKE_HEAD_RIGHT[];
    extern const u8 TDATA_SNAKE_HEAD_DOWN[];
    extern const u8 TDATA_SNAKE_BODY_RIGHT[];
    extern const u8 TDATA_SNAKE_BODY_DOWN[];
    extern const u8 TDATA_WALL[];

    video_load_tdata(0, (const u16 *)TDATA_BACKGROUND);
    video_load_tdata(1, (const u16 *)TDATA_APPLE);
    video_load_tdata(2, (const u16 *)TDATA_SNAKE_HEAD_RIGHT);
    video_load_tdata(3, (const u16 *)TDATA_SNAKE_HEAD_DOWN);
    video_load_tdata(4, (const u16 *)TDATA_SNAKE_BODY_RIGHT);
    video_load_tdata(5, (const u16 *)TDATA_SNAKE_BODY_DOWN);
    video_load_tdata(6, (const u16 *)TDATA_WALL);

    // Initialize game
    snake[0] = (Position){.y = 1, .x = 1};
    snake_size = 1;
    snake_dir = DIR_RIGHT;
    dir_next = snake_dir;
    apple = (Position){.y = 1, .x = 3};
    paused = false;

    video_set_tile(snake[0].x, snake[0].y, TATTR_SNAKE_HEAD[snake_dir]);
    video_set_tile(apple.x, apple.y, TATTR_APPLE);

    // Top and bottom borders
    for (size_t x = 0; x < VIDEO_TILES_H; ++x) {
        video_set_tile(x, 0, TATTR_WALL);
        video_set_tile(x, VIDEO_TILES_V - 1, TATTR_WALL);
    }

    // Left and right borders
    for (size_t y = 1; y < VIDEO_TILES_V - 1; ++y) {
        video_set_tile(0, y, TATTR_WALL);
        video_set_tile(VIDEO_TILES_H - 1, y, TATTR_WALL);
    }

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
