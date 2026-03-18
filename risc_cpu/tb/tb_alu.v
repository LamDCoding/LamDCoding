// =============================================================================
// tb_alu.v  –  ALU Testbench
// Tests every ALU operation with known inputs/outputs
// =============================================================================
`timescale 1ns/1ps

module tb_alu;

    reg  [31:0] a, b;
    reg  [3:0]  alu_ctrl;
    wire [31:0] result;
    wire        zero, negative, overflow, carry_out;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    alu dut (
        .a        (a),
        .b        (b),
        .alu_ctrl (alu_ctrl),
        .result   (result),
        .zero     (zero),
        .negative (negative),
        .overflow (overflow),
        .carry_out(carry_out)
    );

    task check;
        input [63:0]  test_id;
        input [31:0]  expected;
        input         exp_zero;
        begin
            #1;
            if (result === expected && zero === exp_zero) begin
                $display("PASS [%0d] op=%b a=%0d b=%0d => result=%0d",
                         test_id, alu_ctrl, $signed(a), $signed(b), $signed(result));
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("FAIL [%0d] op=%b a=%0d b=%0d => got=%0d (z=%b) exp=%0d (z=%b)",
                         test_id, alu_ctrl, $signed(a), $signed(b),
                         $signed(result), zero, $signed(expected), exp_zero);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    initial begin
        // --- ADD (0000) ---
        alu_ctrl = 4'b0000;
        a = 32'd10;  b = 32'd20;  check(1, 32'd30,  1'b0);
        a = 32'd0;   b = 32'd0;   check(2, 32'd0,   1'b1);
        a = 32'hFFFF_FFFF; b = 32'd1; check(3, 32'd0, 1'b1); // wrap-around

        // --- SUB (0001) ---
        alu_ctrl = 4'b0001;
        a = 32'd30;  b = 32'd10;  check(4, 32'd20,  1'b0);
        a = 32'd10;  b = 32'd10;  check(5, 32'd0,   1'b1);
        a = 32'd0;   b = 32'd1;   check(6, 32'hFFFF_FFFF, 1'b0);

        // --- AND (0010) ---
        alu_ctrl = 4'b0010;
        a = 32'hFF00_FF00; b = 32'h0F0F_0F0F; check(7, 32'h0F00_0F00, 1'b0);
        a = 32'hAAAA_AAAA; b = 32'h5555_5555; check(8, 32'h0000_0000, 1'b1);

        // --- OR (0011) ---
        alu_ctrl = 4'b0011;
        a = 32'hF0F0_F0F0; b = 32'h0F0F_0F0F; check(9,  32'hFFFF_FFFF, 1'b0);
        a = 32'd0;          b = 32'd0;          check(10, 32'd0,         1'b1);

        // --- XOR (0100) ---
        alu_ctrl = 4'b0100;
        a = 32'hFFFF_FFFF; b = 32'hFFFF_FFFF; check(11, 32'd0,         1'b1);
        a = 32'h5A5A_5A5A; b = 32'hA5A5_A5A5; check(12, 32'hFFFF_FFFF, 1'b0);

        // --- SLL (0101) ---
        alu_ctrl = 4'b0101;
        a = 32'd1;  b = 32'd4;  check(13, 32'd16,          1'b0);
        a = 32'd1;  b = 32'd31; check(14, 32'h8000_0000,   1'b0);
        a = 32'd1;  b = 32'd0;  check(15, 32'd1,           1'b0);

        // --- SRL (0110) ---
        alu_ctrl = 4'b0110;
        a = 32'h8000_0000; b = 32'd1;  check(16, 32'h4000_0000, 1'b0);
        a = 32'hFFFF_FFFF; b = 32'd4;  check(17, 32'h0FFF_FFFF, 1'b0);
        a = 32'd16;        b = 32'd4;  check(18, 32'd1,          1'b0);

        // --- SRA (0111) ---
        alu_ctrl = 4'b0111;
        a = 32'h8000_0000; b = 32'd1;  check(19, 32'hC000_0000, 1'b0); // sign-extend
        a = 32'hFFFF_FFFF; b = 32'd4;  check(20, 32'hFFFF_FFFF, 1'b0);
        a = 32'd16;        b = 32'd4;  check(21, 32'd1,          1'b0);

        // --- SLT (1000) ---
        alu_ctrl = 4'b1000;
        a = 32'hFFFF_FFFF; b = 32'd0;  check(22, 32'd1, 1'b0); // -1 < 0 (signed)
        a = 32'd5;         b = 32'd10; check(23, 32'd1, 1'b0);
        a = 32'd10;        b = 32'd5;  check(24, 32'd0, 1'b1);
        a = 32'd5;         b = 32'd5;  check(25, 32'd0, 1'b1);

        // --- SLTU (1001) ---
        alu_ctrl = 4'b1001;
        a = 32'hFFFF_FFFF; b = 32'd0;  check(26, 32'd0, 1'b1); // large unsigned > 0
        a = 32'd0;         b = 32'd1;  check(27, 32'd1, 1'b0);
        a = 32'd5;         b = 32'd5;  check(28, 32'd0, 1'b1);

        // --- PASS_B / LUI (1010) ---
        alu_ctrl = 4'b1010;
        a = 32'hDEAD_BEEF; b = 32'h1234_5000; check(29, 32'h1234_5000, 1'b0);
        a = 32'd0;          b = 32'd0;          check(30, 32'd0,         1'b1);

        // --- AUIPC ADD (1011) ---
        alu_ctrl = 4'b1011;
        a = 32'h0000_0100; b = 32'h0001_2000; check(31, 32'h0001_2100, 1'b0);

        // --- Zero flag additional ---
        alu_ctrl = 4'b0000;
        a = 32'h8000_0000; b = 32'h8000_0000;
        check(32, 32'h0000_0000, 1'b1); // 0x80000000 + 0x80000000 wraps to 0

        $display("--------------------------------------");
        $display("ALU TB: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("ALL ALU TESTS PASSED");
        else
            $display("SOME ALU TESTS FAILED");
        $display("--------------------------------------");
        $finish;
    end

endmodule
