PROJECT_NAME := firmware
TARGET_EXEC := $(PROJECT_NAME).elf
TARGET_BIN := $(PROJECT_NAME).bin
TARGET_MEM := $(PROJECT_NAME).mem
TARGET_TDATA_DIR := ./data/tdata

BUILD_DIR := ./build
SRC_DIRS := ./src
TDATA_DIR := ./data/tdata

TDATA_FILES := $(shell find $(TDATA_DIR) -name '*.tdata')
TDATA_SRCS := $(TDATA_FILES:%=%.c)

SRCS := $(TDATA_SRCS) $(shell find $(SRC_DIRS) -name '*.c' -or -name '*.s')
OBJS := $(SRCS:%=$(BUILD_DIR)/%.o)
LINKER := ./data/tachyon.ld

INC_DIRS := $(shell find $(SRC_DIRS) -type d)
INC_FLAGS := $(addprefix -I,$(INC_DIRS))

CFLAGS := $(INC_FLAGS) -march=rv32i_zicsr -mabi=ilp32 -std=c23 -Oz -g \
		  -ffunction-sections -fdata-sections -ffreestanding \
		  -specs=nano.specs -nostartfiles -static
LDFLAGS := --no-warn-rwx-segments,--gc-sections

CC := riscv32-none-elf-gcc
OBJCOPY := riscv32-none-elf-objcopy
XXD := xxd

BEAR := bear
CDB := compile_commands.json

.PHONY: all clean

all: $(BUILD_DIR)/$(TARGET_MEM)

clean:
	rm -rf $(BUILD_DIR)

compdb:
	mkdir -p $(BUILD_DIR)
	$(BEAR) --output $(BUILD_DIR)/$(CDB) -- make -B

$(BUILD_DIR)/$(TARGET_TDATA_DIR)/%.c: $(TDATA_DIR)/%
	mkdir -p $(dir $@)
	./tools/generate_tdata.sh $< > $@

$(BUILD_DIR)/%.mem: $(BUILD_DIR)/%.bin
	$(XXD) -p -c4 -e $< | awk '{print $$2}' > $@

$(BUILD_DIR)/$(TARGET_BIN): $(BUILD_DIR)/$(TARGET_EXEC)
	$(OBJCOPY) -O binary --set-section-flags .bss=alloc,load,contents $< $@

$(BUILD_DIR)/$(TARGET_EXEC): $(OBJS) $(LINKER)
	$(CC) $(CFLAGS) -T $(LINKER) -o $@ $(OBJS) -Wl,$(LDFLAGS)

$(BUILD_DIR)/%.tdata.c.o: $(BUILD_DIR)/%.tdata.c
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.c.o: %.c
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.s.o: %.s
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@
