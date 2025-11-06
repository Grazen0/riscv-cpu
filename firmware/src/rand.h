#ifndef FIRMWARE_RAND_H
#define FIRMWARE_RAND_H

#include "num.h"

void rand_seed(void);

u64 rand_get(void);

void rand_update(void);

#endif
