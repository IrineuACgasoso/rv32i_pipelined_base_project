// =============================================================================
// pl_top.sv (Módulo de Topo Principal - RV32I Pipelined)
// Top-level para síntese física na placa Altera/Intel DE2-115.
//
// Instancia o gerador de clock (PLL) e o processador principal (pl_cpu).
// O clock do sistema é reduzido de 50 MHz para 10 MHz para garantir folga
// no fechamento de timing (STA) do datapath crítico.
//
// Pinagem (DE2-115):
//   CLOCK_50 : Clock nativo de 50 MHz do oscilador da placa
//   KEY[0]   : Reset manual ativo-baixo (Pressionado = 0 = Reset)
//   KEY[3:1] : Botões lidos no banco de registradores MMIO (0x404)
//   SW[17:0] : Chaves deslizantes lidas via MMIO (0x400)
//   LEDR     : 18 LEDs vermelhos mapeados via MMIO (0x408)
//   LEDG     : 9 LEDs verdes mapeados via MMIO (0x40C)
//   UART_TXD : Transmissão RS-232 (Padrão 9600 8N1)
//   UART_RXD : Recepção RS-232
// =============================================================================

`timescale 1ns / 1ps

module pl_top (
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,          // KEY[0] atua como Reset
    input  logic [17:0] SW,
    output logic [17:0] LEDR,
    output logic [8:0]  LEDG,
    output logic        UART_TXD,
    input  logic        UART_RXD
);

    // =========================================================================
    // Sinais Internos de Gerenciamento de Clock e Reset
    // =========================================================================
    logic clk;          // Clock principal do sistema (10 MHz vindo da PLL)
    logic pll_locked;   // Flag em alto (1) quando a frequência da PLL estabiliza
    logic rst_n;        // Sinal de reset da CPU (Sincronizado com PLL + KEY[0])

    // =========================================================================
    // Instância da PLL (Phase-Locked Loop)
    // Reduz o clock da placa (50 MHz) para a frequência de operação da CPU (10 MHz)
    // =========================================================================
    pll_10mhz pll (
        .inclk0 (CLOCK_50),
        .c0     (clk),
        .locked (pll_locked)
    );

    // Proteção de Reset de Hardware:
    // O processador só sai do estado de reset (rst_n = 1) SE o usuário não estiver 
    // segurando o botão (KEY[0] == 1) E a PLL já tiver travado o clock (pll_locked == 1).
    assign rst_n = pll_locked & KEY[0];

    // =========================================================================
    // Instância do Núcleo Processador (pl_cpu)
    // =========================================================================
    pl_cpu cpu (
        .clk           (clk),
        .rst_n         (rst_n),
        .SW            (SW),
        .KEY_IO        (KEY),
        .LEDR          (LEDR),
        .LEDG          (LEDG),
        .UART_TXD      (UART_TXD),
        .UART_RXD      (UART_RXD),
        
        // Sinais de depuração / Monitoramento (Desconectados na síntese do Top-Level)
        .PC            (),
        .wb_reg_write  (),
        .wb_reg_dst    (),
        .wb_reg_data   (),
        .mem_wr_en     (),
        .mem_wr_addr   (),
        .mem_wr_data   ()
    );

endmodule