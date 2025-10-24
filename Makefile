BUILD_DIR := ./build
SRC_DIR := ./src
TB_DIR := ./tb

SRCS = $(shell find $(SRC_DIR) -name '*.v')
TBS = $(shell find $(TB_DIR) -name '*.v')

TARGETS := $(patsubst $(TB_DIR)/%.v,$(BUILD_DIR)/%,$(TBS))

INC_DIRS := ./include
INC_FLAGS := $(addprefix -I,$(INC_DIRS))

IVERILOG_FLAGS := $(INC_FLAGS) 

DATA_DIR := ./data
FIRMWARE_DIR := firmware

FIRMWARE_HEX = firmware.hex

.PHONY: clean run wave firmware

all: $(TARGETS)

clean:
	make -C $(FIRMWARE_DIR) clean
	rm -rf $(BUILD_DIR)
	rm -f dump.vcd

FORCE: ;

$(DATA_DIR)/%.hex: FORCE
	@set -e; \
	if make -C $(FIRMWARE_DIR) -q; then \
		echo "Up to date"; \
	else \
		echo "Building firmware..."; \
		make -C $(FIRMWARE_DIR); \
		cp $(FIRMWARE_DIR)/build/*.hex $(DATA_DIR); \
	fi

$(BUILD_DIR)/%: $(TB_DIR)/%.v $(SRCS) $(DATA_DIR)/$(FIRMWARE_HEX)
	mkdir -p $(dir $@)
	iverilog $(IVERILOG_FLAGS) -o $@ $< $(SRCS) 

run: $(BUILD_DIR)/$(TB)
	@if [ -z "$(TB)" ]; then \
	    echo "Usage: make run TB=<testbench_name>"; \
	    exit 1; \
	fi
	vvp $(VVP_FLAGS) $<

wave: $(BUILD_DIR)/$(TB)
	@if [ -z "$(TB)" ]; then \
	    echo "Usage: make wave TB=<testbench_name>"; \
	    exit 1; \
	fi
	vvp $<
	gtkwave dump.vcd
