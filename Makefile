BUILD_DIR := ./build

SRC_DIR := ./src
TB_DIR := ./tb

# Firmware variables ====================================================================

PROJECT_NAME := firmware
FW_TARGET_EXEC := $(PROJECT_NAME).elf
FW_TARGET_BIN := $(PROJECT_NAME).bin
FW_TARGET_MEM := $(PROJECT_NAME).mem

FW_BASE := ./firmware
FW_TARGET_TDATA_DIR := $(FW_BASE)/data/tdata

FW_SRC_DIRS := $(FW_BASE)/src
FW_TDATA_DIR := $(FW_BASE)/data/tdata

FW_TDATA_FILES := $(shell find $(FW_TDATA_DIR) -name '*.tdata')
FW_TDATA_SRCS := $(FW_TDATA_FILES:%=$(BUILD_DIR)/%.c)
FW_TDATA_OBJS := $(FW_TDATA_SRCS:%=%.o)

FW_SRCS := $(shell find $(FW_SRC_DIRS) -name '*.c' -or -name '*.s')
FW_OBJS := $(FW_TDATA_OBJS) $(FW_SRCS:%=$(BUILD_DIR)/%.o)
FW_LINKER := $(FW_BASE)/data/tachyon.ld

FW_INC_DIRS := $(shell find $(FW_SRC_DIRS) -type d)
FW_INC_FLAGS := $(addprefix -I,$(FW_INC_DIRS))

CFLAGS := $(FW_INC_FLAGS) -march=rv32if_zicsr -mabi=ilp32 -std=c23 -Oz -g \
		  -ffunction-sections -fdata-sections -ffreestanding \
		  -specs=nano.specs -nostartfiles -static \
		  -Wall -Wextra -Wpedantic
LDFLAGS := --no-warn-rwx-segments,--gc-sections

CC := riscv32-none-elf-gcc
OBJCOPY := riscv32-none-elf-objcopy
XXD := xxd

BEAR := bear
CDB := compile_commands.json


# Verilog variables ===========================================================

SRCS = $(shell find $(SRC_DIR) -name '*.v')
TBS = $(shell find $(TB_DIR) -name '*.v')

TARGETS := $(patsubst $(TB_DIR)/%.v,$(BUILD_DIR)/%.out,$(TBS))
VCD_DUMPS := $(patsubst $(TB_DIR)/%.v,$(BUILD_DIR)/%.vcd,$(TBS))

INC_DIRS := $(shell find ./include -type d)
INC_FLAGS := $(addprefix -I,$(INC_DIRS))

RAM_SOURCE := $(BUILD_DIR)/$(FW_BASE)/$(FIRMWARE_MEM)
ROM_SOURCE := $(BUILD_DIR)/$(FW_BASE)/$(FIRMWARE_MEM)
IVERILOG_FLAGS := -DIVERILOG
# -DRAM_SOURCE_FILE='"$(RAM_SOURCE)"' -DROM_SOURCE_FILE='"$(ROM_SOURCE)"'


.PHONY: all clean run wave compdb firmware

all: $(TARGETS)

clean:
	rm -rf $(BUILD_DIR)


# Firmware ====================================================================

firmware: $(BUILD_DIR)/$(FW_BASE)/$(FW_TARGET_MEM)

compdb:
	mkdir -p $(BUILD_DIR)
	$(BEAR) --output $(BUILD_DIR)/$(CDB) -- make -B $(BUILD_DIR)/$(FW_BASE)/$(FW_TARGET_EXEC)

$(BUILD_DIR)/$(FW_TARGET_TDATA_DIR)/%.c: $(FW_TDATA_DIR)/%
	mkdir -p $(dir $@)
	$(FW_BASE)/tools/generate_tdata.sh $< > $@

$(BUILD_DIR)/%.mem: $(BUILD_DIR)/%.bin
	$(XXD) -p -c4 -e $< | awk '{print $$2}' > $@

$(BUILD_DIR)/$(FW_BASE)/$(FW_TARGET_BIN): $(BUILD_DIR)/$(FW_BASE)/$(FW_TARGET_EXEC)
	$(OBJCOPY) -O binary --set-section-flags .bss=alloc,load,contents $< $@

$(BUILD_DIR)/$(FW_BASE)/$(FW_TARGET_EXEC): $(FW_OBJS) $(FW_LINKER)
	$(CC) $(CFLAGS) -T $(FW_LINKER) -o $@ $(FW_OBJS) -Wl,$(LDFLAGS)

$(BUILD_DIR)/%.tdata.c.o: $(BUILD_DIR)/%.tdata.c
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.c.o: %.c
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.s.o: %.s
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@


# Verilog =====================================================================

$(BUILD_DIR)/%.out: $(TB_DIR)/%.v $(SRCS) $(BUILD_DIR)/$(FW_BASE)/$(FW_TARGET_MEM)
	mkdir -p $(dir $@)
	iverilog $(INC_FLAGS) $(IVERILOG_FLAGS) -o $@ $< $(SRCS) 

$(BUILD_DIR)/%.vcd: $(BUILD_DIR)/%.out
	mkdir -p $(dir $@)
	vvp $(VVP_FLAGS) $<
	mv dump.vcd $@

run: $(BUILD_DIR)/$(TB).out
	mkdir -p $(dir $(BUILD_DIR)/$(TB))
	vvp $(VVP_FLAGS) $<
	mv dump.vcd $(BUILD_DIR)/$(TB).vcd

wave: $(BUILD_DIR)/$(TB).vcd
	gtkwave $<
