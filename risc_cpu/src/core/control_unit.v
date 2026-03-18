// =============================================================================
// Control Unit - Main decode stage control signal generator
// Decodes opcode into all pipeline control signals
// =============================================================================
module control_unit (
    input  wire [6:0] opcode,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg  [1:0] mem_to_reg,  // 00=ALU, 01=Mem, 10=PC+4, 11=Imm(LUI)
    output reg        alu_src,     // 0=rs2, 1=immediate
    output reg        branch,
    output reg        jump,        // JAL
    output reg        jalr,        // JALR
    output reg  [1:0] alu_op       // 00=ADD, 01=SUB(branch), 10=decode, 11=special
);

    // Opcode definitions (RV32I)
    localparam OP_R_TYPE = 7'b0110011; // R-type
    localparam OP_I_ARITH= 7'b0010011; // I-type arithmetic
    localparam OP_LOAD   = 7'b0000011; // Load
    localparam OP_STORE  = 7'b0100011; // Store
    localparam OP_BRANCH = 7'b1100011; // Branch
    localparam OP_JAL    = 7'b1101111; // JAL
    localparam OP_JALR   = 7'b1100111; // JALR
    localparam OP_LUI    = 7'b0110111; // LUI
    localparam OP_AUIPC  = 7'b0010111; // AUIPC

    always @(*) begin
        // Safe defaults
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 2'b00;
        alu_src    = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        jalr       = 1'b0;
        alu_op     = 2'b00;

        case (opcode)
            OP_R_TYPE: begin
                reg_write  = 1'b1;
                alu_op     = 2'b10; // ALU decoder uses funct3/funct7
            end

            OP_I_ARITH: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;  // immediate
                alu_op     = 2'b10;
            end

            OP_LOAD: begin
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                alu_src    = 1'b1;
                mem_to_reg = 2'b01; // write-back from memory
                alu_op     = 2'b00; // ADD for address
            end

            OP_STORE: begin
                mem_write  = 1'b1;
                alu_src    = 1'b1;
                alu_op     = 2'b00; // ADD for address
            end

            OP_BRANCH: begin
                branch     = 1'b1;
                alu_op     = 2'b01; // SUB/compare
            end

            OP_JAL: begin
                reg_write  = 1'b1;
                jump       = 1'b1;
                mem_to_reg = 2'b10; // PC+4 as return address
                alu_op     = 2'b00;
            end

            OP_JALR: begin
                reg_write  = 1'b1;
                jalr       = 1'b1;
                alu_src    = 1'b1;
                mem_to_reg = 2'b10; // PC+4 as return address
                alu_op     = 2'b00; // ADD for target address
            end

            OP_LUI: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_to_reg = 2'b11; // immediate direct
                alu_op     = 2'b11; // pass-B
            end

            OP_AUIPC: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                alu_op     = 2'b11; // AUIPC: PC + imm, treated as special ADD
            end

            default: begin
                // NOP / illegal — all signals remain at safe defaults
            end
        endcase
    end

endmodule
