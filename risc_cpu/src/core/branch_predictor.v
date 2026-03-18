// =============================================================================
// Branch Predictor - 2-bit Saturating Counter
// 16-entry Branch History Table (BHT), indexed by PC[5:2]
// States: SN=00 (Strongly Not Taken), WN=01 (Weakly Not Taken),
//         WT=10 (Weakly Taken), ST=11 (Strongly Taken)
// =============================================================================
module branch_predictor (
    input  wire        clk,
    input  wire        rst_n,
    // Predict interface (IF stage)
    input  wire [31:0] pc,
    output wire        predict_taken,
    // Update interface (EX stage)
    input  wire [31:0] ex_pc,          // PC of the branch being resolved
    input  wire        ex_is_branch,   // 1 if instruction in EX is a branch
    input  wire        ex_actual_taken // actual outcome
);

    localparam ENTRIES = 16;
    localparam SN = 2'b00;
    localparam WN = 2'b01;
    localparam WT = 2'b10;
    localparam ST = 2'b11;

    reg [1:0] bht [0:ENTRIES-1];
    integer i;

    wire [3:0] pred_idx   = pc[5:2];
    wire [3:0] update_idx = ex_pc[5:2];

    // Predict: taken if MSB of counter is 1
    assign predict_taken = bht[pred_idx][1];

    // Update BHT on branch resolution
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < ENTRIES; i = i + 1)
                bht[i] <= WN; // weakly not-taken initial state
        end else if (ex_is_branch) begin
            case (bht[update_idx])
                SN: bht[update_idx] <= ex_actual_taken ? WN : SN;
                WN: bht[update_idx] <= ex_actual_taken ? WT : SN;
                WT: bht[update_idx] <= ex_actual_taken ? ST : WN;
                ST: bht[update_idx] <= ex_actual_taken ? ST : WT;
                default: bht[update_idx] <= WN;
            endcase
        end
    end

endmodule
