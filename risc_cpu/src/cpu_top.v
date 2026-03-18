// =============================================================================
// cpu_top.v  –  5-Stage Pipelined RISC-V RV32I CPU
//
// Pipeline stages: IF → ID → EX → MEM → WB
//
// Features:
//   • Full RV32I instruction set
//   • Data forwarding (EX/MEM and MEM/WB bypass)
//   • Load-use hazard stall
//   • Branch resolved in EX stage with flush
//   • 2-bit saturating counter branch predictor
//   • UART TX peripheral
//   • GPIO peripheral (LEDs / switches)
//
// Memory map (data):
//   0x0000_0000 – 0x0000_0FFF  : Data RAM (4 KB)
//   0x1000_0000                : GPIO base
//   0x2000_0000                : UART TX data register
// =============================================================================

`timescale 1ns/1ps

module cpu_top #(
    parameter IMEM_HEX     = "instr_mem.hex",
    parameter UART_BPS     = 868        // CLKS_PER_BIT for UART
)(
    input  wire        clk,
    input  wire        rst_n,
    // GPIO
    output wire [15:0] gpio_out,
    input  wire [15:0] gpio_in,
    // UART
    output wire        uart_tx_pin,
    // Debug
    output wire [31:0] dbg_pc,
    output wire [31:0] dbg_reg_x10    // a0
);

    // =========================================================================
    // 0. Wires / nets
    // =========================================================================

    // --- IF stage ---
    reg  [31:0] pc;
    wire [31:0] pc_plus4     = pc + 4;
    wire [31:0] if_instr;

    // --- IF/ID outputs ---
    wire [31:0] id_pc, id_pc_plus4, id_instr;

    // --- ID stage decode ---
    wire [6:0]  id_opcode  = id_instr[6:0];
    wire [4:0]  id_rs1_addr= id_instr[19:15];
    wire [4:0]  id_rs2_addr= id_instr[24:20];
    wire [4:0]  id_rd_addr = id_instr[11:7];
    wire [2:0]  id_funct3  = id_instr[14:12];
    wire [6:0]  id_funct7  = id_instr[31:25];

    wire [31:0] id_rs1_data, id_rs2_data;
    wire [31:0] id_imm;

    // Control signals from ID
    wire        id_reg_write, id_mem_read, id_mem_write;
    wire [1:0]  id_mem_to_reg;
    wire        id_alu_src, id_branch, id_jump, id_jalr;
    wire [1:0]  id_alu_op;

    // --- ID/EX outputs ---
    wire [31:0] ex_pc, ex_pc_plus4;
    wire [31:0] ex_rs1_data, ex_rs2_data, ex_imm;
    wire [4:0]  ex_rs1, ex_rs2, ex_rd;
    wire [2:0]  ex_funct3;
    wire [6:0]  ex_funct7, ex_opcode;
    wire        ex_reg_write, ex_mem_read, ex_mem_write;
    wire [1:0]  ex_mem_to_reg;
    wire        ex_alu_src, ex_branch, ex_jump, ex_jalr;
    wire [1:0]  ex_alu_op;

    // --- EX stage ---
    wire [3:0]  ex_alu_ctrl;
    wire [31:0] ex_alu_a, ex_alu_b_pre, ex_alu_b;
    wire [31:0] ex_alu_result;
    wire        ex_alu_zero;
    wire [31:0] ex_branch_target;
    wire [31:0] ex_jalr_target;
    wire        ex_branch_taken;
    wire        ex_take_jump;

    // Forwarding
    wire [1:0]  forward_a, forward_b;
    wire [31:0] ex_fwd_a, ex_fwd_b;

    // WB result (needed for MEM/WB→EX forwarding)
    wire [31:0] wb_result;

    // --- EX/MEM outputs ---
    wire [31:0] mem_pc_plus4, mem_branch_target;
    wire [31:0] mem_alu_result, mem_rs2_data;
    wire [4:0]  mem_rd;
    wire [2:0]  mem_funct3;
    wire        mem_zero, mem_branch_taken;
    wire        mem_reg_write, mem_mem_read, mem_mem_write;
    wire [1:0]  mem_mem_to_reg;
    wire        mem_branch, mem_jump;

    // --- MEM stage ---
    wire [31:0] mem_read_data;
    wire        dmem_we;
    wire [31:0] dmem_addr;

    // --- MEM/WB outputs ---
    wire [31:0] wb_pc_plus4, wb_alu_result, wb_read_data;
    wire [4:0]  wb_rd;
    wire        wb_reg_write;
    wire [1:0]  wb_mem_to_reg;

    // --- Hazard signals ---
    wire        pc_stall, if_id_stall, id_ex_bubble;
    wire        if_id_flush, id_ex_flush;

    // --- Branch predictor ---
    wire        bp_predict_taken;

    // =========================================================================
    // 1. IF Stage – Instruction Fetch
    // =========================================================================

    // Next-PC logic
    wire [31:0] branch_pc    = mem_branch_target;  // resolved in EX (now MEM stage reg)
    wire        actual_flush = mem_branch_taken || mem_jump;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'h0000_0000;
        else if (!pc_stall) begin
            if (actual_flush)
                pc <= branch_pc;
            else
                pc <= pc_plus4;
        end
    end

    instr_mem #(
        .HEX_FILE(IMEM_HEX)
    ) u_imem (
        .addr (pc),
        .instr(if_instr)
    );

    // =========================================================================
    // 2. IF/ID Pipeline Register
    // =========================================================================

    if_id_reg u_if_id (
        .clk        (clk),
        .rst_n      (rst_n),
        .stall      (if_id_stall),
        .flush      (if_id_flush),
        .if_pc      (pc),
        .if_pc_plus4(pc_plus4),
        .if_instr   (if_instr),
        .id_pc      (id_pc),
        .id_pc_plus4(id_pc_plus4),
        .id_instr   (id_instr)
    );

    // =========================================================================
    // 3. ID Stage – Instruction Decode
    // =========================================================================

    register_file u_regfile (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1      (id_rs1_addr),
        .rs1_data (id_rs1_data),
        .rs2      (id_rs2_addr),
        .rs2_data (id_rs2_data),
        .rd       (wb_rd),
        .rd_data  (wb_result),
        .reg_write(wb_reg_write)
    );

    control_unit u_ctrl (
        .opcode    (id_opcode),
        .reg_write (id_reg_write),
        .mem_read  (id_mem_read),
        .mem_write (id_mem_write),
        .mem_to_reg(id_mem_to_reg),
        .alu_src   (id_alu_src),
        .branch    (id_branch),
        .jump      (id_jump),
        .jalr      (id_jalr),
        .alu_op    (id_alu_op)
    );

    immediate_gen u_immgen (
        .instr(id_instr),
        .imm  (id_imm)
    );

    branch_predictor u_bp (
        .clk            (clk),
        .rst_n          (rst_n),
        .pc             (pc),
        .predict_taken  (bp_predict_taken),
        .ex_pc          (ex_pc),
        .ex_is_branch   (ex_branch),
        .ex_actual_taken(ex_branch_taken)
    );

    // =========================================================================
    // 4. ID/EX Pipeline Register
    // =========================================================================

    id_ex_reg u_id_ex (
        .clk          (clk),
        .rst_n        (rst_n),
        .flush        (id_ex_flush | id_ex_bubble),
        .id_pc        (id_pc),
        .id_pc_plus4  (id_pc_plus4),
        .id_rs1_data  (id_rs1_data),
        .id_rs2_data  (id_rs2_data),
        .id_imm       (id_imm),
        .id_rs1       (id_rs1_addr),
        .id_rs2       (id_rs2_addr),
        .id_rd        (id_rd_addr),
        .id_funct3    (id_funct3),
        .id_funct7    (id_funct7),
        .id_opcode    (id_opcode),
        .id_reg_write (id_reg_write),
        .id_mem_read  (id_mem_read),
        .id_mem_write (id_mem_write),
        .id_mem_to_reg(id_mem_to_reg),
        .id_alu_src   (id_alu_src),
        .id_branch    (id_branch),
        .id_jump      (id_jump),
        .id_jalr      (id_jalr),
        .id_alu_op    (id_alu_op),
        .ex_pc        (ex_pc),
        .ex_pc_plus4  (ex_pc_plus4),
        .ex_rs1_data  (ex_rs1_data),
        .ex_rs2_data  (ex_rs2_data),
        .ex_imm       (ex_imm),
        .ex_rs1       (ex_rs1),
        .ex_rs2       (ex_rs2),
        .ex_rd        (ex_rd),
        .ex_funct3    (ex_funct3),
        .ex_funct7    (ex_funct7),
        .ex_opcode    (ex_opcode),
        .ex_reg_write (ex_reg_write),
        .ex_mem_read  (ex_mem_read),
        .ex_mem_write (ex_mem_write),
        .ex_mem_to_reg(ex_mem_to_reg),
        .ex_alu_src   (ex_alu_src),
        .ex_branch    (ex_branch),
        .ex_jump      (ex_jump),
        .ex_jalr      (ex_jalr),
        .ex_alu_op    (ex_alu_op)
    );

    // =========================================================================
    // 5. EX Stage – Execute
    // =========================================================================

    forwarding_unit u_fwd (
        .id_ex_rs1       (ex_rs1),
        .id_ex_rs2       (ex_rs2),
        .ex_mem_rd       (mem_rd),
        .ex_mem_reg_write(mem_reg_write),
        .mem_wb_rd       (wb_rd),
        .mem_wb_reg_write(wb_reg_write),
        .forward_a       (forward_a),
        .forward_b       (forward_b)
    );

    // Forward mux A
    assign ex_fwd_a = (forward_a == 2'b10) ? mem_alu_result :
                      (forward_a == 2'b01) ? wb_result       :
                                             ex_rs1_data;

    // Forward mux B (before ALU-src mux)
    assign ex_fwd_b = (forward_b == 2'b10) ? mem_alu_result :
                      (forward_b == 2'b01) ? wb_result       :
                                             ex_rs2_data;

    // ALU source mux: use PC for AUIPC, otherwise rs1
    // For AUIPC the opcode is 7'b0010111
    wire ex_is_auipc = (ex_opcode == 7'b0010111);
    assign ex_alu_a = ex_is_auipc ? ex_pc : ex_fwd_a;

    // ALU operand B: immediate or register
    assign ex_alu_b_pre = ex_alu_src ? ex_imm : ex_fwd_b;
    assign ex_alu_b = ex_alu_b_pre;

    // ALU decoder
    // For LUI: alu_op=11, we pass funct7_5=1 to select PASS_B
    // For AUIPC: alu_op=11, funct7_5=0 to select ADD (PC+imm)
    wire ex_is_lui = (ex_opcode == 7'b0110111);

    alu_decoder u_alu_dec (
        .alu_op   (ex_alu_op),
        .funct3   (ex_funct3),
        .funct7_5 (ex_is_lui ? 1'b1 : ex_funct7[5]),
        .opcode   (ex_opcode),
        .alu_ctrl (ex_alu_ctrl)
    );

    alu u_alu (
        .a        (ex_alu_a),
        .b        (ex_alu_b),
        .alu_ctrl (ex_alu_ctrl),
        .result   (ex_alu_result),
        .zero     (ex_alu_zero),
        .negative (),
        .overflow (),
        .carry_out()
    );

    // Branch target: PC + imm
    assign ex_branch_target = ex_pc + ex_imm;

    // JALR target: (rs1 + imm) & ~1
    assign ex_jalr_target = (ex_fwd_a + ex_imm) & ~32'h1;

    // Branch condition evaluation
    reg ex_branch_cond;
    always @(*) begin
        case (ex_funct3)
            3'b000: ex_branch_cond = (ex_fwd_a == ex_fwd_b);                   // BEQ
            3'b001: ex_branch_cond = (ex_fwd_a != ex_fwd_b);                   // BNE
            3'b100: ex_branch_cond = ($signed(ex_fwd_a) < $signed(ex_fwd_b));  // BLT
            3'b101: ex_branch_cond = ($signed(ex_fwd_a) >= $signed(ex_fwd_b)); // BGE
            3'b110: ex_branch_cond = (ex_fwd_a < ex_fwd_b);                    // BLTU
            3'b111: ex_branch_cond = (ex_fwd_a >= ex_fwd_b);                   // BGEU
            default: ex_branch_cond = 1'b0;
        endcase
    end

    assign ex_branch_taken = ex_branch && ex_branch_cond;
    assign ex_take_jump    = ex_jump || ex_jalr;

    // =========================================================================
    // 6. EX/MEM Pipeline Register
    // =========================================================================

    ex_mem_reg u_ex_mem (
        .clk             (clk),
        .rst_n           (rst_n),
        .ex_pc_plus4     (ex_pc_plus4),
        .ex_branch_target(ex_jalr ? ex_jalr_target : ex_branch_target),
        .ex_alu_result   (ex_alu_result),
        .ex_rs2_data     (ex_fwd_b),
        .ex_rd           (ex_rd),
        .ex_funct3       (ex_funct3),
        .ex_zero         (ex_alu_zero),
        .ex_branch_taken (ex_branch_taken | ex_take_jump),
        .ex_reg_write    (ex_reg_write),
        .ex_mem_read     (ex_mem_read),
        .ex_mem_write    (ex_mem_write),
        .ex_mem_to_reg   (ex_mem_to_reg),
        .ex_branch       (ex_branch),
        .ex_jump         (ex_take_jump),
        .mem_pc_plus4    (mem_pc_plus4),
        .mem_branch_target(mem_branch_target),
        .mem_alu_result  (mem_alu_result),
        .mem_rs2_data    (mem_rs2_data),
        .mem_rd          (mem_rd),
        .mem_funct3      (mem_funct3),
        .mem_zero        (mem_zero),
        .mem_branch_taken(mem_branch_taken),
        .mem_reg_write   (mem_reg_write),
        .mem_mem_read    (mem_mem_read),
        .mem_mem_write   (mem_mem_write),
        .mem_mem_to_reg  (mem_mem_to_reg),
        .mem_branch      (mem_branch),
        .mem_jump        (mem_jump)
    );

    // =========================================================================
    // 7. MEM Stage – Memory Access
    // =========================================================================

    // Address decode
    wire mem_is_gpio  = (mem_alu_result[31:28] == 4'h1); // 0x1000_0000
    wire mem_is_uart  = (mem_alu_result[31:28] == 4'h2); // 0x2000_0000
    wire mem_is_dmem  = !mem_is_gpio && !mem_is_uart;

    assign dmem_we   = mem_mem_write && mem_is_dmem;
    assign dmem_addr = mem_alu_result;

    data_mem u_dmem (
        .clk      (clk),
        .addr     (dmem_addr),
        .wdata    (mem_rs2_data),
        .funct3   (mem_funct3),
        .mem_read (mem_mem_read  && mem_is_dmem),
        .mem_write(dmem_we),
        .rdata    (mem_read_data)
    );

    // GPIO peripheral
    wire [31:0] gpio_rdata;
    gpio u_gpio (
        .clk    (clk),
        .rst_n  (rst_n),
        .addr   (mem_alu_result[3:0]),
        .wdata  (mem_rs2_data),
        .we     (mem_mem_write && mem_is_gpio),
        .rdata  (gpio_rdata),
        .gpio_out(gpio_out),
        .gpio_in (gpio_in)
    );

    // UART TX peripheral
    wire uart_ready;
    wire uart_we = mem_mem_write && mem_is_uart;
    uart_tx #(.CLKS_PER_BIT(UART_BPS)) u_uart (
        .clk     (clk),
        .rst_n   (rst_n),
        .tx_valid(uart_we),
        .tx_data (mem_rs2_data[7:0]),
        .tx_ready(uart_ready),
        .tx      (uart_tx_pin),
        .tx_done ()
    );

    // Read data mux
    wire [31:0] periph_rdata = mem_is_gpio ? gpio_rdata : 32'b0;
    wire [31:0] final_rdata  = mem_is_dmem ? mem_read_data : periph_rdata;

    // =========================================================================
    // 8. MEM/WB Pipeline Register
    // =========================================================================

    mem_wb_reg u_mem_wb (
        .clk          (clk),
        .rst_n        (rst_n),
        .mem_pc_plus4 (mem_pc_plus4),
        .mem_alu_result(mem_alu_result),
        .mem_read_data(final_rdata),
        .mem_rd       (mem_rd),
        .mem_reg_write(mem_reg_write),
        .mem_mem_to_reg(mem_mem_to_reg),
        .wb_pc_plus4  (wb_pc_plus4),
        .wb_alu_result(wb_alu_result),
        .wb_read_data (wb_read_data),
        .wb_rd        (wb_rd),
        .wb_reg_write (wb_reg_write),
        .wb_mem_to_reg(wb_mem_to_reg)
    );

    // =========================================================================
    // 9. WB Stage – Write Back
    // =========================================================================

    // mem_to_reg mux:
    //   2'b00 = ALU result
    //   2'b01 = Memory data
    //   2'b10 = PC+4 (JAL/JALR return address)
    //   2'b11 = Immediate (LUI) — stored in alu_result (PASS_B)
    assign wb_result = (wb_mem_to_reg == 2'b01) ? wb_read_data  :
                       (wb_mem_to_reg == 2'b10) ? wb_pc_plus4   :
                                                   wb_alu_result ;

    // =========================================================================
    // 10. Hazard Detection
    // =========================================================================

    hazard_detection u_hazard (
        .id_ex_mem_read(ex_mem_read),
        .id_ex_rd      (ex_rd),
        .if_id_rs1     (id_rs1_addr),
        .if_id_rs2     (id_rs2_addr),
        .branch_taken  (mem_branch_taken),
        .jump          (mem_jump),
        .pc_stall      (pc_stall),
        .if_id_stall   (if_id_stall),
        .id_ex_bubble  (id_ex_bubble),
        .if_id_flush   (if_id_flush),
        .id_ex_flush   (id_ex_flush)
    );

    // =========================================================================
    // 11. Debug outputs
    // =========================================================================

    assign dbg_pc = pc;

    // Read x10 (a0) from register file for debug
    // Re-read through a simple wire (register file has async read)
    // We reuse a second read port: for simplicity, connect rs1=10 always
    // This is only for simulation debug visibility.
    wire [31:0] dbg_rs1_data;
    register_file u_dbg_regfile (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1      (5'd10),
        .rs1_data (dbg_rs1_data),
        .rs2      (5'd0),
        .rs2_data (),
        .rd       (wb_rd),
        .rd_data  (wb_result),
        .reg_write(wb_reg_write)
    );
    assign dbg_reg_x10 = dbg_rs1_data;

endmodule
