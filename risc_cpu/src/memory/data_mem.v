// =============================================================================
// Data Memory - 4096 x 8-bit byte-addressable RAM
// Supports: LW, LH, LB, LHU, LBU, SW, SH, SB
// =============================================================================
module data_mem #(
    parameter MEM_BYTES = 4096  // total bytes
)(
    input  wire        clk,
    input  wire [31:0] addr,       // byte address
    input  wire [31:0] wdata,      // write data
    input  wire [2:0]  funct3,     // determines access width
    input  wire        mem_read,
    input  wire        mem_write,
    output reg  [31:0] rdata       // read data
);

    reg [7:0] mem [0:MEM_BYTES-1];
    integer i;

    initial begin
        for (i = 0; i < MEM_BYTES; i = i + 1)
            mem[i] = 8'h00;
    end

    wire [11:0] a = addr[11:0]; // lower 12 bits of byte address

    // -------------------------------------------------------------------------
    // Write logic (synchronous)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (mem_write) begin
            case (funct3)
                3'b010: begin // SW
                    mem[a]   <= wdata[7:0];
                    mem[a+1] <= wdata[15:8];
                    mem[a+2] <= wdata[23:16];
                    mem[a+3] <= wdata[31:24];
                end
                3'b001: begin // SH
                    mem[a]   <= wdata[7:0];
                    mem[a+1] <= wdata[15:8];
                end
                3'b000: begin // SB
                    mem[a]   <= wdata[7:0];
                end
                default: ; // ignore undefined
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Read logic (combinational / asynchronous)
    // -------------------------------------------------------------------------
    always @(*) begin
        rdata = 32'b0;
        if (mem_read) begin
            case (funct3)
                3'b010: // LW
                    rdata = {mem[a+3], mem[a+2], mem[a+1], mem[a]};
                3'b001: // LH (sign-extended)
                    rdata = {{16{mem[a+1][7]}}, mem[a+1], mem[a]};
                3'b000: // LB (sign-extended)
                    rdata = {{24{mem[a][7]}}, mem[a]};
                3'b101: // LHU (zero-extended)
                    rdata = {16'b0, mem[a+1], mem[a]};
                3'b100: // LBU (zero-extended)
                    rdata = {24'b0, mem[a]};
                default: rdata = 32'b0;
            endcase
        end
    end

endmodule
