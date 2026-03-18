// =============================================================================
// Register File - 32 x 32-bit RISC-V Register File
// x0 hardwired to zero
// Synchronous write, asynchronous read
// =============================================================================
module register_file (
    input  wire        clk,
    input  wire        rst_n,
    // Read port 1
    input  wire [4:0]  rs1,
    output wire [31:0] rs1_data,
    // Read port 2
    input  wire [4:0]  rs2,
    output wire [31:0] rs2_data,
    // Write port
    input  wire [4:0]  rd,
    input  wire [31:0] rd_data,
    input  wire        reg_write
);

    reg [31:0] regs [0:31];
    integer i;

    // Asynchronous read with x0 = 0 enforcement
    assign rs1_data = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
    assign rs2_data = (rs2 == 5'd0) ? 32'd0 : regs[rs2];

    // Synchronous write; x0 is never written
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (reg_write && (rd != 5'd0)) begin
            regs[rd] <= rd_data;
        end
    end

endmodule
