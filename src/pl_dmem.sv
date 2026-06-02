// =============================================================================
// pl_dmem.sv (Memória de Dados com Escrita Parcial)
// Capacidade : 256 palavras x 32 bits = 1 KB (Mapeamento por Byte)
// Leitura    : Assíncrona (Combinatorial) - Requisito do estágio MEM
// Escrita    : Síncrona (Posedge clk) com máscara de Bytes (SB, SH, SW)
// =============================================================================

`timescale 1ns / 1ps

module pl_dmem (
    input  logic        clk,
    input  logic        MemWrite,
    input  logic [2:0]  funct3,    // Determina o tamanho do acesso (Byte, Half, Word)
    input  logic [9:0]  addr,      // Endereço completo de 10 bits (Byte Address)
    input  logic [31:0] WriteData,
    output logic [31:0] ReadData
);

    // Memória física organizada em 256 palavras de 32 bits
    (* ram_init_file = "data.mif" *) logic [31:0] ram [0:255];

    // Fios internos para decodificação do endereço e máscara
    logic [7:0] word_addr;
    logic [1:0] byte_offset;
    logic [3:0] byte_en;       // Máscara de escrita (1 para habilitar o byte correspondente)

    assign word_addr   = addr[9:2]; // Descarta os 2 LSBs para achar o índice da palavra (0-255)
    assign byte_offset = addr[1:0]; // Alinhamento do byte dentro da palavra de 32 bits

    // Inicialização para Simulação (ModelSim) / Síntese (Quartus)
    // synthesis translate_off
    initial begin
        for (int i = 0; i < 256; i++) ram[i] = 32'h00000000;
        $readmemh("data.hex", ram);
    end
    // synthesis translate_on

    // Geração do Byte Enable com base no funct3 e no offset do endereço
    always_comb begin
        byte_en = 4'b0000;
        if (MemWrite) begin
            case (funct3[1:0])
                2'b00: // SB (Store Byte)
                    case (byte_offset)
                        2'b00: byte_en = 4'b0001;
                        2'b01: byte_en = 4'b0010;
                        2'b10: byte_en = 4'b0100;
                        2'b11: byte_en = 4'b1000;
                    endcase
                2'b01: // SH (Store Halfword)
                    if (byte_offset[1]) byte_en = 4'b1100; // Endereço terminado em 10 ou 11
                    else                byte_en = 4'b0011; // Endereço terminado em 00 or 01
                2'b10: // SW (Store Word)
                    byte_en = 4'b1111; // Habilita todos os 4 bytes
                default: 
                    byte_en = 4'b1111;
            endcase
        end
    end

    // Processo de escrita síncrona seletiva (Gated por byte_en)
    always_ff @(posedge clk) begin
        if (byte_en[0]) ram[word_addr][7:0]   <= WriteData[7:0];
        if (byte_en[1]) ram[word_addr][15:8]  <= WriteData[15:8];
        if (byte_en[2]) ram[word_addr][23:16] <= WriteData[23:16];
        if (byte_en[3]) ram[word_addr][31:24] <= WriteData[31:24];
    end

    // Leitura assíncrona da palavra completa (O sinal mem_read_wb do Datapath cuida do alinhamento)
    assign ReadData = ram[word_addr];

endmodule