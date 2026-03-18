# =============================================================================
# Intel DE10-Lite Board Constraints (SDC Format)
# RISC-V RV32I Pipelined CPU
# Board: Terasic DE10-Lite (Intel MAX 10 10M50DAF484C7G)
# =============================================================================

# ---------------------------------------------------------------------------
# Clock – 50 MHz on-board MAX10 oscillator (PIN_P11)
# ---------------------------------------------------------------------------
create_clock -name {clk} -period 20.000 -waveform {0.000 10.000} [get_ports {clk}]

# Derive PLL clocks if any are used
derive_pll_clocks

# Derive clock uncertainty
derive_clock_uncertainty

# ---------------------------------------------------------------------------
# Input / Output delay constraints
# ---------------------------------------------------------------------------
set_input_delay  -clock {clk} -max 3.0  [all_inputs]
set_input_delay  -clock {clk} -min 0.5  [all_inputs]
set_output_delay -clock {clk} -max 3.0  [all_outputs]
set_output_delay -clock {clk} -min 0.5  [all_outputs]

# ---------------------------------------------------------------------------
# False paths for asynchronous reset
# ---------------------------------------------------------------------------
set_false_path -from [get_ports {rst_n}]

# ---------------------------------------------------------------------------
# Pin assignments (Quartus .qsf format; also valid as SDC comments)
# ---------------------------------------------------------------------------
# Clock:    PIN_P11  (MAX10 50MHz oscillator)
# Reset:    PIN_B8   (KEY0, active-low push button)
#
# LEDs (LEDR[9:0]):
#   LEDR0 = PIN_A8
#   LEDR1 = PIN_A9
#   LEDR2 = PIN_A10
#   LEDR3 = PIN_B10
#   LEDR4 = PIN_D13
#   LEDR5 = PIN_C13
#   LEDR6 = PIN_E14
#   LEDR7 = PIN_D14
#   LEDR8 = PIN_A11
#   LEDR9 = PIN_B11
#
# Switches (SW[9:0]):
#   SW0 = PIN_C10
#   SW1 = PIN_C11
#   SW2 = PIN_D12
#   SW3 = PIN_C12
#   SW4 = PIN_A12
#   SW5 = PIN_B12
#   SW6 = PIN_A13
#   SW7 = PIN_A14
#   SW8 = PIN_B14
#   SW9 = PIN_F15
#
# Push buttons (KEY[1:0]):
#   KEY0 = PIN_B8  (used as rst_n)
#   KEY1 = PIN_A7
#
# UART TX (GPIO_0[0] = PIN_V10)

# ---------------------------------------------------------------------------
# Multicycle path exceptions (for slow paths if needed)
# ---------------------------------------------------------------------------
# set_multicycle_path -from [get_registers {*}] -to [get_registers {*}] -setup 2

# ---------------------------------------------------------------------------
# Timing constraint for UART (slow peripheral, relax if needed)
# ---------------------------------------------------------------------------
set_false_path -to [get_ports {uart_tx_pin}]
