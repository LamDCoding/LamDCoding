// =============================================================================
// ALU - 32-bit Arithmetic Logic Unit
// RISC-V RV32I compliant
// =============================================================================
module alu (
    input  wire [31:0] a,          // Operand A (rs1 or PC)
    input  wire [31:0] b,          // Operand B (rs2 or immediate)
    input  wire [3:0]  alu_ctrl,   // ALU control signal
    output reg  [31:0] result,     // ALU result
    output wire        zero,       // Zero flag
    output wire        negative,   // Negative flag (bit 31)
    output reg         overflow,   // Signed overflow flag
    output reg         carry_out   // Unsigned carry out
);

    // ALU operation encodings
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_PASSB= 4'b1010;  // LUI: pass B
    localparam ALU_APCADD = 4'b1011; // AUIPC: PC + imm (same as ADD)

    wire [32:0] sum;
    wire [32:0] diff;

    assign sum  = {1'b0, a} + {1'b0, b};
    assign diff = {1'b0, a} - {1'b0, b};

    assign zero     = (result == 32'b0);
    assign negative = result[31];

    always @(*) begin
        carry_out = 1'b0;
        overflow  = 1'b0;
        case (alu_ctrl)
            ALU_ADD, ALU_APCADD: begin
                result    = sum[31:0];
                carry_out = sum[32];
                overflow  = (a[31] == b[31]) && (result[31] != a[31]);
            end
            ALU_SUB: begin
                result    = diff[31:0];
                carry_out = diff[32];  // borrow
                overflow  = (a[31] != b[31]) && (result[31] != a[31]);
            end
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = $signed(a) >>> b[4:0];
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
            ALU_PASSB: result = b;  // LUI passes immediate directly
            default:   result = 32'b0;
        endcase
    end

endmodule
