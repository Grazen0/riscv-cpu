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

static inline Direction dir_opposite(const Direction dir)
{
    return (dir + 2) % 4;
}

typedef struct {
    u8 x;
    u8 y;
} Position;

typedef enum : u8 {
    PAL_SNAKE,
    PAL_APPLE,
    PAL_BG,
} PaletteIdx;

static constexpr u16 PALDATA_SNAKE[] = {
    0xAD5, // green
    0xFFF, // white
    0x47F, // blue
    0x149, // darker blue
};

static constexpr u16 PALDATA_SNAKE_LOSE[] = {
    0xAD5, // green
    0xFFF, // white
    0x777, // gray
    0x555, // darker gray
};

static constexpr u16 PALDATA_APPLE[] = {
    0xAD5, // green
    0xE42, // red
    0x975, // brown
    0x4C2, // dark green
};

static constexpr u16 PALDATA_BG[] = {
    0xAD5, // green
    0xAD5, // green
    0xAD5, // green
    0x583, // gray (for walls)
};

typedef enum : u8 {
    SPR_BACKGROUND,
    SPR_APPLE,
    SPR_SNAKE_HEAD_RIGHT,
    SPR_SNAKE_HEAD_DOWN,
    SPR_SNAKE_BODY_RIGHT,
    SPR_SNAKE_BODY_DOWN,
    SPR_WALL,
    SPR_SNAKE_BODY_TURN,
    SPR_SNAKE_TAIL_RIGHT,
    SPR_SNAKE_TAIL_DOWN,
} SpriteIdx;

// Calculates a tattr value based on:
// - Sprite index (4 bits)
// - Palette index (2 bits)
// - Extra flags (TF_FLIP_X or TF_FLIP_Y, 1 bit each)
#define MK_TATTR(spr_idx, pal_idx, flags) ((spr_idx) | ((pal_idx) << 4) | (flags))

static constexpr u8 TF_FLIP_X = 0b1000'0000;
static constexpr u8 TF_FLIP_Y = 0b0100'0000;

static constexpr u8 TATTR_BACKGROUND = MK_TATTR(SPR_BACKGROUND, PAL_BG, 0);
static constexpr u8 TATTR_WALL = MK_TATTR(SPR_WALL, PAL_BG, 0);
static constexpr u8 TATTR_APPLE = MK_TATTR(SPR_APPLE, PAL_APPLE, 0);

static constexpr u8 TATTR_SNAKE_HEAD[] = {
    [DIR_UP] = MK_TATTR(SPR_SNAKE_HEAD_DOWN, PAL_SNAKE, TF_FLIP_Y),
    [DIR_RIGHT] = MK_TATTR(SPR_SNAKE_HEAD_RIGHT, PAL_SNAKE, 0),
    [DIR_DOWN] = MK_TATTR(SPR_SNAKE_HEAD_DOWN, PAL_SNAKE, 0),
    [DIR_LEFT] = MK_TATTR(SPR_SNAKE_HEAD_RIGHT, PAL_SNAKE, TF_FLIP_X),
};

static constexpr u8 TATTR_SNAKE_BODY[] = {
    [DIR_UP] = MK_TATTR(SPR_SNAKE_BODY_DOWN, PAL_SNAKE, 0),
    [DIR_RIGHT] = MK_TATTR(SPR_SNAKE_BODY_RIGHT, PAL_SNAKE, 0),
    [DIR_DOWN] = MK_TATTR(SPR_SNAKE_BODY_DOWN, PAL_SNAKE, 0),
    [DIR_LEFT] = MK_TATTR(SPR_SNAKE_BODY_RIGHT, PAL_SNAKE, 0),
};

static constexpr u8 TATTR_SNAKE_BODY_TURN[] = {
    [DIR_UP] = MK_TATTR(SPR_SNAKE_BODY_TURN, PAL_SNAKE, TF_FLIP_X | TF_FLIP_Y),
    [DIR_RIGHT] = MK_TATTR(SPR_SNAKE_BODY_TURN, PAL_SNAKE, TF_FLIP_X),
    [DIR_DOWN] = MK_TATTR(SPR_SNAKE_BODY_TURN, PAL_SNAKE, 0),
    [DIR_LEFT] = MK_TATTR(SPR_SNAKE_BODY_TURN, PAL_SNAKE, TF_FLIP_Y),
};

