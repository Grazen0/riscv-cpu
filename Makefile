BUILD_DIR := ./build
SRC_DIR := ./src
TB_DIR := ./tb

SRCS = $(shell find $(SRC_DIR) -name '*.v')
TBS = $(shell find $(TB_DIR) -name '*.v')

TARGETS := $(patsubst $(TB_DIR)/%.v,$(BUILD_DIR)/%,$(TBS))

INC_DIRS := $(shell find ./include -type d)
INC_FLAGS := $(addprefix -I,$(INC_DIRS))

IVERILOG_FLAGS := $(INC_FLAGS) 

DATA_DIR := ./data
FIRMWARE_DIR := firmware

FIRMWARE_MEM = firmware.mem

.PHONY: clean run wave firmware

all: $(TARGETS)

clean:
	make -C $(FIRMWARE_DIR) clean
	rm -rf $(BUILD_DIR)
	rm -f dump.vcd

FORCE: ;

$(DATA_DIR)/%.mem: FORCE
	make -C $(FIRMWARE_DIR)
	cp $(FIRMWARE_DIR)/build/*.mem $(DATA_DIR);

$(BUILD_DIR)/%: $(TB_DIR)/%.v $(SRCS) $(DATA_DIR)/$(FIRMWARE_MEM)
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
