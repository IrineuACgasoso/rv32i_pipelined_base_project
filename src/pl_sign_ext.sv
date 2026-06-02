// =============================================================================
// pl_sign_ext.sv (Extensão de Sinal de Imediatos - RV32I)
// Extrai e estende o sinal de campos imediatos contidos nas instruções.
//
// Formatos de Imediato RISC-V Suportados:
//   - I-type (Loads, JALR, Alométrica Imediata): imm[11:0]
//   - S-type (Stores): imm[11:5] e imm[4:0] recombinados
//   - B-type (Condicionais): imm[12:1] com imm[0]=0 (alinhamento de 2 bytes)
//   - J-type (Desvios Incondicionais): imm[20:1] com imm[0]=0 
// =============================================================================

`timescale 1ns / 1ps

module pl_sign_ext (
    input  logic [31:0] Instr,   // Instrução bruta de 32 bits vinda de IF/ID
    output logic [31:0] ImmExt   // Imediato de 32 bits com sinal estendido
);

    // =========================================================================
    // Parâmetros Locais (Opcodes de 7 bits - Instr[6:0])
    // =========================================================================
    localparam LOAD   = 7'b0000011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam OP_IMM = 7'b0010011;
    localparam JAL    = 7'b1101111;
    localparam JALR   = 7'b1100111;

    // =========================================================================
    // Lógica Combinatorial de Geração do Imediato
    // =========================================================================
    always_comb begin
        case (Instr[6:0])
            
            // --- FORMATO I-TYPE (LOAD, JALR, Operações com Imediato) ---
            // Campo imediato linear de 12 bits localizado em Instr[31:20]
            LOAD, JALR, OP_IMM: begin
                ImmExt = {{20{Instr[31]}}, Instr[31:20]};
            end

            // --- FORMATO S-TYPE (STORE: SB, SH, SW) ---
            // Recombina os dois pedaços divididos do imediato: [31:25] e [11:7]
            STORE: begin
                ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};
            end

            // --- FORMATO B-TYPE (BRANCH: BEQ, BNE, BLT, BGE, etc.) ---
            // Deslocado em 1 bit para a esquerda (imm[0] = 0). Alcance de até 4 KB.
            // Mapeamento: imm[12]=bit31, imm[11]=bit7, imm[10:5]=bit[30:25], imm[4:1]=bit[11:8]
            BRANCH: begin
                ImmExt = {{19{Instr[31]}}, Instr[31], Instr[7],
                           Instr[30:25], Instr[11:8], 1'b0};
            end

            // --- FORMATO J-TYPE (JAL) ---
            // Deslocado em 1 bit para a esquerda (imm[0] = 0). Alcance de até 1 MB.
            // Mapeamento: imm[20]=bit31, imm[19:12]=bit[19:12], imm[11]=bit20, imm[10:1]=bit[30:21]
            JAL: begin
                ImmExt = {{11{Instr[31]}}, Instr[31], Instr[19:12],
                           Instr[20], Instr[30:21], 1'b0};
            end

            // --- PADRÃO / SEGURANÇA ---
            // Instruções do tipo R (ADD, SUB, etc.) não utilizam imediatos
            default: begin
                ImmExt = 32'b0;
            end
            
        endcase
    end

endmodule