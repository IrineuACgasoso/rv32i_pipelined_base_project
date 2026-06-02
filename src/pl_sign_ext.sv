// =============================================================================
// pl_sign_ext.sv  (ESTENDIDO)
// Extensao de Sinal de Imediatos -- RV32I pipelined
//
// Formatos suportados:
//   I-type (lw/lb/lh/lbu/addi etc.) : imm[11:0]  = inst[31:20]
//   S-type (sw/sb/sh)               : imm[11:5]  = inst[31:25], imm[4:0] = inst[11:7]
//   B-type (beq/bne/blt/bge/bltu)   : B-imm
//   J-type (jal)                    : J-imm (20 bits deslocado)
//   I-type JALR (1100111)           : mesmo que I-type normal
// =============================================================================

`timescale 1ns / 1ps

module pl_sign_ext (
    input  logic [31:0] Instr,
    output logic [31:0] ImmExt
);

    localparam LOAD   = 7'b0000011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam OP_IMM = 7'b0010011;
    localparam JAL    = 7'b1101111;
    localparam JALR   = 7'b1100111;

    always_comb begin
        case (Instr[6:0])
            LOAD, JALR, OP_IMM:
                ImmExt = {{20{Instr[31]}}, Instr[31:20]};

            STORE:
                ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};

            BRANCH:
                ImmExt = {{19{Instr[31]}}, Instr[31], Instr[7],
                           Instr[30:25], Instr[11:8], 1'b0};

            JAL:
                // J-imm: inst[31] inst[19:12] inst[20] inst[30:21] 0
                ImmExt = {{11{Instr[31]}}, Instr[31], Instr[19:12],
                           Instr[20], Instr[30:21], 1'b0};

            default:
                ImmExt = 32'b0;
        endcase
    end

endmodule