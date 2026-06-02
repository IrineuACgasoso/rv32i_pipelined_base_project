// =============================================================================
// pl_top_no_pll.sv (Módulo de Topo Alternativo - Sem PLL)
// Variante de síntese para a placa DE2-115, alimentando a CPU diretamente com
// o clock externo de 50 MHz (CLOCK_50).
//
// Ideal para:
//   - Testes rápidos de síntese lógica e mapeamento de pinos.
//   - Análise estática de timing (STA) pura usando o arquivo SDC.
// =============================================================================

`timescale 1ns / 1ps

module pl_top_no_pll (
    input  logic        CLOCK_50, // Clock nativo de 50 MHz da placa DE2-115
    input  logic [3:0]  KEY,      // KEY[0] atua como Reset ativo-baixo
    input  logic [17:0] SW,       // 18 Chaves deslizantes
    output logic [17:0] LEDR,     // 18 LEDs Vermelhos
    output logic [8:0]  LEDG,     // 9 LEDs Verdes
    output logic        UART_TXD, // Linha de transmissão Serial
    input  logic        UART_RXD  // Linha de recepção Serial
);

    // =========================================================================
    // Controle de Reset
    // =========================================================================
    // Sem o bloco de PLL, o rst_n é associado diretamente ao botão físico.
    // Nota: Em cenários reais de silício, recomenda-se passar esse sinal por um
    // sincronizador de reset para evitar problemas de metaestabilidade no pipeline.
    logic rst_n;
    assign rst_n = KEY[0];

    // =========================================================================
    // Instância do Núcleo Processador (pl_cpu)
    // =========================================================================
    // O clock de 50 MHz é injetado diretamente no sistema. 
    // Certifique-se de que o parâmetro CLK_HZ (se existente na pl_cpu) esteja 
    // configurado para 50_000_000 para que a UART calcule o baud rate de 9600 corretamente.
    pl_cpu cpu (
        .clk           (CLOCK_50),
        .rst_n         (rst_n),
        .SW            (SW),
        .KEY_IO        (KEY),
        .LEDR          (LEDR),
        .LEDG          (LEDG),
        .UART_TXD      (UART_TXD),
        .UART_RXD      (UART_RXD),
        
        // Sinais de depuração / Monitoramento (Deixados abertos no Topo)
        .PC            (),
        .wb_reg_write  (),
        .wb_reg_dst    (),
        .wb_reg_data   (),
        .mem_wr_en     (),
        .mem_wr_addr   (),
        .mem_wr_data   ()
    );

endmodule