// =============================================================================
// IF/ID Pipeline Register
// Holds fetched instruction and PC values between IF and ID stages
// =============================================================================
module if_id_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,   // hold current values
    input  wire        flush,   // insert NOP bubble
    // Inputs from IF stage
    input  wire [31:0] if_pc,
    input  wire [31:0] if_pc_plus4,
    input  wire [31:0] if_instr,
    // Outputs to ID stage
    output reg  [31:0] id_pc,
    output reg  [31:0] id_pc_plus4,
    output reg  [31:0] id_instr
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_pc       <= 32'b0;
            id_pc_plus4 <= 32'b0;
            id_instr    <= 32'h0000_0013; // ADDI x0, x0, 0 = NOP
        end else if (flush) begin
            id_pc       <= 32'b0;
            id_pc_plus4 <= 32'b0;
            id_instr    <= 32'h0000_0013; // NOP bubble
        end else if (!stall) begin
            id_pc       <= if_pc;
            id_pc_plus4 <= if_pc_plus4;
            id_instr    <= if_instr;
        end
        // If stall and not flush: hold current values (no else needed)
    end

endmodule
