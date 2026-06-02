// =============================================================================
// pl_hazard.sv (Unidade de Detecção de Hazard)
// Detecta conflitos do tipo Load-Use e gera o sinal de Stall (parada).
//
// Mecanismo de Ação do Stall no Datapath:
//   - stall = 1 -> Trava o PC (não muda de valor)
//   - stall = 1 -> Trava o registrador IF/ID (segura a instrução atual)
//   - stall = 1 -> Limpa o registrador ID/EX (injeta um NOP/Bolha na execução)
// =============================================================================

`timescale 1ns / 1ps

module pl_hazard (
    input  logic [4:0] if_id_rs1,       // Registrador rs1 da instrução no estágio ID
    input  logic [4:0] if_id_rs2,       // Registrador rs2 da instrução no estágio ID
    input  logic [4:0] id_ex_rd,        // Registrador destino (rd) da instrução no estágio EX
    input  logic       id_ex_mem_read,  // 1 se a instrução no estágio EX for um Load (LB, LH, LW, etc.)
    output logic       stall            // 1 = Ativa congelamento do fluxo e injeta bolha
);

    // Lógica Combinatorial Pura
    always_comb begin
        // Um stall Load-Use ocorre se a instrução anterior (em EX) vai ler da memória
        // E o destino dela (rd) coincide com qualquer uma das fontes (rs1 ou rs2) da instrução atual (em ID).
        if (id_ex_mem_read && ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2))) begin
            stall = 1'b1;
        end 
        else begin
            stall = 1'b0;
        end
    end

endmodule