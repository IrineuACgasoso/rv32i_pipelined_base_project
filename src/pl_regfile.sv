// =============================================================================
// pl_regfile.sv (Banco de Registradores - RV32I)
// Matriz de 32 registradores de 32 bits.
//
// Leitura  : Assíncrona (Combinatorial) - Ocorre no estágio ID.
// Escrita  : Síncrona no NEGEDGE (borda de descida) do clock - Ocorre no estágio WB.
// Reg x0   : Hardwired a zero (leituras retornam 0, escritas são ignoradas).
//
// Arquitetura de Clock (Baseada em Patterson & Hennessy - Fig. 4.63):
// A escrita em borda de descida resolve o hazard de dados quando uma instrução
// no estágio WB escreve no mesmo registrador que uma instrução no estágio ID 
// tenta ler no MESMO ciclo de clock. A escrita termina na primeira metade do 
// ciclo, garantindo que a leitura na segunda metade pegue o dado atualizado.
// =============================================================================

`timescale 1ns / 1ps

module pl_regfile (
    input  logic        clk,
    input  logic        RegWrite,    // Sinal de controle vindo do estágio WB
    input  logic [4:0]  rs1,         // Endereço do registrador fonte 1
    input  logic [4:0]  rs2,         // Endereço do registrador fonte 2
    input  logic [4:0]  rd,          // Endereço do registrador destino
    input  logic [31:0] WriteData,   // Dado a ser escrito (vindo de WB)
    output logic [31:0] ReadData1,   // Dado lido do registrador fonte 1
    output logic [31:0] ReadData2    // Dado lido do registrador fonte 2
);

    // =========================================================================
    // Matriz Física de Registradores
    // =========================================================================
    logic [31:0] rf [31:0];

    // =========================================================================
    // Escrita Síncrona (Borda de Descida)
    // =========================================================================
    always_ff @(negedge clk) begin
        // Protege o registrador x0 (rd = 0) contra qualquer tentativa de escrita
        if (RegWrite && (rd != 5'b0)) begin
            rf[rd] <= WriteData;
        end
    end

    // =========================================================================
    // Leitura Assíncrona (Combinatorial)
    // =========================================================================
    // Proteção hardwired: O registrador 0 (x0) sempre retorna 32 bits em zero,
    // independentemente do que possa estar armazenado na memória física.
    assign ReadData1 = (rs1 != 5'b0) ? rf[rs1] : 32'b0;
    assign ReadData2 = (rs2 != 5'b0) ? rf[rs2] : 32'b0;

endmodule