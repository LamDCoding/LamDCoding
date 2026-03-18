// =============================================================================
// GPIO Peripheral
// 16-bit output (LEDs), 16-bit input (switches)
// Memory-mapped: base+0 = output register, base+4 = input register
// =============================================================================
module gpio (
    input  wire        clk,
    input  wire        rst_n,
    // CPU interface (word-aligned addresses)
    input  wire [3:0]  addr,        // [3:2] selects register (lower 2 bits ignored)
    input  wire [31:0] wdata,
    input  wire        we,          // write enable
    output reg  [31:0] rdata,
    // Physical I/O
    output reg  [15:0] gpio_out,    // LED outputs
    input  wire [15:0] gpio_in      // switch inputs
);

    // Register map
    // offset 0x0: GPIO output (read/write)
    // offset 0x4: GPIO input  (read-only)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            gpio_out <= 16'h0000;
        else if (we && (addr[3:2] == 2'b00))
            gpio_out <= wdata[15:0];
    end

    always @(*) begin
        case (addr[3:2])
            2'b00:   rdata = {16'b0, gpio_out};
            2'b01:   rdata = {16'b0, gpio_in};
            default: rdata = 32'b0;
        endcase
    end

endmodule
