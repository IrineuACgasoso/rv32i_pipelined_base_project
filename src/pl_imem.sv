// =============================================================================
// pl_dmem.sv (Memória de Dados - RV32I)
// Memória física de 1 KB (256 palavras x 32 bits) mapeada por byte.
//
// Operações (Controladas pelo sinal funct3 e MemWrite/MemRead):
//   000 (LB/SB)   : Acesso a 1 Byte
//   001 (LH/SH)   : Acesso a Halfword (2 Bytes)
//   010 (LW/SW)   : Acesso a Word Inteira (4 Bytes)
//   100 (LBU)     : Acesso a Byte Unsigned (Extensão tratada no WB)
//   101 (LHU)     : Acesso a Halfword Unsigned (Extensão tratada no WB)
//
// Detalhe de Escrita:
// No RISC-V, o dado de um 'Store' (SB/SH) sempre vem dos LSBs de rs2.
// A memória é responsável por colocar esse dado na posição correta (offset).
// =============================================================================

`timescale 1ns / 1ps

module pl_dmem (
    input  logic        clk,
    input  logic        MemWrite,
    input  logic [2:0]  funct3,      // Indica a largura da operação (SB, SH, SW)
    input  logic [9:0]  addr,        // Endereço de Byte vindo da ALU
    input  logic [31:0] WriteData,   // Dado a ser escrito (vindo de rs2)
    output logic [31:0] ReadData     // Palavra completa lida da memória
);

    // =========================================================================
    // Armazenamento Físico e Inicialização
    // =========================================================================
    (* ram_init_file = "data.mif" *) logic [31:0] ram [0:255];

    // synthesis translate_off
    initial begin
        for (int i = 0; i < 256; i++) ram[i] = 32'h00000000;
        $readmemh("data.hex", ram);
    end
    // synthesis translate_on

    // =========================================================================
    // Decodificação de Endereço
    // =========================================================================
    // word_addr: Índice da palavra de 32 bits na matriz da RAM (0 a 255)
    // byte_off:  Deslocamento do byte exato dentro dessa palavra
    wire [7:0] word_addr = addr[9:2];
    wire [1:0] byte_off  = addr[1:0];

    // =========================================================================
    // Escrita Síncrona com Endereçamento e Mascaramento Parcial
    // =========================================================================
    always @(posedge clk) begin
        if (MemWrite) begin
            case (funct3)
                // --- STORE BYTE (SB) ---
                3'b000: begin 
                    case (byte_off)
                        2'd0: ram[word_addr][7:0]   <= WriteData[7:0];
                        2'd1: ram[word_addr][15:8]  <= WriteData[7:0];
                        2'd2: ram[word_addr][23:16] <= WriteData[7:0];
                        2'd3: ram[word_addr][31:24] <= WriteData[7:0];
                    endcase
                end
                
                // --- STORE HALFWORD (SH) ---
                3'b001: begin 
                    // Assume alinhamento em 16 bits (halfword-aligned)
                    if (byte_off[1] == 1'b0)
                        ram[word_addr][15:0]  <= WriteData[15:0];
                    else
                        ram[word_addr][31:16] <= WriteData[15:0];
                end
                
                // --- STORE WORD (SW) ---
                default: begin // funct3 = 3'b010
                    ram[word_addr] <= WriteData;
                end
            endcase
        end
    end

    // =========================================================================
    // Leitura Assíncrona Combinatorial
    // =========================================================================
    // Sempre entrega os 32 bits completos referentes ao word_addr.
    // O Datapath (no estágio WB) cuida de extrair o byte/halfword correto.
    assign ReadData = ram[word_addr];

endmodule