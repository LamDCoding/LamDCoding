// =============================================================================
// Hazard Detection Unit
// Detects load-use hazards and branch/jump control hazards
// =============================================================================
module hazard_detection (
    // Load-use hazard inputs
    input  wire       id_ex_mem_read,   // load instruction in EX stage
    input  wire [4:0] id_ex_rd,         // destination of load in EX stage
    input  wire [4:0] if_id_rs1,        // source 1 of instruction in ID stage
    input  wire [4:0] if_id_rs2,        // source 2 of instruction in ID stage
    // Branch/jump taken in EX stage
    input  wire       branch_taken,     // resolved branch taken signal
    input  wire       jump,             // unconditional jump (JAL/JALR)
    // Stall and flush outputs
    output reg        pc_stall,         // freeze PC
    output reg        if_id_stall,      // freeze IF/ID register
    output reg        id_ex_bubble,     // insert NOP bubble into ID/EX
    output reg        if_id_flush,      // flush IF/ID on branch taken
    output reg        id_ex_flush       // flush ID/EX on branch taken
);

    wire load_use_hazard;
    assign load_use_hazard = id_ex_mem_read &&
                             ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2)) &&
                             (id_ex_rd != 5'd0);

    always @(*) begin
        // Defaults
        pc_stall     = 1'b0;
        if_id_stall  = 1'b0;
        id_ex_bubble = 1'b0;
        if_id_flush  = 1'b0;
        id_ex_flush  = 1'b0;

        if (load_use_hazard) begin
            // Stall: freeze PC and IF/ID, insert bubble
            pc_stall     = 1'b1;
            if_id_stall  = 1'b1;
            id_ex_bubble = 1'b1;
        end

        if (branch_taken || jump) begin
            // Flush incorrectly fetched instructions
            if_id_flush = 1'b1;
            id_ex_flush = 1'b1;
        end
    end

endmodule
