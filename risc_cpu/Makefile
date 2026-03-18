# =============================================================================
# RISC-V RV32I Pipelined CPU — Makefile
# Uses Icarus Verilog (iverilog) + vvp for simulation
# =============================================================================

IVERILOG = iverilog
VVP      = vvp

SRC_CORE = src/core/alu.v \
           src/core/register_file.v \
           src/core/control_unit.v \
           src/core/alu_decoder.v \
           src/core/immediate_gen.v \
           src/core/forwarding_unit.v \
           src/core/hazard_detection.v \
           src/core/branch_predictor.v

SRC_PIPE = src/pipeline/if_id_reg.v \
           src/pipeline/id_ex_reg.v \
           src/pipeline/ex_mem_reg.v \
           src/pipeline/mem_wb_reg.v

SRC_MEM  = src/memory/instr_mem.v \
           src/memory/data_mem.v

SRC_PERI = src/peripherals/uart_tx.v \
           src/peripherals/gpio.v

SRC_ALL  = $(SRC_CORE) $(SRC_PIPE) $(SRC_MEM) $(SRC_PERI) src/cpu_top.v

.PHONY: all sim_alu sim_regfile sim_ctrl sim_hazard sim_cpu assemble clean help

all: sim_alu sim_regfile sim_ctrl sim_hazard sim_cpu

# -----------------------------------------------------------------------------
# Individual unit simulations
# -----------------------------------------------------------------------------

sim_alu: tb/tb_alu.v $(SRC_CORE)
	@echo "=== Simulating ALU ==="
	$(IVERILOG) -g2012 -o sim_alu.vvp tb/tb_alu.v src/core/alu.v
	$(VVP) sim_alu.vvp
	@rm -f sim_alu.vvp

sim_regfile: tb/tb_register_file.v $(SRC_CORE)
	@echo "=== Simulating Register File ==="
	$(IVERILOG) -g2012 -o sim_regfile.vvp tb/tb_register_file.v src/core/register_file.v
	$(VVP) sim_regfile.vvp
	@rm -f sim_regfile.vvp

sim_ctrl: tb/tb_control_unit.v $(SRC_CORE)
	@echo "=== Simulating Control Unit ==="
	$(IVERILOG) -g2012 -o sim_ctrl.vvp tb/tb_control_unit.v src/core/control_unit.v
	$(VVP) sim_ctrl.vvp
	@rm -f sim_ctrl.vvp

sim_hazard: tb/tb_hazard_forwarding.v $(SRC_CORE)
	@echo "=== Simulating Hazard/Forwarding Units ==="
	$(IVERILOG) -g2012 -o sim_hazard.vvp \
		tb/tb_hazard_forwarding.v \
		src/core/forwarding_unit.v \
		src/core/hazard_detection.v
	$(VVP) sim_hazard.vvp
	@rm -f sim_hazard.vvp

# -----------------------------------------------------------------------------
# Full CPU simulation (requires tb_cpu_prog.hex in tb/)
# -----------------------------------------------------------------------------

sim_cpu: tb/tb_cpu_top.v $(SRC_ALL)
	@echo "=== Simulating Full CPU ==="
	@if [ ! -f tb/tb_cpu_prog.hex ]; then \
		echo "Assembling test program..."; \
		python3 assembler/assembler.py assembler/programs/fibonacci.asm tb/tb_cpu_prog.hex; \
	fi
	$(IVERILOG) -g2012 \
		-I src/core -I src/pipeline -I src/memory -I src/peripherals \
		-o sim_cpu.vvp \
		tb/tb_cpu_top.v $(SRC_ALL)
	$(VVP) sim_cpu.vvp
	@rm -f sim_cpu.vvp

# -----------------------------------------------------------------------------
# Assemble all programs
# -----------------------------------------------------------------------------

assemble:
	@echo "=== Assembling programs ==="
	python3 assembler/assembler.py assembler/programs/fibonacci.asm  programs/fibonacci.hex
	python3 assembler/assembler.py assembler/programs/bubble_sort.asm programs/bubble_sort.hex
	python3 assembler/assembler.py assembler/programs/led_blink.asm   programs/led_blink.hex

# -----------------------------------------------------------------------------
# Waveform viewer (GTKWave)
# -----------------------------------------------------------------------------

wave: sim_cpu
	gtkwave tb_cpu_top.vcd &

# -----------------------------------------------------------------------------
# Syntax check only (no simulation)
# -----------------------------------------------------------------------------

lint:
	@echo "=== Lint/syntax check ==="
	$(IVERILOG) -g2012 -tnull $(SRC_ALL)
	@echo "Syntax OK"

# -----------------------------------------------------------------------------
# Clean up
# -----------------------------------------------------------------------------

clean:
	rm -f *.vvp *.vcd *.lxt *.fst

help:
	@echo "Targets:"
	@echo "  all        - Run all simulations"
	@echo "  sim_alu    - Simulate ALU"
	@echo "  sim_regfile- Simulate register file"
	@echo "  sim_ctrl   - Simulate control unit"
	@echo "  sim_hazard - Simulate hazard/forwarding units"
	@echo "  sim_cpu    - Simulate full CPU"
	@echo "  assemble   - Assemble all .asm programs to .hex"
	@echo "  lint       - Syntax check all source files"
	@echo "  wave       - Open waveform in GTKWave"
	@echo "  clean      - Remove generated files"
