// =============================================================================
// tb_cpu_top.v  -  Full CPU Testbench
// Loads a simple test program, simulates 200 cycles, dumps VCD waveform
//
// Test program sequence (loaded via instr_mem.hex):
//   addi x1, x0, 5      # x1 = 5
//   addi x2, x0, 3      # x2 = 3
//   add  x3, x1, x2     # x3 = 8
//   addi x4, x0, 100    # x4 = 100 (base address)
//   sw   x3, 0(x4)      # mem[100] = 8
//   lw   x5, 0(x4)      # x5 = mem[100] = 8
//   nop
//   nop
//   nop
// =============================================================================
`timescale 1ns/1ps

module tb_cpu_top;

    reg         clk, rst_n;
    wire [15:0] gpio_out;
    wire        uart_tx_pin;
    wire [31:0] dbg_pc, dbg_reg_x10;

    integer pass_cnt = 0;
    integer fail_cnt = 0;
    integer cycle_cnt = 0;

    // Instantiate CPU
    cpu_top #(
        .IMEM_HEX("tb/tb_cpu_prog.hex"),
        .UART_BPS(4)
    ) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .gpio_out    (gpio_out),
        .gpio_in     (16'h0000),
        .uart_tx_pin (uart_tx_pin),
        .dbg_pc      (dbg_pc),
        .dbg_reg_x10 (dbg_reg_x10)
    );

    always #5 clk = ~clk;

    // Cycle counter
    always @(posedge clk) cycle_cnt = cycle_cnt + 1;

    // Access register file and data memory for verification
    // Using hierarchical path names
    task check_reg;
        input [31:0] test_id;
        input [4:0]  reg_addr;
        input [31:0] expected;
        reg   [31:0] actual;
        begin
            actual = dut.u_regfile.regs[reg_addr];
            if (actual === expected) begin
                $display("PASS [%0d] x%0d = 0x%08h (%0d)", test_id, reg_addr, actual, $signed(actual));
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("FAIL [%0d] x%0d = 0x%08h (exp 0x%08h)", test_id, reg_addr, actual, expected);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task check_mem;
        input [31:0] test_id;
        input [11:0] byte_addr;
        input [31:0] expected;
        reg   [31:0] actual;
        begin
            actual = {dut.u_dmem.mem[byte_addr+3],
                      dut.u_dmem.mem[byte_addr+2],
                      dut.u_dmem.mem[byte_addr+1],
                      dut.u_dmem.mem[byte_addr]};
            if (actual === expected) begin
                $display("PASS [%0d] mem[0x%03h] = 0x%08h", test_id, byte_addr, actual);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("FAIL [%0d] mem[0x%03h] = 0x%08h (exp 0x%08h)",
                         test_id, byte_addr, actual, expected);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    initial begin
        // Create VCD dump
        $dumpfile("tb_cpu_top.vcd");
        $dumpvars(0, tb_cpu_top);

        clk = 0; rst_n = 0;
        #12; rst_n = 1;

        // Run for 200 cycles
        repeat (200) @(posedge clk);

        $display("Simulated %0d cycles, final PC = 0x%08h", cycle_cnt, dbg_pc);

        // Verify register values after program executes
        // addi x1,x0,5  => x1=5
        check_reg(1, 5'd1, 32'd5);
        // addi x2,x0,3  => x2=3
        check_reg(2, 5'd2, 32'd3);
        // add x3,x1,x2  => x3=8
        check_reg(3, 5'd3, 32'd8);
        // addi x4,x0,100 => x4=100
        check_reg(4, 5'd4, 32'd100);
        // lw x5,0(x4) => x5=8
        check_reg(5, 5'd5, 32'd8);
        // sw x3,0(x4) => mem[100]=8
        check_mem(6, 12'd100, 32'd8);
        // x0 always 0
        check_reg(7, 5'd0, 32'd0);

        $display("--------------------------------------");
        $display("CPU Top TB: %0d PASS, %0d FAIL after %0d cycles",
                 pass_cnt, fail_cnt, cycle_cnt);
        if (fail_cnt == 0)
            $display("ALL CPU INTEGRATION TESTS PASSED");
        else
            $display("SOME CPU INTEGRATION TESTS FAILED");
        $display("--------------------------------------");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("TIMEOUT: simulation exceeded limit");
        $finish;
    end

endmodule
