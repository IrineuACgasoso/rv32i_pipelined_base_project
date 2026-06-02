// =============================================================================
// pl_alu.sv  (ESTENDIDO)
// Unidade Logica e Aritmetica de 32 bits -- RV32I pipelined
// =============================================================================

`timescale 1ns / 1ps

module pl_alu (
    // ENTRADAS: Os dois dados de 32 bits vindos dos registradores (ou adiantamento)
    input  logic [31:0] SrcA,       // Operando A (geralmente rs1)
    input  logic [31:0] SrcB,       // Operando B (geralmente rs2 ou o valor imediato)
    input  logic [3:0]  Operation,  // Código de 4 bits vindo da Unidade de Controle da ALU
    
    // SAÍDAS: O resultado da conta e a flag de teste
    output logic [31:0] ALUResult,  // Resultado final de 32 bits
    output logic        Zero        // Flag que avisa se o resultado deu exatamente zero
);

    // Bloco combinacional: calcula o resultado instantaneamente com base na operação escolhida
    always_comb begin
        case (Operation)
            // 4'd01 e 4'd02: Soma e Subtração tratadas como números com sinal ($signed)
            4'd01: ALUResult = $signed(SrcA) + $signed(SrcB);
            4'd02: ALUResult = $signed(SrcA) - $signed(SrcB);
            
            // Operações lógicas bit a bit (Bitwise)
            4'd03: ALUResult = SrcA ^ SrcB;  // XOR
            4'd04: ALUResult = SrcA | SrcB;  // OR
            4'd05: ALUResult = SrcA & SrcB;  // AND
            
            // Deslocamentos (Shifts): Repare o uso de SrcB[4:0]. 
            // Como o registrador tem 32 bits, só precisamos de 5 bits (2^5 = 32) para definir a quantidade do shift.
            4'd06: ALUResult = SrcA << SrcB[4:0];  // SLL: Deslocamento Lógico para Esquerda (insere zeros)
            4'd07: ALUResult = SrcA >> SrcB[4:0];  // SRL: Deslocamento Lógico para Direita (insere zeros)
            4'd08: ALUResult = $signed(SrcA) >>> SrcB[4:0]; // SRA: Deslocamento Aritmético para Direita (mantém o bit de sinal)
            
            // Comparações "Set Less Than" (Insere 1 se A < B, senão insere 0)
            4'd11: ALUResult = ($signed(SrcA) < $signed(SrcB)) ? 32'd1 : 32'd0; // SLT: Comparação com sinal (considera negativos)
            4'd12: ALUResult = (SrcA < SrcB) ? 32'd1 : 32'd0;   // SLTU: Comparação sem sinal (trata tudo como positivo)
            
            // Segurança: Se a operação for inválida, zera o resultado
            default: ALUResult = 32'b0;
        endcase
    end

    // Atribuição contínua para a flag Zero.
    // Se o ALUResult for igual a 0, a variável Zero ganha o valor lógico 1 (True). 
    // É usada principalmente pelo comando BEQ para saber se dois números são iguais (A - B == 0).
    assign Zero = (ALUResult == 32'b0);

endmodule