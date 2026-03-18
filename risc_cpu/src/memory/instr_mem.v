// =============================================================================
// Instruction Memory - 1024 x 32-bit word ROM
// Initialized from instr_mem.hex via $readmemh
// =============================================================================
module instr_mem #(
    parameter MEM_SIZE  = 1024,           // number of 32-bit words
    parameter HEX_FILE  = "instr_mem.hex" // hex initialization file
)(
    input  wire [31:0] addr,    // byte address (word-aligned)
    output wire [31:0] instr
);

    reg [31:0] mem [0:MEM_SIZE-1];
    integer i;

    initial begin
        // Initialize to NOP (ADDI x0,x0,0)
        for (i = 0; i < MEM_SIZE; i = i + 1)
            mem[i] = 32'h0000_0013;
        // Load program; $readmemh ignores missing file in some tools,
        // hence the NOP pre-fill above.
        $readmemh(HEX_FILE, mem);
    end

    // Word-addressed read (byte address >> 2)
    assign instr = mem[addr[11:2]];

endmodule
