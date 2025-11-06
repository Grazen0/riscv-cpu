#include "rand.h"
#include "num.h"
#include "tachyon.h"

// See: https://en.wikipedia.org/wiki/Xorshift#xoshiro256++

static u64 rol64(const uint64_t x, const size_t k)
{
    return (x << k) | (x >> (64 - k));
}

static u64 rand_state[4];

static u64 u64_from_trng(void)
{
    const u64 lo = TRNG;
    const u64 hi = TRNG;

    return lo | (hi << 32);
}

void rand_seed(void)
{
    bool zero = true;

    for (size_t i = 0; i < 4; ++i) {
        rand_state[i] = u64_from_trng();
        if (rand_state[i] != 0)
            zero = false;
    }

    // Care should be taken to not allow the initial state to be 0,
    // which is impossible to escape from.
    if (zero)
        rand_state[0] = 0xDEADBEEF;
}

u64 rand_get(void)
{
    const u64 result = rol64(rand_state[0] + rand_state[3], 23) + rand_state[0];
    rand_update();

    return result;
}

void rand_update(void)
{
    const u64 t = rand_state[1] << 17;

    rand_state[2] ^= rand_state[0];
    rand_state[3] ^= rand_state[1];
    rand_state[1] ^= rand_state[2];
    rand_state[0] ^= rand_state[3];

    rand_state[2] ^= t;
    rand_state[3] = rol64(rand_state[3], 45);
}
