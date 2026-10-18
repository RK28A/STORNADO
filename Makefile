# STORNADO — tâches de build / test
RTL_COMMON := rtl/common/nvme_pkg.sv rtl/common/reset_sync.sv rtl/common/cdc_sync.sv \
              rtl/common/sync_fifo.sv rtl/common/async_fifo.sv
RTL_NVME   := rtl/nvme/nvme_regs.sv rtl/nvme/nvme_doorbells.sv \
              rtl/nvme/nvme_cmd_decoder.sv rtl/nvme/nvme_queue_mgr.sv
BUILD      := build
# Active les traces RTL : make sim DEFS=-DSTORNADO_DEBUG  (ou: make sim-debug)
DEFS       ?=

.PHONY: all test-host sim sim-debug sim-verilator cli lint clean

all: test-host

## Tests Python (sans matériel)
test-host:
	python3 -m pytest host/tests -q

## Démo CLI sur transport mock
cli:
	python3 host/cli/nvme_tool.py self-test --json
	python3 host/cli/nvme_tool.py status

## Simulation RTL — Icarus Verilog
sim: $(BUILD)
	iverilog -g2012 $(DEFS) -o $(BUILD)/tb_fifo  $(RTL_COMMON) sim/unit/tb_sync_fifo.sv && vvp $(BUILD)/tb_fifo
	iverilog -g2012 $(DEFS) -o $(BUILD)/tb_regs  $(RTL_COMMON) $(RTL_NVME) sim/unit/tb_nvme_regs.sv && vvp $(BUILD)/tb_regs
	iverilog -g2012 $(DEFS) -o $(BUILD)/tb_init  $(RTL_COMMON) $(RTL_NVME) sim/integration/tb_init_sequence.sv && vvp $(BUILD)/tb_init

## Idem avec les traces de debug RTL
sim-debug:
	$(MAKE) sim DEFS=-DSTORNADO_DEBUG

## Simulation RTL — Verilator (lint+run FIFO)
sim-verilator:
	verilator --binary -j 0 -Wall --top-module tb_sync_fifo $(RTL_COMMON) sim/unit/tb_sync_fifo.sv -o tb_fifo_vl
	./obj_dir/tb_fifo_vl

## Lint (optionnel, verible)
lint:
	verible-verilog-lint rtl/**/*.sv || true

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD) obj_dir host/**/__pycache__ .pytest_cache
