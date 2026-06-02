// =============================================================================
// pl_alu_ctrl.sv 
// Unidade de Controle da ALU -- RV32I pipelined
// =============================================================================

`timescale 1ns / 1ps

module pl_alu_ctrl (
    // ENTRADAS: Sinais que vêm do estágio de decodificação/execução do pipeline
    input  logic [1:0] ALUOp,     // Sinal de controle principal (2 bits) que define a categoria da instrução
    input  logic [6:0] Funct7,    // Campo de 7 bits da instrução (usado para diferenciar ADD/SUB e SRL/SRA)
    input  logic [2:0] Funct3,    // Campo de 3 bits da instrução (define a operação exata dentro da categoria)
    
    // SAÍDA: O código de 4 bits que vai direto pros seletores da ALU
    output logic [3:0] Operation 
);

    // Bloco combinacional puro: não depende de clock, mudou a entrada, a saída muda na hora
    always_comb begin
        case (ALUOp)
            
            // -----------------------------------------------------------------
            // CASO 00: Instruções de Memória (LW, SW) ou JALR
            // Todas elas precisam calcular um endereço somando um offset. 
            // -----------------------------------------------------------------
            2'b00: Operation = 4'd01;   // Força a ALU a fazer um ADD (4'd01)

            // -----------------------------------------------------------------
            // CASO 01: Instruções de Desvio Condicional (Branches - BEQ, BNE, etc)
            // A ALU faz contas de comparação para o processador decidir se pula ou não.
            // -----------------------------------------------------------------
            2'b01: begin 
                case (Funct3)
                    3'b000, 3'b001: Operation = 4'd02;   // BEQ / BNE -> Faz Subtração (se der 0, são iguais)
                    3'b100, 3'b101: Operation = 4'd11;   // BLT / BGE -> Compara Menor Que (Sinalizado)
                    3'b110, 3'b111: Operation = 4'd12;   // BLTU / BGEU -> Compara Menor Que (Sem Sinal)
                    default:        Operation = 4'd02;
                endcase
            end

            // -----------------------------------------------------------------
            // CASO 10: Instruções Tipo-R (Registrador-Registrador, ex: ADD, SUB, AND, OR)
            // Aqui o bicho pega: precisamos olhar o Funct3 e às vezes o Funct7.
            // -----------------------------------------------------------------
            2'b10: begin 
                case (Funct3)
                    // Funct3 é 0: Pode ser ADD ou SUB. O bit 5 do Funct7 desempata (1 = SUB, 0 = ADD)
                    3'h0: Operation = (Funct7 == 7'b0100000) ? 4'd02 : 4'd01; 
                    3'h1: Operation = 4'd06; // SLL (Shift Left Logical)
                    3'h2: Operation = 4'd11; // SLT (Set Less Than)
                    3'h3: Operation = 4'd12; // SLTU (Set Less Than Unsigned)
                    3'h4: Operation = 4'd03; // XOR
                    // Funct3 é 5: Pode ser Shift Direita Aritmético (SRA) ou Lógico (SRL)
                    3'h5: Operation = (Funct7 == 7'b0100000) ? 4'd08 : 4'd07; 
                    3'h6: Operation = 4'd04; // OR
                    3'h7: Operation = 4'd05; // AND
                    default: Operation = 4'd01;
                endcase
            end

            // -----------------------------------------------------------------
            // CASO 11: Instruções Tipo-I Matemáticas (Operações com Imediatos, ex: ADDI, ANDI)
            // Quase idêntico ao Tipo-R, mas opera com o número estático que veio no código.
            // -----------------------------------------------------------------
            2'b11: begin 
                case (Funct3)
                    3'b000: Operation = 4'd01; // ADDI -> Soma imediato
                    3'b001: Operation = 4'd06; // SLLI -> Shift Left imediato
                    3'b010: Operation = 4'd11; // SLTI
                    3'b011: Operation = 4'd12; // SLTIU
                    3'b100: Operation = 4'd03; // XORI
                    // Mesma regra de desempate do shift para a direita usando Funct7
                    3'b101: Operation = (Funct7 == 7'b0100000) ? 4'd08 : 4'd07; 
                    3'b110: Operation = 4'd04; // ORI
                    3'b111: Operation = 4'd05; // ANDI
                    default: Operation = 4'd01;
                endcase
            end

            // Segurança: Se vier um padrão de bits desconhecido, o padrão é fazer um ADD
            default: Operation = 4'd01;
        endcase
    end

endmodule