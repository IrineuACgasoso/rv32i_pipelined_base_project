// =============================================================================
// pl_uart.sv (Controlador de Comunicação Serial RS-232)
// Implementação padrão 8N1: 8 bits de dados, sem paridade, 1 stop bit.
//
// Parâmetros:
//   CLK_HZ : Frequência do clock da CPU em Hz (Default: 50 MHz)
//   BAUD   : Taxa de transmissão desejada (Default: 9600)
//
// Interface de Transmissão (TX):
//   tx_write : Strobe de 1 ciclo. Carrega tx_data e inicia o envio.
//   tx_busy  : Permanece em alto (1) durante todo o processo de shift out.
//
// Interface de Recepção (RX):
//   rx_data  : Armazena o último byte completo recebido de forma estável.
//   rx_valid : Pulsa em alto por exatamente 1 ciclo assim que um byte é validado.
// =============================================================================

`timescale 1ns / 1ps

module pl_uart #(
    parameter int CLK_HZ = 50_000_000,
    parameter int BAUD   =      9_600
) (
    input  logic       clk,
    input  logic       rst_n,      // Reset assíncrono ativo-baixo

    // Interface com o Controlador de MMIO
    input  logic       tx_write,   // Sinal de escrita (strobe)
    input  logic [7:0] tx_data,    // Byte a ser enviado
    output logic       tx_busy,    // Flag de transmissor ocupado
    output logic [7:0] rx_data,    // Byte recebido e estabilizado
    output logic       rx_valid,   // Strobe de novo dado recebido

    // Pinos Físicos da Interface RS-232 (Nível TTL)
    output logic       TXD,        // Linha de transmissão física (Idle = 1)
    input  logic       RXD         // Linha de recepção física (Idle = 1)
);

    // =========================================================================
    // Parâmetros Derivados: Divisor de Baud-Rate
    // =========================================================================
    localparam int CLKS_PER_BIT = CLK_HZ / BAUD;

    // =========================================================================
    // 1. MÁQUINA DE ESTADOS DO TRANSMISSOR (TX)
    // =========================================================================
    typedef enum logic [1:0] {
        TX_IDLE  = 2'd0,
        TX_START = 2'd1,
        TX_DATA  = 2'd2,
        TX_STOP  = 2'd3
    } tx_state_t;

    tx_state_t   tx_state;
    logic [15:0] tx_cnt;       // Contador de ciclos de clock por bit
    logic [2:0]  tx_bit_idx;   // Ponteiro do bit de dados atual (0 a 7)
    logic [7:0]  tx_sr;        // Registrador de deslocamento (Shift Register)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state   <= TX_IDLE;
            TXD        <= 1'b1; // Linha serial em repouso fica em HIGH
            tx_busy    <= 1'b0;
            tx_cnt     <= '0;
            tx_bit_idx <= '0;
            tx_sr      <= '0;
        end else begin
            case (tx_state)

                // --- Aguarda o comando de escrita da CPU ---
                TX_IDLE: begin
                    TXD     <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_write) begin
                        tx_sr    <= tx_data;
                        tx_busy  <= 1'b1;
                        tx_cnt   <= '0;
                        tx_state <= TX_START;
                    end
                end

                // --- Envia o START BIT (Linha em LOW) ---
                TX_START: begin
                    TXD <= 1'b0;
                    if (tx_cnt == CLKS_PER_BIT - 1) begin
                        tx_cnt     <= '0;
                        tx_bit_idx <= '0;
                        tx_state   <= TX_DATA;
                    end else begin
                        tx_cnt <= tx_cnt + 1'b1;
                    end
                end

                // --- Envia os 8 Bits de Dados (LSB Primeiro) ---
                TX_DATA: begin
                    TXD <= tx_sr[0]; // Envia o bit menos significativo atual
                    if (tx_cnt == CLKS_PER_BIT - 1) begin
                        tx_cnt <= '0;
                        tx_sr  <= {1'b0, tx_sr[7:1]}; // Desloca para a direita
                        if (tx_bit_idx == 3'd7) begin
                            tx_bit_idx <= '0;
                            tx_state   <= TX_STOP;
                        end else begin
                            tx_bit_idx <= tx_bit_idx + 1'b1;
                        end
                    end else begin
                        tx_cnt <= tx_cnt + 1'b1;
                    end
                end

                // --- Envia o STOP BIT (Linha em HIGH) ---
                TX_STOP: begin
                    TXD <= 1'b1;
                    if (tx_cnt == CLKS_PER_BIT - 1) begin
                        tx_cnt   <= '0;
                        tx_busy  <= 1'b0;
                        tx_state <= TX_IDLE;
                    end else begin
                        tx_cnt <= tx_cnt + 1'b1;
                    end
                end

            endcase
        end
    end

    // =========================================================================
    // 2. SINCRONIZADOR DE SINAL RXD (Anti-Metaestabilidade)
    // =========================================================================
    logic rxd_s, rxd_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rxd_s <= 1'b1;
            rxd_q <= 1'b1;
        end else begin
            rxd_s <= RXD;   // Primeiro estágio de captura
            rxd_q <= rxd_s; // Segundo estágio estabilizado (seguro para a FSM)
        end
    end

    // =========================================================================
    // 3. MÁQUINA DE ESTADOS DO RECEPTOR (RX)
    // =========================================================================
    typedef enum logic [1:0] {
        RX_IDLE  = 2'd0,
        RX_START = 2'd1,
        RX_DATA  = 2'd2,
        RX_STOP  = 2'd3
    } rx_state_t;

    rx_state_t   rx_state;
    logic [15:0] rx_cnt;       // Contador de ciclos para amostragem
    logic [2:0]  rx_bit_idx;   // Ponteiro de reconstrução do bit (0 a 7)
    logic [7:0]  rx_sr;        // Registrador de deslocamento de entrada

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state   <= RX_IDLE;
            rx_data    <= 8'b0;
            rx_valid   <= 1'b0;
            rx_cnt     <= '0;
            rx_bit_idx <= '0;
            rx_sr      <= '0;
        end else begin
            rx_valid <= 1'b0; // Garante que o pulso dure estritamente 1 ciclo

            case (rx_state)

                // --- Aguarda a descida da linha (Falling Edge do Start Bit) ---
                RX_IDLE: begin
                    if (!rxd_q) begin
                        rx_cnt   <= '0;
                        rx_state <= RX_START;
                    end
                end

                // --- Amostra no meio do bit para validar o START BIT ---
                RX_START: begin
                    if (rx_cnt == (CLKS_PER_BIT / 2) - 1) begin
                        if (!rxd_q) begin // Confirmado: linha ainda em LOW
                            rx_cnt     <= '0;
                            rx_bit_idx <= '0;
                            rx_state   <= RX_DATA;
                        end else begin
                            rx_state <= RX_IDLE; // Ruído/Glitch detectado
                        end
                    end else begin
                        rx_cnt <= rx_cnt + 1'b1;
                    end
                end

                // --- Captura os 8 Bits de Dados em intervalos regulares ---
                RX_DATA: begin
                    if (rx_cnt == CLKS_PER_BIT - 1) begin
                        rx_cnt <= '0;
                        rx_sr  <= {rxd_q, rx_sr[7:1]}; // Injeta o bit no MSB (LSB entra primeiro)
                        if (rx_bit_idx == 3'd7) begin
                            rx_bit_idx <= '0;
                            rx_state   <= RX_STOP;
                        end else begin
                            rx_bit_idx <= rx_bit_idx + 1'b1;
                        end
                    end else begin
                        rx_cnt <= rx_cnt + 1'b1;
                    end
                end

                // --- Confirma o STOP BIT (Linha em HIGH) e disponibiliza o dado ---
                RX_STOP: begin
                    if (rx_cnt == CLKS_PER_BIT - 1) begin
                        rx_cnt   <= '0;
                        rx_state <= RX_IDLE;
                        if (rxd_q) begin // Stop bit válido detectado
                            rx_data  <= rx_sr;
                            rx_valid <= 1'b1; // Notifica a CPU / MMIO
                        end
                        // Se rxd_q for 0 aqui, ocorreu um Framing Error (descartado silenciosamente)
                    end else begin
                        rx_cnt <= rx_cnt + 1'b1;
                    end
                end

            endcase
        end
    end

endmodule