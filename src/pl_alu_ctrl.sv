// =============================================================================
// pl_alu_ctrl.sv  (ESTENDIDO)
// Unidade de Controle da ALU -- RV32I pipelined
//
// ALUOp:
//   2'b00 : Load/Store/JALR -> ADD
//   2'b01 : Branch          -> varia conforme Funct3:
//             BEQ/BNE  -> SUB (testa zero)
//             BLT/BGE  -> SLT  (testa bit 0)
//             BLTU/BGEU-> SLTU (testa bit 0)
//   2'b10 : R-type
//   2'b11 : OP_IMM
//
// Codigos Operation:
//   4'd01 ADD  4'd02 SUB  4'd03 XOR  4'd04 OR  4'd05 AND
//   4'd06 SLL  4'd07 SRL  4'd08 SRA  4'd11 SLT  4'd12 SLTU
// =============================================================================

`timescale 1ns / 1ps

module pl_alu_ctrl (
    input  logic [1:0] ALUOp,
    input  logic [6:0] Funct7,
    input  logic [2:0] Funct3,
    output logic [3:0] Operation
);

    always_comb begin
        case (ALUOp)
            2'b00: Operation = 4'd01;   // Load / Store / JALR -> ADD

            2'b01: begin                // Branch: escolher por Funct3
                case (Funct3)
                    3'b000, 3'b001: Operation = 4'd02;   // BEQ / BNE  -> SUB
                    3'b100, 3'b101: Operation = 4'd11;   // BLT / BGE  -> SLT
                    3'b110, 3'b111: Operation = 4'd12;   // BLTU / BGEU-> SLTU
                    default:        Operation = 4'd02;
                endcase
            end

            2'b10: begin                // R-type
                case (Funct3)
                    3'h0: Operation = (Funct7 == 7'b0100000) ? 4'd02 : 4'd01; // SUB/ADD
                    3'h1: Operation = 4'd06; // SLL
                    3'h2: Operation = 4'd11; // SLT
                    3'h3: Operation = 4'd12; // SLTU
                    3'h4: Operation = 4'd03; // XOR
                    3'h5: Operation = (Funct7 == 7'b0100000) ? 4'd08 : 4'd07; // SRA/SRL
                    3'h6: Operation = 4'd04; // OR
                    3'h7: Operation = 4'd05; // AND
                    default: Operation = 4'd01;
                endcase
            end

            2'b11: begin                // OP_IMM
                case (Funct3)
                    3'b000: Operation = 4'd01; // ADDI
                    3'b001: Operation = 4'd06; // SLLI
                    3'b010: Operation = 4'd11; // SLTI
                    3'b011: Operation = 4'd12; // SLTIU
                    3'b100: Operation = 4'd03; // XORI
                    3'b101: Operation = (Funct7 == 7'b0100000) ? 4'd08 : 4'd07; // SRAI/SRLI
                    3'b110: Operation = 4'd04; // ORI
                    3'b111: Operation = 4'd05; // ANDI
                    default: Operation = 4'd01;
                endcase
            end

            default: Operation = 4'd01;
        endcase
    end

endmodule