// =============================================================================
// pl_dmem.sv  (ESTENDIDO)
// Memoria de dados -- RV32I pipelined
//
// Capacidade : 256 palavras x 32 bits = 1 KB
// Init file  : data.mif (sintese) / data.hex (simulacao)
//
// Operacoes suportadas (gated por funct3 + MemWrite/MemRead):
//   funct3=000  LB / SB  (byte)
//   funct3=001  LH / SH  (halfword)
//   funct3=010  LW / SW  (word)
//   funct3=100  LBU      (byte, zero-extend)
//   funct3=101  LHU      (halfword, zero-extend)
//
// Obs: o sign-extend do dado lido e feito no estagio WB (pl_datapath),
// usando mem_wb.funct3. A dmem entrega sempre os 32 bits da palavra,
// e o datapath extrai o sub-campo correto.
//
// Escrita sub-palavra: usa byte-enable sincrono.
//   SB: escreve somente o byte indicado por addr[1:0]
//   SH: escreve somente os 2 bytes indicados por addr[1] (halfword-aligned)
//   SW: escreve a palavra inteira
// =============================================================================

`timescale 1ns / 1ps

module pl_dmem (
    input  logic        clk,
    input  logic        MemWrite,
    input  logic [2:0]  funct3,      // 000=SB 001=SH 010=SW
    input  logic [9:0]  addr,        // alu_result[9:0] -- endereco de BYTE
    input  logic [31:0] WriteData,
    output logic [31:0] ReadData     // palavra completa; WB faz sign/zero-extend
);

    (* ram_init_file = "data.mif" *) logic [31:0] ram [0:255];

    // synthesis translate_off
    initial begin
        for (int i = 0; i < 256; i++) ram[i] = 32'h00000000;
        $readmemh("data.hex", ram);
    end
    // synthesis translate_on

    // Endereco de palavra (bits [9:2]) e offset de byte dentro da palavra
    wire [7:0]  word_addr = addr[9:2];
    wire [1:0]  byte_off  = addr[1:0];

    // Escrita sincrona com byte-enable
    always @(posedge clk) begin
        if (MemWrite) begin
            case (funct3)
                3'b000: begin // SB
                    case (byte_off)
                        2'd0: ram[word_addr][7:0]   <= WriteData[7:0];
                        2'd1: ram[word_addr][15:8]  <= WriteData[7:0];
                        2'd2: ram[word_addr][23:16] <= WriteData[7:0];
                        2'd3: ram[word_addr][31:24] <= WriteData[7:0];
                    endcase
                end
                3'b001: begin // SH (assume halfword-aligned)
                    if (byte_off[1] == 1'b0)
                        ram[word_addr][15:0]  <= WriteData[15:0];
                    else
                        ram[word_addr][31:16] <= WriteData[15:0];
                end
                default: // SW (funct3=010)
                    ram[word_addr] <= WriteData;
            endcase
        end
    end

    // Leitura assincrona: retorna a palavra inteira (WB extrai sub-campo)
    assign ReadData = ram[word_addr];

endmodule