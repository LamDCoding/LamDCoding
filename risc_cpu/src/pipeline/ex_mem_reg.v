// =============================================================================
// EX/MEM Pipeline Register
// Holds execution results and control signals between EX and MEM stages
// =============================================================================
module ex_mem_reg (
    input  wire        clk,
    input  wire        rst_n,
    // Inputs from EX stage
    input  wire [31:0] ex_pc_plus4,
    input  wire [31:0] ex_branch_target,
    input  wire [31:0] ex_alu_result,
    input  wire [31:0] ex_rs2_data,       // store data
    input  wire [4:0]  ex_rd,
    input  wire [2:0]  ex_funct3,
    input  wire        ex_zero,
    input  wire        ex_branch_taken,
    // Control signals
    input  wire        ex_reg_write,
    input  wire        ex_mem_read,
    input  wire        ex_mem_write,
    input  wire [1:0]  ex_mem_to_reg,
    input  wire        ex_branch,
    input  wire        ex_jump,
    // Outputs to MEM stage
    output reg  [31:0] mem_pc_plus4,
    output reg  [31:0] mem_branch_target,
    output reg  [31:0] mem_alu_result,
    output reg  [31:0] mem_rs2_data,
    output reg  [4:0]  mem_rd,
    output reg  [2:0]  mem_funct3,
    output reg         mem_zero,
    output reg         mem_branch_taken,
    output reg         mem_reg_write,
    output reg         mem_mem_read,
    output reg         mem_mem_write,
    output reg  [1:0]  mem_mem_to_reg,
    output reg         mem_branch,
    output reg         mem_jump
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_pc_plus4     <= 32'b0;
            mem_branch_target<= 32'b0;
            mem_alu_result   <= 32'b0;
            mem_rs2_data     <= 32'b0;
            mem_rd           <= 5'b0;
            mem_funct3       <= 3'b0;
            mem_zero         <= 1'b0;
            mem_branch_taken <= 1'b0;
            mem_reg_write    <= 1'b0;
            mem_mem_read     <= 1'b0;
            mem_mem_write    <= 1'b0;
            mem_mem_to_reg   <= 2'b0;
            mem_branch       <= 1'b0;
            mem_jump         <= 1'b0;
        end else begin
            mem_pc_plus4     <= ex_pc_plus4;
            mem_branch_target<= ex_branch_target;
            mem_alu_result   <= ex_alu_result;
            mem_rs2_data     <= ex_rs2_data;
            mem_rd           <= ex_rd;
            mem_funct3       <= ex_funct3;
            mem_zero         <= ex_zero;
            mem_branch_taken <= ex_branch_taken;
            mem_reg_write    <= ex_reg_write;
            mem_mem_read     <= ex_mem_read;
            mem_mem_write    <= ex_mem_write;
            mem_mem_to_reg   <= ex_mem_to_reg;
            mem_branch       <= ex_branch;
            mem_jump         <= ex_jump;
        end
    end

endmodule