static constexpr u8 TATTR_SNAKE_TAIL[] = {
    [DIR_UP] = MK_TATTR(SPR_SNAKE_TAIL_DOWN, PAL_SNAKE, TF_FLIP_Y),
    [DIR_RIGHT] = MK_TATTR(SPR_SNAKE_TAIL_RIGHT, PAL_SNAKE, 0),
    [DIR_DOWN] = MK_TATTR(SPR_SNAKE_TAIL_DOWN, PAL_SNAKE, 0),
    [DIR_LEFT] = MK_TATTR(SPR_SNAKE_TAIL_RIGHT, PAL_SNAKE, TF_FLIP_X),
};

typedef struct {
    Position pos;
    Direction dir;
} SnakePart;

static constexpr size_t SNAKE_CAPACITY = VIDEO_TILES_H * VIDEO_TILES_V;
static SnakePart snake[SNAKE_CAPACITY];
static size_t snake_size;
static Direction dir_next;
static Position apple;

static constexpr size_t STEP_DELAY_CAP = 8;
static bool dead;
static size_t step_delay;

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

static void randomize_apple(void)
{
    static Position candidates[(VIDEO_TILES_H - 2) * (VIDEO_TILES_V - 2)];

    size_t candidates_size = 0;

    for (size_t i = 1; i < VIDEO_TILES_H - 1; ++i) {
        for (size_t j = 1; j < VIDEO_TILES_V - 1; ++j) {
            for (size_t k = 0; k < snake_size; ++k) {
                if (i == snake[k].pos.x && j == snake[k].pos.y)
                    goto skip_tile;
            }

            candidates[candidates_size] = (Position){.x = i, .y = j};
            ++candidates_size;
skip_tile:
        }
    }

    const size_t choice = rand_get() % candidates_size;
    apple = candidates[choice];
}

static inline void game_step(void)
{
    if (dead)
        return;

    SnakePart *const head = &snake[0];

    const Direction prev_dir = head->dir;
    head->dir = dir_next;

    const SnakePart prev_tail = snake[snake_size - 1];

    for (size_t i = snake_size - 1; i > 0; --i)
        snake[i] = snake[i - 1];

    switch (head->dir) {
    case DIR_RIGHT:
        if (head->pos.x >= VIDEO_TILES_H - 2)
            dead = true;
        else
            ++head->pos.x;
        break;
    case DIR_LEFT:
        if (head->pos.x <= 1)
            dead = true;
        else
            --head->pos.x;
        break;
    case DIR_UP:
        if (head->pos.y <= 1)
            dead = true;
        else
            --head->pos.y;
        break;
    case DIR_DOWN:
        if (head->pos.y >= VIDEO_TILES_V - 2)
            dead = true;
        else
            ++head->pos.y;
        break;
    }

    if (!dead) {
        for (size_t i = 1; i < snake_size; ++i) {
            if (head->pos.x == snake[i].pos.x && head->pos.y == snake[i].pos.y) {
                dead = true;
                break;
            }
        }
    }

    if (dead) {
        // TODO: buffer this
        video_load_palette(PAL_SNAKE, PALDATA_SNAKE_LOSE);
        return;
    }

    if (head->pos.x == apple.x && head->pos.y == apple.y) {
        // Ate an apple
        ++snake_size;
        snake[snake_size - 1] = prev_tail;

        if (step_delay > STEP_DELAY_CAP && (snake_size % 2) == 0)
            step_delay--;

        randomize_apple();
        draw_buf_push(apple.x, apple.y, TATTR_APPLE);

        audio_play_note(NOTE_A4, 18);
    } else {
        draw_buf_push(prev_tail.pos.x, prev_tail.pos.y, TATTR_BACKGROUND);
    }

    const SnakePart tail = snake[snake_size - 1];

    if (snake_size > 2) {
        if (head->dir == prev_dir)
            draw_buf_push(snake[1].pos.x, snake[1].pos.y, TATTR_SNAKE_BODY[head->dir]);
        else if (head->dir == (prev_dir + 1) % 4)
            draw_buf_push(snake[1].pos.x, snake[1].pos.y, TATTR_SNAKE_BODY_TURN[head->dir]);
        else
            draw_buf_push(snake[1].pos.x, snake[1].pos.y,
                          TATTR_SNAKE_BODY_TURN[dir_opposite(prev_dir)]);
    }

    draw_buf_push(tail.pos.x, tail.pos.y, TATTR_SNAKE_TAIL[tail.dir]);
    draw_buf_push(head->pos.x, head->pos.y, TATTR_SNAKE_HEAD[head->dir]);
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

static void game_init(void)
{
    // TODO: buffer this
    video_load_palette(PAL_SNAKE, PALDATA_SNAKE);

    // Background grass
    for (size_t x = 1; x < VIDEO_TILES_H - 1; ++x) {
        for (size_t y = 1; y < VIDEO_TILES_V - 1; ++y)
            video_set_tile(x, y, TATTR_BACKGROUND);
    }

    snake[0] = (SnakePart){
        .pos = {.x = VIDEO_TILES_H / 4, .y = VIDEO_TILES_V / 2},
        .dir = DIR_RIGHT,
    };
    snake_size = 1;

    dir_next = snake[0].dir;
    step_delay = 18;

    apple = snake[0].pos;
    apple.x += VIDEO_TILES_H / 2;

    paused = false;
    dead = false;

    draw_buf_push(snake[0].pos.x, snake[0].pos.y, TATTR_SNAKE_HEAD[snake[0].dir]);
    draw_buf_push(apple.x, apple.y, TATTR_APPLE);
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
        if (!dead)
            paused = true;
        else
            game_init();

        return;
    }

    const Direction snake_dir = snake[0].dir;

    if (snake_dir != DIR_DOWN && up)
        dir_next = DIR_UP;
    else if (snake_dir != DIR_RIGHT && left)
        dir_next = DIR_LEFT;
    else if (snake_dir != DIR_LEFT && right)
        dir_next = DIR_RIGHT;
    else if (snake_dir != DIR_UP && down)
        dir_next = DIR_DOWN;

    static size_t step_timer = 0;

    ++step_timer;

    if (step_timer >= step_delay) {
        step_timer = 0;
        game_step();
    }
}

