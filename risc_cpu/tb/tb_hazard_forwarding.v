// =============================================================================
// tb_hazard_forwarding.v  –  Hazard Detection & Forwarding Unit Testbench
// =============================================================================
`timescale 1ns/1ps

module tb_hazard_forwarding;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    // ---- Forwarding Unit ----
    reg  [4:0] id_ex_rs1, id_ex_rs2;
    reg  [4:0] ex_mem_rd;
    reg        ex_mem_reg_write;
    reg  [4:0] mem_wb_rd;
    reg        mem_wb_reg_write;
    wire [1:0] forward_a, forward_b;

    forwarding_unit dut_fwd (
        .id_ex_rs1       (id_ex_rs1),
        .id_ex_rs2       (id_ex_rs2),
        .ex_mem_rd       (ex_mem_rd),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_rd       (mem_wb_rd),
        .mem_wb_reg_write(mem_wb_reg_write),
        .forward_a       (forward_a),
        .forward_b       (forward_b)
    );

    // ---- Hazard Detection Unit ----
    reg        id_ex_mem_read;
    reg  [4:0] id_ex_rd;
    reg  [4:0] if_id_rs1, if_id_rs2;
    reg        branch_taken, jump;
    wire       pc_stall, if_id_stall, id_ex_bubble;
    wire       if_id_flush, id_ex_flush;

    hazard_detection dut_haz (
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_rd      (id_ex_rd),
        .if_id_rs1     (if_id_rs1),
        .if_id_rs2     (if_id_rs2),
        .branch_taken  (branch_taken),
        .jump          (jump),
        .pc_stall      (pc_stall),
        .if_id_stall   (if_id_stall),
        .id_ex_bubble  (id_ex_bubble),
        .if_id_flush   (if_id_flush),
        .id_ex_flush   (id_ex_flush)
    );

    task check_fwd;
        input [31:0] test_id;
        input [1:0] exp_fa, exp_fb;
        begin
            #1;
            if (forward_a === exp_fa && forward_b === exp_fb) begin
                $display("PASS [FWD%0d] fa=%b fb=%b", test_id, forward_a, forward_b);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("FAIL [FWD%0d] fa=%b fb=%b (exp fa=%b fb=%b)",
                         test_id, forward_a, forward_b, exp_fa, exp_fb);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task check_haz;
        input [31:0] test_id;
        input exp_stall, exp_bubble, exp_flush_if, exp_flush_id;
        begin
            #1;
            if (pc_stall     === exp_stall &&
                if_id_stall  === exp_stall &&
                id_ex_bubble === exp_bubble &&
                if_id_flush  === exp_flush_if &&
                id_ex_flush  === exp_flush_id) begin
                $display("PASS [HAZ%0d] stall=%b bubble=%b flush_if=%b flush_id=%b",
                         test_id, pc_stall, id_ex_bubble, if_id_flush, id_ex_flush);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("FAIL [HAZ%0d] stall=%b bubble=%b flush_if=%b flush_id=%b (exp %b %b %b %b)",
                         test_id, pc_stall, id_ex_bubble, if_id_flush, id_ex_flush,
                         exp_stall, exp_bubble, exp_flush_if, exp_flush_id);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    initial begin
        // =====================================================================
        // Forwarding Unit Tests
        // =====================================================================

        // Test FWD1: No hazard (rd=0)
        id_ex_rs1 = 5'd3; id_ex_rs2 = 5'd4;
        ex_mem_rd = 5'd0; ex_mem_reg_write = 1'b1;
        mem_wb_rd = 5'd0; mem_wb_reg_write = 1'b1;
        check_fwd(1, 2'b00, 2'b00);

        // Test FWD2: No hazard (reg_write=0)
        id_ex_rs1 = 5'd3; id_ex_rs2 = 5'd4;
        ex_mem_rd = 5'd3; ex_mem_reg_write = 1'b0;
        mem_wb_rd = 5'd4; mem_wb_reg_write = 1'b0;
        check_fwd(2, 2'b00, 2'b00);

        // Test FWD3: EX/MEM forward for rs1
        id_ex_rs1 = 5'd5; id_ex_rs2 = 5'd6;
        ex_mem_rd = 5'd5; ex_mem_reg_write = 1'b1;
        mem_wb_rd = 5'd0; mem_wb_reg_write = 1'b0;
        check_fwd(3, 2'b10, 2'b00);

        // Test FWD4: EX/MEM forward for rs2
        id_ex_rs1 = 5'd1; id_ex_rs2 = 5'd7;
        ex_mem_rd = 5'd7; ex_mem_reg_write = 1'b1;
        mem_wb_rd = 5'd0; mem_wb_reg_write = 1'b0;
        check_fwd(4, 2'b00, 2'b10);

        // Test FWD5: MEM/WB forward for rs1
        id_ex_rs1 = 5'd8; id_ex_rs2 = 5'd9;
        ex_mem_rd = 5'd0; ex_mem_reg_write = 1'b0;
        mem_wb_rd = 5'd8; mem_wb_reg_write = 1'b1;
        check_fwd(5, 2'b01, 2'b00);

        // Test FWD6: MEM/WB forward for rs2
        id_ex_rs1 = 5'd1; id_ex_rs2 = 5'd9;
        ex_mem_rd = 5'd0; ex_mem_reg_write = 1'b0;
        mem_wb_rd = 5'd9; mem_wb_reg_write = 1'b1;
        check_fwd(6, 2'b00, 2'b01);

        // Test FWD7: EX/MEM takes priority over MEM/WB
        id_ex_rs1 = 5'd10; id_ex_rs2 = 5'd10;
        ex_mem_rd = 5'd10; ex_mem_reg_write = 1'b1;
        mem_wb_rd = 5'd10; mem_wb_reg_write = 1'b1;
        check_fwd(7, 2'b10, 2'b10);

        // Test FWD8: Both ports forward from different stages
        id_ex_rs1 = 5'd11; id_ex_rs2 = 5'd12;
        ex_mem_rd = 5'd11; ex_mem_reg_write = 1'b1;
        mem_wb_rd = 5'd12; mem_wb_reg_write = 1'b1;
        check_fwd(8, 2'b10, 2'b01);

        // =====================================================================
        // Hazard Detection Tests
        // =====================================================================

        // Test HAZ1: No hazard
        id_ex_mem_read = 1'b0; id_ex_rd = 5'd5;
        if_id_rs1 = 5'd3; if_id_rs2 = 5'd4;
        branch_taken = 1'b0; jump = 1'b0;
        check_haz(1, 0, 0, 0, 0);

        // Test HAZ2: Load-use hazard on rs1
        id_ex_mem_read = 1'b1; id_ex_rd = 5'd3;
        if_id_rs1 = 5'd3; if_id_rs2 = 5'd6;
        branch_taken = 1'b0; jump = 1'b0;
        check_haz(2, 1, 1, 0, 0);

        // Test HAZ3: Load-use hazard on rs2
        id_ex_mem_read = 1'b1; id_ex_rd = 5'd6;
        if_id_rs1 = 5'd3; if_id_rs2 = 5'd6;
        branch_taken = 1'b0; jump = 1'b0;
        check_haz(3, 1, 1, 0, 0);

        // Test HAZ4: Load-use but rd=0 (no hazard)
        id_ex_mem_read = 1'b1; id_ex_rd = 5'd0;
        if_id_rs1 = 5'd0; if_id_rs2 = 5'd0;
        branch_taken = 1'b0; jump = 1'b0;
        check_haz(4, 0, 0, 0, 0);

        // Test HAZ5: Branch taken → flush
        id_ex_mem_read = 1'b0; id_ex_rd = 5'd1;
        if_id_rs1 = 5'd3; if_id_rs2 = 5'd4;
        branch_taken = 1'b1; jump = 1'b0;
        check_haz(5, 0, 0, 1, 1);

        // Test HAZ6: Jump → flush
        id_ex_mem_read = 1'b0; id_ex_rd = 5'd1;
        if_id_rs1 = 5'd3; if_id_rs2 = 5'd4;
        branch_taken = 1'b0; jump = 1'b1;
        check_haz(6, 0, 0, 1, 1);

        // Test HAZ7: Load-use + branch taken (both active)
        id_ex_mem_read = 1'b1; id_ex_rd = 5'd3;
        if_id_rs1 = 5'd3; if_id_rs2 = 5'd4;
        branch_taken = 1'b1; jump = 1'b0;
        // stall from load-use AND flush from branch
        // In our implementation, both conditions fire
        #1;
        if (pc_stall && id_ex_bubble && if_id_flush && id_ex_flush) begin
            $display("PASS [HAZ7] load-use+branch: stall+bubble+flush all set");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL [HAZ7] expected all hazard signals set");
            fail_cnt = fail_cnt + 1;
        end

        $display("--------------------------------------");
        $display("Hazard+Fwd TB: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("ALL HAZARD/FORWARDING TESTS PASSED");
        else
            $display("SOME HAZARD/FORWARDING TESTS FAILED");
        $display("--------------------------------------");
        $finish;
    end

endmodule
