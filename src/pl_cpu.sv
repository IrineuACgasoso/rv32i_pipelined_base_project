// =============================================================================
// pl_cpu.sv (Wrapper Top-Level da CPU)
// Integra e interconecta os 3 grandes blocos: Controle, Controle da ALU e Datapath.
// Atualizado para suportar múltiplos tipos de Branch (3 bits) e saltos JAL/JALR.
// =============================================================================

`timescale 1ns / 1ps

module pl_cpu (
    // Sinais Básicos do Sistema
    input  logic        clk,
    input  logic        rst_n,
    output logic [31:0] PC,

    // Interface de I/O com o mundo externo (Placa FPGA)
    input  logic [17:0] SW,           // Chaves estáticas
    input  logic [3:0]  KEY_IO,       // Botões pulsadores
    output logic [17:0] LEDR,         // LEDs Vermelhos
    output logic [8:0]  LEDG,         // LEDs Verdes
    output logic        UART_TXD,     // Transmissão Serial
    input  logic        UART_RXD,     // Recepção Serial

    // Sinais de Monitoramento (Sondas que o Testbench usa para verificar se a CPU funciona)
    output logic        wb_reg_write,
    output logic [4:0]  wb_reg_dst,
    output logic [31:0] wb_reg_data,
    output logic        mem_wr_en,
    output logic [7:0]  mem_wr_addr,
    output logic [31:0] mem_wr_data
);

    // Fios internos para interconectar os módulos
    logic [6:0] opcode;

    // Sinais de controle gerados pela Unidade de Controle principal
    logic       ALUSrc, MemtoReg, RegWrite, MemRead, MemWrite;
    logic [2:0] BranchType;
    logic [1:0] JalJalr;
    logic [1:0] ALUOp;

    // Sinais decodificados que já viajaram pelos registradores de pipeline até o estágio de Execução (EX)
    logic [2:0] funct3_ex;
    logic [6:0] funct7_ex;
    logic [1:0] aluop_ex;
    logic [3:0] alu_cc; // Fio que leva a decisão final de 4 bits da operação para a ALU

    // 1. INSTÂNCIA DA UNIDADE DE CONTROLE PRINCIPAL
    // Lê o opcode da instrução atual e decide as diretrizes gerais do circuito
    pl_control ctrl (
        .Opcode     (opcode),
        .ALUSrc     (ALUSrc),
        .MemtoReg   (MemtoReg),
        .RegWrite   (RegWrite),
        .MemRead    (MemRead),
        .MemWrite   (MemWrite),
        .BranchType (BranchType),
        .JalJalr    (JalJalr),
        .ALUOp      (ALUOp)
    );

    // 2. INSTÂNCIA DO CONTROLE DA ALU
    // Fica fisicamente perto do estágio EX. Recebe os functs pipelinados e escolhe a operação da ALU
    pl_alu_ctrl alu_ctrl (
        .ALUOp     (aluop_ex),
        .Funct7    (funct7_ex),
        .Funct3    (funct3_ex),
        .Operation (alu_cc)
    );

    // 3. INSTÂNCIA DO DATAPATH (O "MÚSCULO" DA CPU)
    // Contém os estágios físicos (IF, ID, EX, MEM, WB), registradores, ALU e memórias
    pl_datapath datapath (
        .clk          (clk),
        .rst_n        (rst_n),
        .ALUSrc       (ALUSrc),
        .MemtoReg     (MemtoReg),
        .RegWrite     (RegWrite),
        .MemRead      (MemRead),
        .MemWrite     (MemWrite),
        .BranchType   (BranchType),
        .JalJalr      (JalJalr),
        .ALUOp        (ALUOp),
        .ALU_CC       (alu_cc),
        
        // Conexões de feedback: extrai informações de dentro do datapath para alimentar o controle externo
        .Opcode       (opcode),
        .Funct3_EX    (funct3_ex),
        .Funct7_EX    (funct7_ex),
        .ALUOp_EX     (aluop_ex),
        
        // Repassa os pinos externos de I/O e diagnóstico para as subcamadas internas
        .PC           (PC),
        .SW           (SW),
        .KEY          (KEY_IO),
        .LEDR         (LEDR),
        .LEDG         (LEDG),
        .UART_TXD     (UART_TXD),
        .UART_RXD     (UART_RXD),
        .wb_reg_write (wb_reg_write),
        .wb_reg_dst   (wb_reg_dst),
        .wb_reg_data  (wb_reg_data),
        .mem_wr_en    (mem_wr_en),
        .mem_wr_addr  (mem_wr_addr),
        .mem_wr_data  (mem_wr_data)
    );

endmodule