void main(void)
{
    enable_irq = false;
    VCTRL->display_on = false;

    audio_init();
    rand_seed();

    video_load_palette(PAL_SNAKE, PALDATA_SNAKE);
    video_load_palette(PAL_APPLE, PALDATA_APPLE);
    video_load_palette(PAL_BG, PALDATA_BG);

    extern const u8 TDATA_BACKGROUND[];
    extern const u8 TDATA_APPLE[];
    extern const u8 TDATA_SNAKE_HEAD_RIGHT[];
    extern const u8 TDATA_SNAKE_HEAD_DOWN[];
    extern const u8 TDATA_SNAKE_BODY_RIGHT[];
    extern const u8 TDATA_SNAKE_BODY_DOWN[];
    extern const u8 TDATA_WALL[];
    extern const u8 TDATA_SNAKE_BODY_TURN[];
    extern const u8 TDATA_SNAKE_TAIL_RIGHT[];
    extern const u8 TDATA_SNAKE_TAIL_DOWN[];

    video_load_tdata(SPR_BACKGROUND, (const u16 *)TDATA_BACKGROUND);
    video_load_tdata(SPR_APPLE, (const u16 *)TDATA_APPLE);
    video_load_tdata(SPR_SNAKE_HEAD_RIGHT, (const u16 *)TDATA_SNAKE_HEAD_RIGHT);
    video_load_tdata(SPR_SNAKE_HEAD_DOWN, (const u16 *)TDATA_SNAKE_HEAD_DOWN);
    video_load_tdata(SPR_SNAKE_BODY_RIGHT, (const u16 *)TDATA_SNAKE_BODY_RIGHT);
    video_load_tdata(SPR_SNAKE_BODY_DOWN, (const u16 *)TDATA_SNAKE_BODY_DOWN);
    video_load_tdata(SPR_WALL, (const u16 *)TDATA_WALL);
    video_load_tdata(SPR_SNAKE_BODY_TURN, (const u16 *)TDATA_SNAKE_BODY_TURN);
    video_load_tdata(SPR_SNAKE_TAIL_RIGHT, (const u16 *)TDATA_SNAKE_TAIL_RIGHT);
    video_load_tdata(SPR_SNAKE_TAIL_DOWN, (const u16 *)TDATA_SNAKE_TAIL_DOWN);

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

    game_init();

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
