// =============================================================================
// pl_mmio.sv (Controlador de E/S Mapeada em Memória)
// Interfaceia a CPU com os periféricos da placa FPGA (DE2-115) e UART.
//
// Mapa de Endereços (Mapeamento a partir do bit 10 da ALU = 1):
//   addr[4:2] | Offset | Periférico   | Permissão  | Formato
//   --------- | ------ | ------------ | ---------- | ------------------------
//     3'b000  | 0x400  | Chaves (SW)  | Read-Only  | [17:0]
//     3'b001  | 0x404  | Botões (KEY) | Read-Only  | [3:0]
//     3'b010  | 0x408  | LEDR         | Write-Only | [17:0]
//     3'b011  | 0x40C  | LEDG         | Write-Only | [8:0]
//     3'b100  | 0x410  | UART         | Read/Write | R: {busy, ready, data[7:0]} / W: 32-bits (4 bytes)
//     3'b101  | 0x414  | CYCLE        | Read-Only  | [31:0] Contador de Ciclos
// =============================================================================

`timescale 1ns / 1ps

module pl_mmio (
    input  logic        clk,
    input  logic        rst_n,
    
    // Interface com o Datapath (Estágio MEM)
    input  logic        MemWrite,
    input  logic        MemRead,
    input  logic [2:0]  addr,        // alu_result[4:2]
    input  logic [31:0] WriteData,
    output logic [31:0] ReadData,

    // Interface com os Periféricos Físicos (FPGA)
    input  logic [17:0] SW,
    input  logic [3:0]  KEY,
    output logic [17:0] LEDR,
    output logic [8:0]  LEDG,

    // Interface Serial (RS-232)
    output logic        UART_TXD,
    input  logic        UART_RXD
);

    // =========================================================================
    // 1. Instância do Controlador UART
    // =========================================================================
    logic       tx_write;
    logic       tx_busy;
    logic [7:0] rx_data;
    logic       rx_valid;
    logic [7:0] tx_byte; // Byte atual sendo despachado para a UART

    pl_uart #(
        .CLK_HZ (50_000_000),
        .BAUD   (9_600)
    ) uart_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_write (tx_write),
        .tx_data  (tx_byte),
        .tx_busy  (tx_busy),
        .rx_data  (rx_data),
        .rx_valid (rx_valid),
        .TXD      (UART_TXD),
        .RXD      (UART_RXD)
    );

    // =========================================================================
    // 2. Sequenciador de Transmissão UART (Little-Endian)
    // Transmite 4 bytes sequencialmente: Byte 0 (LSB) -> Byte 3 (MSB)
    // =========================================================================
    logic [31:0] tx_word;      // Buffer da palavra de 32 bits
    logic [1:0]  tx_byte_idx;  // Índice do byte atual (0 a 3)
    logic        tx_word_busy; // Flag de ocupação do sequenciador

    // Mux para selecionar o byte atual a ser enviado
    always_comb begin
        case (tx_byte_idx)
            2'd0: tx_byte = tx_word[7:0];
            2'd1: tx_byte = tx_word[15:8];
            2'd2: tx_byte = tx_word[23:16];
            2'd3: tx_byte = tx_word[31:24];
        endcase
    end

    // Habilita a escrita na UART se houver dado pendente e a UART estiver livre
    assign tx_write = tx_word_busy & ~tx_busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_word      <= 32'b0;
            tx_byte_idx  <= 2'b00;
            tx_word_busy <= 1'b0;
        end else if (MemWrite && (addr == 3'b100) && !tx_word_busy) begin
            // Captura a palavra da CPU e inicia a máquina de estados de envio
            tx_word      <= WriteData;
            tx_byte_idx  <= 2'd0;
            tx_word_busy <= 1'b1;
        end else if (tx_word_busy && !tx_busy) begin
            // A UART aceitou o byte. Avança para o próximo ou finaliza
            if (tx_byte_idx == 2'd3) begin
                tx_word_busy <= 1'b0;
            end else begin
                tx_byte_idx <= tx_byte_idx + 1'b1;
            end
        end
    end

    // =========================================================================
    // 3. Flags de Recepção UART (Sticky Bit)
    // =========================================================================
    logic rx_ready;

    // Retém o sinal de que um dado chegou até que a CPU faça a leitura
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_ready <= 1'b0;
        end else if (rx_valid) begin
            rx_ready <= 1'b1; // Seta quando chega novo byte
        end else if (MemRead && (addr == 3'b100)) begin
            rx_ready <= 1'b0; // Limpa automaticamente ao ser lido pela CPU
        end
    end

    // =========================================================================
    // 4. Contador de Ciclos de Hardware (Read-Only)
    // =========================================================================
    logic [31:0] cycle_count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) cycle_count <= 32'b0;
        else        cycle_count <= cycle_count + 32'd1;
    end

    // =========================================================================
    // 5. Multiplexador de Leitura (MMIO -> Datapath)
    // =========================================================================
    always_comb begin
        case (addr)
            3'b000:  ReadData = {14'b0, SW};
            3'b001:  ReadData = {28'b0, KEY};
            // UART Status/Data = {22 zeros, tx_is_busy, rx_has_data, rx_byte}
            3'b100:  ReadData = {22'b0, (tx_word_busy | tx_busy), rx_ready, rx_data};
            3'b101:  ReadData = cycle_count;
            default: ReadData = 32'b0;
        endcase
    end

    // =========================================================================
    // 6. Registradores de Saída para LEDs (Write-Only)
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            LEDR <= 18'b0;
            LEDG <=  9'b0;
        end else if (MemWrite) begin
            case (addr)
                3'b010: LEDR <= WriteData[17:0];
                3'b011: LEDG <= WriteData[8:0];
                default: ; // Ignora outras escritas
            endcase
        end
    end

endmodule