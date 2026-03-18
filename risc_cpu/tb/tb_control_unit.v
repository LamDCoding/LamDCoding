// =============================================================================
// tb_control_unit.v  -  Control Unit Testbench
// Tests each opcode for correct control signal generation
// =============================================================================
`timescale 1ns/1ps

module tb_control_unit;

    reg  [6:0] opcode;
    wire       reg_write, mem_read, mem_write, alu_src, branch, jump, jalr;
    wire [1:0] mem_to_reg, alu_op;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    control_unit dut (
        .opcode    (opcode),
        .reg_write (reg_write),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .mem_to_reg(mem_to_reg),
        .alu_src   (alu_src),
        .branch    (branch),
        .jump      (jump),
        .jalr      (jalr),
        .alu_op    (alu_op)
    );

    // Expected: {reg_write, mem_read, mem_write, mem_to_reg[1:0], alu_src,
    //            branch, jump, jalr, alu_op[1:0]}
    // Total 11 bits
    task check_ctrl;
        input [31:0] test_id;
        input [6:0]  op;
        // Expected values
        input exp_reg_write;
        input exp_mem_read;
        input exp_mem_write;
        input [1:0] exp_mem_to_reg;
        input exp_alu_src;
        input exp_branch;
        input exp_jump;
        input exp_jalr;
        input [1:0] exp_alu_op;
        begin
            opcode = op; #1;
            if (reg_write  === exp_reg_write  &&
                mem_read   === exp_mem_read   &&
                mem_write  === exp_mem_write  &&
                mem_to_reg === exp_mem_to_reg &&
                alu_src    === exp_alu_src    &&
                branch     === exp_branch     &&
                jump       === exp_jump       &&
                jalr       === exp_jalr       &&
                alu_op     === exp_alu_op) begin
                $display("PASS [%0d] opcode=%b", test_id, op);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("FAIL [%0d] opcode=%b", test_id, op);
                $display("       rw=%b mr=%b mw=%b m2r=%b as=%b br=%b jp=%b jr=%b ao=%b",
                         reg_write,mem_read,mem_write,mem_to_reg,alu_src,
                         branch,jump,jalr,alu_op);
                $display("  exp rw=%b mr=%b mw=%b m2r=%b as=%b br=%b jp=%b jr=%b ao=%b",
                         exp_reg_write,exp_mem_read,exp_mem_write,exp_mem_to_reg,
                         exp_alu_src,exp_branch,exp_jump,exp_jalr,exp_alu_op);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    initial begin
        // R-type: 0110011
        // rw=1 mr=0 mw=0 m2r=00 as=0 br=0 jp=0 jr=0 ao=10
        check_ctrl(1, 7'b0110011,  1,0,0, 2'b00, 0, 0,0,0, 2'b10);

        // I-type arith: 0010011
        // rw=1 mr=0 mw=0 m2r=00 as=1 br=0 jp=0 jr=0 ao=10
        check_ctrl(2, 7'b0010011,  1,0,0, 2'b00, 1, 0,0,0, 2'b10);

        // LOAD: 0000011
        // rw=1 mr=1 mw=0 m2r=01 as=1 br=0 jp=0 jr=0 ao=00
        check_ctrl(3, 7'b0000011,  1,1,0, 2'b01, 1, 0,0,0, 2'b00);

        // STORE: 0100011
        // rw=0 mr=0 mw=1 m2r=00 as=1 br=0 jp=0 jr=0 ao=00
        check_ctrl(4, 7'b0100011,  0,0,1, 2'b00, 1, 0,0,0, 2'b00);

        // BRANCH: 1100011
        // rw=0 mr=0 mw=0 m2r=00 as=0 br=1 jp=0 jr=0 ao=01
        check_ctrl(5, 7'b1100011,  0,0,0, 2'b00, 0, 1,0,0, 2'b01);

        // JAL: 1101111
        // rw=1 mr=0 mw=0 m2r=10 as=0 br=0 jp=1 jr=0 ao=00
        check_ctrl(6, 7'b1101111,  1,0,0, 2'b10, 0, 0,1,0, 2'b00);

        // JALR: 1100111
        // rw=1 mr=0 mw=0 m2r=10 as=1 br=0 jp=0 jr=1 ao=00
        check_ctrl(7, 7'b1100111,  1,0,0, 2'b10, 1, 0,0,1, 2'b00);

        // LUI: 0110111
        // rw=1 mr=0 mw=0 m2r=11 as=1 br=0 jp=0 jr=0 ao=11
        check_ctrl(8, 7'b0110111,  1,0,0, 2'b11, 1, 0,0,0, 2'b11);

        // AUIPC: 0010111
        // rw=1 mr=0 mw=0 m2r=00 as=1 br=0 jp=0 jr=0 ao=11
        check_ctrl(9, 7'b0010111,  1,0,0, 2'b00, 1, 0,0,0, 2'b11);

        // Unknown opcode: all zeros
        check_ctrl(10, 7'b1111111,  0,0,0, 2'b00, 0, 0,0,0, 2'b00);

        $display("--------------------------------------");
        $display("CtrlUnit TB: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("ALL CONTROL UNIT TESTS PASSED");
        else
            $display("SOME CONTROL UNIT TESTS FAILED");
        $display("--------------------------------------");
        $finish;
    end

endmodule
