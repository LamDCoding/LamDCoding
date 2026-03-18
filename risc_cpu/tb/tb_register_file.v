// =============================================================================
// tb_register_file.v  -  Register File Testbench
// Tests read/write, x0 hardwired to 0, two read ports
// =============================================================================
`timescale 1ns/1ps

module tb_register_file;

    reg        clk, rst_n;
    reg  [4:0] rs1, rs2, rd;
    reg  [31:0]rd_data;
    reg        reg_write;
    wire [31:0]rs1_data, rs2_data;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    register_file dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1      (rs1),
        .rs1_data (rs1_data),
        .rs2      (rs2),
        .rs2_data (rs2_data),
        .rd       (rd),
        .rd_data  (rd_data),
        .reg_write(reg_write)
    );

    always #5 clk = ~clk;

    task write_reg;
        input [4:0]  reg_addr;
        input [31:0] data;
        begin
            @(negedge clk);
            rd = reg_addr; rd_data = data; reg_write = 1'b1;
            @(posedge clk); #1;
            reg_write = 1'b0;
        end
    endtask

    task check_read1;
        input [31:0] test_id;
        input [4:0]  addr;
        input [31:0] expected;
        begin
            rs1 = addr;
            #1;
            if (rs1_data === expected) begin
                $display("PASS [%0d] read x%0d = 0x%08h", test_id, addr, rs1_data);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("FAIL [%0d] read x%0d: got=0x%08h exp=0x%08h",
                         test_id, addr, rs1_data, expected);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task check_read2;
        input [31:0] test_id;
        input [4:0]  addr;
        input [31:0] expected;
        begin
            rs2 = addr;
            #1;
            if (rs2_data === expected) begin
                $display("PASS [%0d] read2 x%0d = 0x%08h", test_id, addr, rs2_data);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("FAIL [%0d] read2 x%0d: got=0x%08h exp=0x%08h",
                         test_id, addr, rs2_data, expected);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; reg_write = 0;
        rs1 = 0; rs2 = 0; rd = 0; rd_data = 0;
        #12; rst_n = 1;

        // Test 1: x0 always reads 0
        check_read1(1, 5'd0, 32'd0);
        check_read2(2, 5'd0, 32'd0);

        // Test 2: write to x0 should NOT change its value
        write_reg(5'd0, 32'hDEAD_BEEF);
        check_read1(3, 5'd0, 32'd0);

        // Test 3: write and read x1
        write_reg(5'd1, 32'hAAAA_AAAA);
        check_read1(4, 5'd1, 32'hAAAA_AAAA);

        // Test 4: write and read x31
        write_reg(5'd31, 32'h1234_5678);
        check_read1(5, 5'd31, 32'h1234_5678);

        // Test 5: both read ports simultaneously
        write_reg(5'd2, 32'hBEEF_CAFE);
        rs1 = 5'd1; rs2 = 5'd2;
        #1;
        if (rs1_data === 32'hAAAA_AAAA && rs2_data === 32'hBEEF_CAFE) begin
            $display("PASS [6] dual-port read x1=0x%08h x2=0x%08h", rs1_data, rs2_data);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL [6] dual-port read x1=0x%08h x2=0x%08h", rs1_data, rs2_data);
            fail_cnt = fail_cnt + 1;
        end

        // Test 6: overwrite x1
        write_reg(5'd1, 32'h0000_0001);
        check_read1(7, 5'd1, 32'h0000_0001);

        // Test 7: reg_write=0 should not change value
        @(negedge clk);
        rd = 5'd1; rd_data = 32'hFFFF_FFFF; reg_write = 1'b0;
        @(posedge clk); #1;
        check_read1(8, 5'd1, 32'h0000_0001); // should still be 1

        // Test 8: write multiple registers, check all
        write_reg(5'd5,  32'd100);
        write_reg(5'd10, 32'd200);
        write_reg(5'd15, 32'd300);
        check_read1(9,  5'd5,  32'd100);
        check_read1(10, 5'd10, 32'd200);
        check_read1(11, 5'd15, 32'd300);
        check_read2(12, 5'd5,  32'd100);

        $display("--------------------------------------");
        $display("RegFile TB: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("ALL REGISTER FILE TESTS PASSED");
        else
            $display("SOME REGISTER FILE TESTS FAILED");
        $display("--------------------------------------");
        $finish;
    end

endmodule
