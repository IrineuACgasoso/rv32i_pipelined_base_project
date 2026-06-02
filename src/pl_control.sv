// =============================================================================
// pl_control.sv (Unidade de Controle Principal)
// Decodifica o Opcode para gerar os sinais que controlam todo o pipeline.
// ALUOp:   00=Load/Store/JALR (ADD) | 01=Branch (SUB) | 10=R-type | 11=OP_IMM
// JalJalr: 00=Sem salto | 01=JAL | 10=JALR
// =============================================================================

`timescale 1ns / 1ps

module pl_control (
    input  logic [6:0] Opcode,
    // SINAIS DE CONTROLE GERADOS:
    output logic       ALUSrc,     // 0 = Usa Registrador rs2 | 1 = Usa valor Imediato na ALU
    output logic       MemtoReg,   // 0 = Grava dado da ALU no RegFile | 1 = Grava dado da Memória
    output logic       RegWrite,   // 1 = Habilita escrita no Banco de Registradores
    output logic       MemRead,    // 1 = Habilita leitura da Memória de Dados (LW)
    output logic       MemWrite,   // 1 = Habilita escrita na Memória de Dados (SW)
    output logic [2:0] BranchType, // Tipo de desvio condicional (decodificado via funct3 no datapath)
    output logic [1:0] JalJalr,    // Controle de saltos incondicionais
    output logic [1:0] ALUOp       // Categoria da operação enviada para o pl_alu_ctrl
);

    // Opcodes padrão da arquitetura RISC-V (RV32I)
    localparam R_TYPE = 7'b0110011;
    localparam LOAD   = 7'b0000011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam OP_IMM = 7'b0010011;
    localparam JAL    = 7'b1101111;
    localparam JALR   = 7'b1100111;
    localparam HALT   = 7'b0001011; // Instrução customizada para parar a execução

    always_comb begin
        // Valores Padrão (Evita a criação de latches indesejados no hardware)
        ALUSrc     = 1'b0;
        MemtoReg   = 1'b0;
        RegWrite   = 1'b0;
        MemRead    = 1'b0;
        MemWrite   = 1'b0;
        BranchType = 3'b000;
        JalJalr    = 2'b00;
        ALUOp      = 2'b00;

        case (Opcode)
            // Tipo-R: Executa lógica/matemática entre registradores. Grava o resultado.
            R_TYPE: begin
                RegWrite = 1'b1;
                ALUOp    = 2'b10;
            end
            
            // Load (LW): Busca na memória. ALUSrc ativa o imediato, MemRead lê e MemtoReg joga pro registrador.
            LOAD: begin
                ALUSrc   = 1'b1;
                MemtoReg = 1'b1;
                RegWrite = 1'b1;
                MemRead  = 1'b1;
                ALUOp    = 2'b00;
            end
            
            // Store (SW): Escreve na memória. ALUSrc ativa o imediato do offset, MemWrite autoriza a escrita.
            STORE: begin
                ALUSrc   = 1'b1;
                MemWrite = 1'b1;
                ALUOp    = 2'b00;
            end
            
            // Branch (BEQ/BNE...): Compara dados. Seta placeholder para o datapath decidir o tipo exato.
            BRANCH: begin
                BranchType = 3'b111; 
                ALUOp      = 2'b01;
            end
            
            // Tipo-I Matemático (ADDI, ANDI...): Mesma lógica do Tipo-R, mas o segundo operando é o imediato (ALUSrc=1).
            OP_IMM: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                ALUOp    = 2'b11;
            end
            
            // JAL: Salto incondicional longo. Escreve o endereço de retorno PC+4 no registrador de destino.
            JAL: begin
                RegWrite = 1'b1;
                JalJalr  = 2'b01;
            end
            
            // JALR: Salto incondicional via registrador (rs1 + imediato). Usa a ALU para somar a base do salto.
            JALR: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                JalJalr  = 2'b10;
                ALUOp    = 2'b00; 
            end
            
            // HALT: Para o processador. Mantém todos os sinais zerados agindo como um NOP eterno.
            HALT: begin
                // Sem efeitos no hardware
            end
            
            default: ; // Cláusula de segurança
        endcase
    end

endmodule