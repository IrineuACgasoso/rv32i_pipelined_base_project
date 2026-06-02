// =============================================================================
// pl_cpu_tb.sv (Testbench do Processador Pipelined RV32I)
// Valida a execução de instruções comparando o resultado com um arquivo "golden".
// Detecta o fim da execução (HALT) monitorando loops periódicos no PC.
// =============================================================================

`timescale 1ns / 1ps

module pl_cpu_tb;

    // Parâmetros de controle de tempo da simulação
    localparam CLK_PERIOD  = 100;
    localparam CLK_HALF    = CLK_PERIOD / 2;
    localparam RESET_CYCLES = 4;
    localparam MAX_CYCLES  = 5000; // Proteção contra loops infinitos (timeout)

    // Sinais de estímulo e monitoramento do processador
    logic        clk, rst_n;
    logic [31:0] PC;
    logic [17:0] SW    = 18'h15555;
    logic [3:0]  KEY   = 4'hF;
    logic [17:0] LEDR;
    logic [8:0]  LEDG;
    logic        UART_TXD;
    logic        UART_RXD = 1'b1;

    // Sinais de diagnóstico (sondam o interior do processador para debug)
    logic        wb_reg_write;
    logic [4:0]  wb_reg_dst;
    logic [31:0] wb_reg_data;
    logic        mem_wr_en;
    logic [7:0]  mem_wr_addr;
    logic [31:0] mem_wr_data;

    // Instanciação do processador (DUT - Device Under Test)
    pl_cpu dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .PC           (PC),
        .SW           (SW),
        .KEY_IO       (KEY),
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

    // Geração do sinal de Clock
    initial clk = 1'b0;
    always #(CLK_HALF) clk = ~clk;

    // Geração do sinal de Reset ativo em nível baixo (segura por 4 ciclos)
    initial begin
        rst_n = 1'b0;
        repeat (RESET_CYCLES) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
    end

    integer out_fd;
    logic [31:0] dmem_shadow [0:255]; // Espelho da memória para validação

    // Monitor do Write-Back: Imprime no console sempre que um registrador é atualizado
    always @(posedge clk) begin
        if (rst_n && wb_reg_write && wb_reg_dst != 5'b0)
            $display("[WB] REG x%0d = 0x%08X", wb_reg_dst, wb_reg_data);
    end

    // Monitor da Memória: Captura e imprime escritas na RAM de dados
    always @(posedge clk) begin
        if (rst_n && mem_wr_en) begin
            dmem_shadow[mem_wr_addr] <= mem_wr_data;
            $display("[MEM] dmem[%0d] = 0x%08X", mem_wr_addr, mem_wr_data);
        end
    end

    // Variáveis e Registros para a lógica de detecção de parada (HALT)
    localparam BRANCH_PERIOD = 3;
    localparam HALT_CONFIRM  = 9;

    logic [31:0] pc_hist [0:BRANCH_PERIOD]; // Guarda os últimos PCs executados
    integer      halt_cnt;
    integer      cycle_cnt;
    logic        halted;

    integer i, j, errors;

    // Bloco Principal de Teste
    initial begin
        out_fd    = $fopen("output.txt", "w"); // Cria o arquivo de log de saída
        halt_cnt  = 0;
        cycle_cnt = 0;
        halted    = 1'b0;

        // Inicializa estruturas de dados do teste
        for (j = 0; j <= BRANCH_PERIOD; j++) pc_hist[j] = 32'hFFFFFFFF;
        for (i = 0; i < 256; i++)            dmem_shadow[i] = 32'b0;

        @(posedge rst_n); // Aguarda o fim do reset

        // Loop de simulação ciclo a ciclo
        while (!halted && cycle_cnt < MAX_CYCLES) begin
            @(posedge clk);
            #1; // Pequeno delay para os sinais estabilizarem após a borda
            cycle_cnt++;

            // Desloca o histórico de PCs (Shift Register)
            for (j = BRANCH_PERIOD; j > 0; j--)
                pc_hist[j] = pc_hist[j-1];
            pc_hist[0] = PC;

            // Se o PC atual for idêntico ao de 3 ciclos atrás repetidamente,
            // significa que entramos no loop de HALT (beq x0, x0, 0)
            if (pc_hist[0] != 32'hFFFFFFFF &&
                pc_hist[BRANCH_PERIOD] != 32'hFFFFFFFF &&
                pc_hist[0] == pc_hist[BRANCH_PERIOD]) begin
                halt_cnt++;
                if (halt_cnt >= HALT_CONFIRM)
                    halted = 1'b1; // Parada confirmada
            end else begin
                halt_cnt = 0;
            end
        end

        // Verificação de timeout
        if (cycle_cnt >= MAX_CYCLES)
            $display("AVISO: timeout apos %0d ciclos", MAX_CYCLES);
        else
            $display("Halt detectado em PC=0x%08X apos %0d ciclos.", PC, cycle_cnt);

        // Varre e despeja o Banco de Registradores real (via hierarquia) no arquivo de saída
        $display("--- Estado final dos registradores ---");
        $fdisplay(out_fd, "--- estado final ---");
        for (i = 1; i < 32; i++) begin
            if (^dut.datapath.regfile.rf[i] !== 1'bX && dut.datapath.regfile.rf[i] != 32'b0) begin
                $display("  x%0d = 0x%08X", i, dut.datapath.regfile.rf[i]);
                $fdisplay(out_fd, "FINAL REG %2d = 0x%08X", i, dut.datapath.regfile.rf[i]);
            end
        end

        // Varre e despeja a RAM física de dados no arquivo de saída
        $display("--- Estado final da dmem ---");
        for (i = 0; i < 16; i++) begin
            if (!$isunknown(dut.datapath.dmem.ram[i]) && dut.datapath.dmem.ram[i] != 32'b0) begin
                $display("  dmem[%0d] = 0x%08X", i, dut.datapath.dmem.ram[i]);
                $fdisplay(out_fd, "FINAL MEM[%3d] = 0x%08X", i, dut.datapath.dmem.ram[i]);
            end
        end

        $fclose(out_fd);

        // Executa a função de validação automatizada contra o gabarito
        $display("--- Comparacao com golden.txt ---");
        errors = compare_with_golden();
        if (errors == 0)
            $display("PASS: saida corresponde ao golden.");
        else
            $display("FAIL: %0d diferenca(s) encontrada(s).", errors);

        $stop; // Pausa a simulação no ModelSim/Vivado
    end

    // Função que lê linha por linha o "golden.txt" e o "output.txt" gerado, acusando erros
    function automatic integer compare_with_golden();
        integer gfd, ofd;
        reg [1023:0] gline, oline;
        integer errs;
        errs = 0;
        gfd = $fopen("golden.txt", "r");
        ofd = $fopen("output.txt", "r");
        if (gfd == 0) begin
            $display("AVISO: golden.txt nao encontrado.");
            return 0;
        end
        if (ofd == 0) begin
            $display("ERRO: output.txt nao pode ser aberto.");
            return 1;
        end
        while (!$feof(gfd)) begin
            void'($fgets(gline, gfd));
            void'($fgets(oline, ofd));
            if (gline != oline) begin
                $display("DIFF golden: %s  output: %s", gline, oline);
                errs++;
            end
        end
        $fclose(gfd);
        $fclose(ofd);
        return errs;
    endfunction

endmodule