// =============================================================================
// pl_forward.sv (Unidade de Forwarding / Adiantamento)
// Resolve hazards de dados RAW (Read After Write) no estágio EX.
//
// Seleção das saídas (forward_a / forward_b):
//   2'b10 -> Adiantar do EX/MEM (Resultado da ALU disponível imediatamente)
//   2'b01 -> Adiantar do MEM/WB (Dado vindo da Memória ou resultado anterior da ALU)
//   2'b00 -> Sem adiantamento (Usa o dado original vindo do Banco de Registradores)
// =============================================================================

`timescale 1ns / 1ps

module pl_forward (
    input  logic [4:0] id_ex_rs1,        // Registrador fonte 1 no estágio EX
    input  logic [4:0] id_ex_rs2,        // Registrador fonte 2 no estágio EX
    input  logic [4:0] ex_mem_rd,        // Registrador destino no estágio MEM
    input  logic [4:0] mem_wb_rd,        // Registrador destino no estágio WB
    input  logic       ex_mem_reg_write, // Instrução no estágio MEM vai escrever no banco?
    input  logic       mem_wb_reg_write, // Instrução no estágio WB vai escrever no banco?
    output logic [1:0] forward_a,        // Controle do Mux do operando A da ALU
    output logic [1:0] forward_b         // Controle do Mux do operando B da ALU
);

    // =========================================================================
    // Lógica de Adiantamento para o Operando A (rs1)
    // =========================================================================
    always_comb begin
        // Condição 1: Hazard detectado a partir do estágio EX/MEM (Maior Prioridade)
        if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1)) begin
            forward_a = 2'b10;
        end
        // Condição 2: Hazard detectado a partir do estágio MEM/WB
        // Correção: Só adianta de MEM/WB se o estágio EX/MEM também não estiver tentando atualizar o MESMO rs1.
        else if (mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs1) &&
                 !(ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1))) begin
            forward_a = 2'b01;
        end
        // Padrão: Sem hazard, usa o dado lido do Register File
        else begin
            forward_a = 2'b00;
        end
    end

    // =========================================================================
    // Lógica de Adiantamento para o Operando B (rs2)
    // =========================================================================
    always_comb begin
        // Condição 1: Hazard detectado a partir do estágio EX/MEM (Maior Prioridade)
        if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2)) begin
            forward_b = 2'b10;
        end
        // Condição 2: Hazard detectado a partir do estágio MEM/WB
        // Correção: Só adianta de MEM/WB se o estágio EX/MEM também não estiver tentando atualizar o MESMO rs2.
        else if (mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs2) &&
                 !(ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2))) begin
            forward_b = 2'b01;
        end
        // Padrão: Sem hazard, usa o dado lido do Register File
        else begin
            forward_b = 2'b00;
        end
    end

endmodule