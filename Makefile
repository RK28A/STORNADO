# STORNADO - build / test tasks
RTL_COMMON := rtl/common/nvme_pkg.sv rtl/common/reset_sync.sv rtl/common/cdc_sync.sv \
              rtl/common/sync_fifo.sv rtl/common/async_fifo.sv
RTL_NVME   := rtl/nvme/nvme_regs.sv rtl/nvme/nvme_doorbells.sv \
              rtl/nvme/nvme_cmd_decoder.sv rtl/nvme/nvme_queue_mgr.sv
RTL_DMA    := rtl/dma/dma_engine.sv
RTL_MEM    := rtl/memory/storage_backend_ram.sv
BUILD      := build
# Enable RTL traces: make sim DEFS=-DSTORNADO_DEBUG  (or: make sim-debug)
DEFS       ?=

.PHONY: all test test-host sim sim-debug sim-verilator cli lint regs package clean

## Everything runnable without hardware
test: test-host

all: test-host

## Python tests (no hardware)
test-host:
	python3 -m pytest host/tests -q

## CLI demo over the mock transport
cli:
	python3 host/cli/nvme_tool.py self-test --json
	python3 host/cli/nvme_tool.py status

## RTL simulation - Icarus Verilog
sim: $(BUILD)
	iverilog -g2012 $(DEFS) -o $(BUILD)/tb_fifo    $(RTL_COMMON) sim/unit/tb_sync_fifo.sv && vvp $(BUILD)/tb_fifo
	iverilog -g2012 $(DEFS) -o $(BUILD)/tb_afifo   $(RTL_COMMON) sim/unit/tb_async_fifo.sv && vvp $(BUILD)/tb_afifo
	iverilog -g2012 $(DEFS) -o $(BUILD)/tb_regs    $(RTL_COMMON) $(RTL_NVME) sim/unit/tb_nvme_regs.sv && vvp $(BUILD)/tb_regs
	iverilog -g2012 $(DEFS) -o $(BUILD)/tb_backend $(RTL_COMMON) $(RTL_MEM) sim/unit/tb_storage_backend.sv && vvp $(BUILD)/tb_backend
	iverilog -g2012 $(DEFS) -o $(BUILD)/tb_init    $(RTL_COMMON) $(RTL_NVME) sim/integration/tb_init_sequence.sv && vvp $(BUILD)/tb_init
	iverilog -g2012 $(DEFS) -o $(BUILD)/tb_dma     $(RTL_COMMON) $(RTL_DMA) sim/integration/tb_dma_prp.sv && vvp $(BUILD)/tb_dma

## Same with RTL debug traces
sim-debug:
	$(MAKE) sim DEFS=-DSTORNADO_DEBUG

## RTL simulation - Verilator (lint+run FIFO)
sim-verilator:
	verilator --binary -j 0 -Wall --top-module tb_sync_fifo $(RTL_COMMON) sim/unit/tb_sync_fifo.sv -o tb_fifo_vl
	./obj_dir/tb_fifo_vl

## Lint (optional, verible) - portable, fails on real lint errors
lint:
	bash scripts/lint.sh

## Regenerate the register doc from tools/registers.json
regs:
	python3 tools/gen_register_doc.py

## Build a release archive (files at the archive root)
package:
	bash scripts/package.sh

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD) obj_dir host/**/__pycache__ .pytest_cache
