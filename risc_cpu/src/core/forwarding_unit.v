// =============================================================================
// Forwarding Unit
// Resolves EX/MEM and MEM/WB data hazards through bypass paths
// =============================================================================
module forwarding_unit (
    // ID/EX source registers
    input  wire [4:0] id_ex_rs1,
    input  wire [4:0] id_ex_rs2,
    // EX/MEM destination
    input  wire [4:0] ex_mem_rd,
    input  wire       ex_mem_reg_write,
    // MEM/WB destination
    input  wire [4:0] mem_wb_rd,
    input  wire       mem_wb_reg_write,
    // Forward select outputs
    // 2'b00 = no forward (use register file)
    // 2'b10 = forward from EX/MEM stage
    // 2'b01 = forward from MEM/WB stage
    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b
);

    always @(*) begin
        // Forward A (rs1)
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1))
            forward_a = 2'b10;  // EX/MEM forward (higher priority)
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1))
            forward_a = 2'b01;  // MEM/WB forward
        else
            forward_a = 2'b00;  // no forward

        // Forward B (rs2)
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2))
            forward_b = 2'b10;  // EX/MEM forward
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2))
            forward_b = 2'b01;  // MEM/WB forward
        else
            forward_b = 2'b00;  // no forward
    end

endmodule
