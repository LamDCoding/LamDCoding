// =============================================================================
// UART Transmitter - 8N1
// Configurable baud rate via CLKS_PER_BIT parameter
// Interface: valid/ready handshake, TX-only
// =============================================================================
module uart_tx #(
    parameter CLKS_PER_BIT = 868  // 100 MHz / 115200 baud ≈ 868
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_valid,    // data valid strobe
    input  wire [7:0] tx_data,     // byte to transmit
    output reg        tx_ready,    // ready to accept new byte
    output reg        tx,          // serial output line
    output reg        tx_done      // pulses high for one cycle when byte complete
);

    // State machine states
    localparam ST_IDLE  = 2'd0;
    localparam ST_START = 2'd1;
    localparam ST_DATA  = 2'd2;
    localparam ST_STOP  = 2'd3;

    reg [1:0]  state;
    reg [31:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= ST_IDLE;
            tx       <= 1'b1;   // UART idle high
            tx_ready <= 1'b1;
            tx_done  <= 1'b0;
            clk_cnt  <= 32'd0;
            bit_idx  <= 3'd0;
            shift_reg<= 8'd0;
        end else begin
            tx_done <= 1'b0;
            case (state)
                ST_IDLE: begin
                    tx       <= 1'b1;
                    tx_ready <= 1'b1;
                    if (tx_valid) begin
                        shift_reg <= tx_data;
                        tx_ready  <= 1'b0;
                        clk_cnt   <= 32'd0;
                        state     <= ST_START;
                    end
                end

                ST_START: begin
                    tx <= 1'b0;  // start bit
                    if (clk_cnt < CLKS_PER_BIT - 1)
                        clk_cnt <= clk_cnt + 1;
                    else begin
                        clk_cnt <= 32'd0;
                        bit_idx <= 3'd0;
                        state   <= ST_DATA;
                    end
                end

                ST_DATA: begin
                    tx <= shift_reg[bit_idx];
                    if (clk_cnt < CLKS_PER_BIT - 1)
                        clk_cnt <= clk_cnt + 1;
                    else begin
                        clk_cnt <= 32'd0;
                        if (bit_idx == 3'd7) begin
                            state <= ST_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end
                end

                ST_STOP: begin
                    tx <= 1'b1;  // stop bit
                    if (clk_cnt < CLKS_PER_BIT - 1)
                        clk_cnt <= clk_cnt + 1;
                    else begin
                        tx_done <= 1'b1;
                        state   <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
