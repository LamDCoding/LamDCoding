// =============================================================================
// ALU Decoder
// Translates alu_op + funct3 + funct7[5] into 4-bit alu_ctrl
// =============================================================================
module alu_decoder (
    input  wire [1:0] alu_op,
    input  wire [2:0] funct3,
    input  wire       funct7_5,   // funct7[5] distinguishes ADD/SUB, SRL/SRA
    input  wire [6:0] opcode,     // needed to distinguish I-type SRLI vs R-type SRA
    output reg  [3:0] alu_ctrl
);

    // ALU control encodings (match alu.v)
    localparam ALU_ADD   = 4'b0000;
    localparam ALU_SUB   = 4'b0001;
    localparam ALU_AND   = 4'b0010;
    localparam ALU_OR    = 4'b0011;
    localparam ALU_XOR   = 4'b0100;
    localparam ALU_SLL   = 4'b0101;
    localparam ALU_SRL   = 4'b0110;
    localparam ALU_SRA   = 4'b0111;
    localparam ALU_SLT   = 4'b1000;
    localparam ALU_SLTU  = 4'b1001;
    localparam ALU_PASSB = 4'b1010;  // LUI
    localparam ALU_APCADD= 4'b1011; // AUIPC

    localparam OP_R_TYPE = 7'b0110011;

    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = ALU_ADD;   // Load/Store: address = base + offset
            2'b01: alu_ctrl = ALU_SUB;   // Branch compare (zero check)
            2'b11: begin
                // LUI (pass B) vs AUIPC (PC+imm = ADD)
                // Control unit sets alu_op=11 for both LUI and AUIPC
                // Differentiated by opcode passed through pipeline
                // For simplicity: LUI uses PASSB, AUIPC uses ADD
                // The pipeline passes opcode-derived signal; we use funct7_5 as a proxy
                // Actually: the immediate_gen already shifts correctly, the ALU just adds.
                // For LUI we pass mem_to_reg=11 and the immediate directly.
                // We still call this path for AUIPC (needs ADD).
                // Use funct7_5 = 1 to signal LUI (set by control_unit proxy).
                if (funct7_5)
                    alu_ctrl = ALU_PASSB;
                else
                    alu_ctrl = ALU_ADD;  // AUIPC: PC + imm
            end
            2'b10: begin
                // R-type and I-type arithmetic
                case (funct3)
                    3'b000: begin
                        // ADD/SUB (R) or ADDI (I)
                        if (funct7_5 && (opcode == OP_R_TYPE))
                            alu_ctrl = ALU_SUB;
                        else
                            alu_ctrl = ALU_ADD;
                    end
                    3'b001: alu_ctrl = ALU_SLL;
                    3'b010: alu_ctrl = ALU_SLT;
                    3'b011: alu_ctrl = ALU_SLTU;
                    3'b100: alu_ctrl = ALU_XOR;
                    3'b101: begin
                        // SRL/SRA
                        if (funct7_5)
                            alu_ctrl = ALU_SRA;
                        else
                            alu_ctrl = ALU_SRL;
                    end
                    3'b110: alu_ctrl = ALU_OR;
                    3'b111: alu_ctrl = ALU_AND;
                    default: alu_ctrl = ALU_ADD;
                endcase
            end
            default: alu_ctrl = ALU_ADD;
        endcase
    end

endmodule
