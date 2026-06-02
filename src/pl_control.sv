// =============================================================================
// pl_control.sv  (ESTENDIDO)
// Unidade de Controle Principal -- RV32I pipelined
//
// Instrucoes adicionadas:
//   B-type  (1100011): BEQ, BNE, BLT, BGE, BLTU, BGEU
//   J-type  (1101111): JAL
//   I-type  (1100111): JALR
//   I-type  (0000011): LB, LH, LW, LBU, LHU  (funct3 diferencia)
//   S-type  (0100011): SB, SH, SW             (funct3 diferencia)
//   HALT    (0001011): encoding customizado
//
// ALUOp:
//   2'b00 = Load/Store -> ADD
//   2'b01 = Branch     -> SUB (BEQ/BNE) ou sinais proprios (BLT etc)
//   2'b10 = R-type
//   2'b11 = OP_IMM
//
// branch_type (3 bits, para pl_datapath escolher pc_src):
//   3'b001 = BEQ   3'b010 = BNE   3'b011 = BLT
//   3'b100 = BGE   3'b101 = BLTU  3'b110 = BGEU
//
// jal_jalr (2 bits):
//   2'b00 = nao e salto incondicional
//   2'b01 = JAL
//   2'b10 = JALR
// =============================================================================

`timescale 1ns / 1ps

module pl_control (
    input  logic [6:0] Opcode,
    output logic       ALUSrc,
    output logic       MemtoReg,
    output logic       RegWrite,
    output logic       MemRead,
    output logic       MemWrite,
    output logic [2:0] BranchType,   // substituiu Branch (1 bit)
    output logic [1:0] JalJalr,
    output logic [1:0] ALUOp
);

    localparam R_TYPE = 7'b0110011;
    localparam LOAD   = 7'b0000011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam OP_IMM = 7'b0010011;
    localparam JAL    = 7'b1101111;
    localparam JALR   = 7'b1100111;
    localparam HALT   = 7'b0001011;   // encoding customizado

    always_comb begin
        ALUSrc     = 1'b0;
        MemtoReg   = 1'b0;
        RegWrite   = 1'b0;
        MemRead    = 1'b0;
        MemWrite   = 1'b0;
        BranchType = 3'b000;
        JalJalr    = 2'b00;
        ALUOp      = 2'b00;

        case (Opcode)
            R_TYPE: begin
                RegWrite = 1'b1;
                ALUOp    = 2'b10;
            end
            LOAD: begin
                ALUSrc   = 1'b1;
                MemtoReg = 1'b1;
                RegWrite = 1'b1;
                MemRead  = 1'b1;
                ALUOp    = 2'b00;
            end
            STORE: begin
                ALUSrc   = 1'b1;
                MemWrite = 1'b1;
                ALUOp    = 2'b00;
            end
            BRANCH: begin
                // BranchType sera decodificado no datapath via funct3
                // usamos 3'b111 como placeholder "decodificar no EX"
                BranchType = 3'b111;
                ALUOp      = 2'b01;
            end
            OP_IMM: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                ALUOp    = 2'b11;
            end
            JAL: begin
                // target = PC + imm_J; rd = PC+4
                RegWrite = 1'b1;
                JalJalr  = 2'b01;
            end
            JALR: begin
                // target = (rs1 + imm_I) & ~1; rd = PC+4
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                JalJalr  = 2'b10;
                ALUOp    = 2'b00;   // ADD (rs1 + imm_I)
            end
            HALT: begin
                // NOP permanente: sem efeitos
            end
            default: ; // seguro
        endcase
    end

endmodule