// =============================================================================
// pl_cpu_tb.sv  (ESTENDIDO)
// Testbench -- RV32I pipelined completo
//
// Programa de teste (ver assemble.py para detalhes completos):
//   Testa: LW/SW, ADD, ADDI, BNE (tomado), BLT (tomado), BGE (tomado),
//          BLTU (tomado), SB, SH, LB, LBU, LH, LHU, JAL, JALR, HALT
//
// Estado esperado apos HALT:
//   x1=10  x2=20  x3=-10  x4=30  x5=5   x6=15  x7=7   x8=8   x9=9
//   x10=0x41  x11=0x42  x12=0x41  x13=0x41  x14=0x42  x15=0x42
//   x16=0x6C  x17=17    x18=0x78  x19=19
//   dmem[0]=10  dmem[1]=20  dmem[2]=-10  dmem[3]=0x00420041  dmem[4]=30
//
// Deteccao de HALT:
//   HALT = opcode 0001011 -> NOP eterno. O PC oscila com o loop BEQ
//   que segue o HALT (beq x0,x0,0). Usa deteccao de periodo como no base.
// =============================================================================

`timescale 1ns / 1ps

module pl_cpu_tb;

    localparam CLK_PERIOD  = 100;
    localparam CLK_HALF    = CLK_PERIOD / 2;
    localparam RESET_CYCLES = 4;
    localparam MAX_CYCLES  = 5000;

    logic        clk, rst_n;
    logic [31:0] PC;
    logic [17:0] SW    = 18'h15555;
    logic [3:0]  KEY   = 4'hF;
    logic [17:0] LEDR;
    logic [8:0]  LEDG;
    logic        UART_TXD;
    logic        UART_RXD = 1'b1;

    logic        wb_reg_write;
    logic [4:0]  wb_reg_dst;
    logic [31:0] wb_reg_data;
    logic        mem_wr_en;
    logic [7:0]  mem_wr_addr;
    logic [31:0] mem_wr_data;

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

    initial clk = 1'b0;
    always #(CLK_HALF) clk = ~clk;

    initial begin
        rst_n = 1'b0;
        repeat (RESET_CYCLES) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
    end

    integer out_fd;
    logic [31:0] dmem_shadow [0:255];

    always @(posedge clk) begin
        if (rst_n && wb_reg_write && wb_reg_dst != 5'b0)
            $display("[WB] REG x%0d = 0x%08X", wb_reg_dst, wb_reg_data);
    end

    always @(posedge clk) begin
        if (rst_n && mem_wr_en) begin
            dmem_shadow[mem_wr_addr] <= mem_wr_data;
            $display("[MEM] dmem[%0d] = 0x%08X", mem_wr_addr, mem_wr_data);
        end
    end

    localparam BRANCH_PERIOD = 3;
    localparam HALT_CONFIRM  = 9;

    logic [31:0] pc_hist [0:BRANCH_PERIOD];
    integer      halt_cnt;
    integer      cycle_cnt;
    logic        halted;

    integer i, j, errors;

    initial begin
        out_fd    = $fopen("output.txt", "w");
        halt_cnt  = 0;
        cycle_cnt = 0;
        halted    = 1'b0;

        for (j = 0; j <= BRANCH_PERIOD; j++) pc_hist[j] = 32'hFFFFFFFF;
        for (i = 0; i < 256; i++)            dmem_shadow[i] = 32'b0;

        @(posedge rst_n);

        while (!halted && cycle_cnt < MAX_CYCLES) begin
            @(posedge clk);
            #1;
            cycle_cnt++;

            for (j = BRANCH_PERIOD; j > 0; j--)
                pc_hist[j] = pc_hist[j-1];
            pc_hist[0] = PC;

            if (pc_hist[0] != 32'hFFFFFFFF &&
                pc_hist[BRANCH_PERIOD] != 32'hFFFFFFFF &&
                pc_hist[0] == pc_hist[BRANCH_PERIOD]) begin
                halt_cnt++;
                if (halt_cnt >= HALT_CONFIRM)
                    halted = 1'b1;
            end else begin
                halt_cnt = 0;
            end
        end

        if (cycle_cnt >= MAX_CYCLES)
            $display("AVISO: timeout apos %0d ciclos", MAX_CYCLES);
        else
            $display("Halt detectado em PC=0x%08X apos %0d ciclos.", PC, cycle_cnt);

        $display("--- Estado final dos registradores ---");
        $fdisplay(out_fd, "--- estado final ---");

        for (i = 1; i < 32; i++) begin
            if (^dut.datapath.regfile.rf[i] !== 1'bX &&
                dut.datapath.regfile.rf[i] != 32'b0) begin
                $display("  x%0d = 0x%08X", i, dut.datapath.regfile.rf[i]);
                $fdisplay(out_fd, "FINAL REG %2d = 0x%08X", i, dut.datapath.regfile.rf[i]);
            end
        end

        $display("--- Estado final da dmem ---");
        for (i = 0; i < 16; i++) begin
            if (!$isunknown(dut.datapath.dmem.ram[i]) &&
                dut.datapath.dmem.ram[i] != 32'b0) begin
                $display("  dmem[%0d] = 0x%08X", i, dut.datapath.dmem.ram[i]);
                $fdisplay(out_fd, "FINAL MEM[%3d] = 0x%08X", i, dut.datapath.dmem.ram[i]);
            end
        end

        $fclose(out_fd);

        $display("--- Comparacao com golden.txt ---");
        errors = compare_with_golden();
        if (errors == 0)
            $display("PASS: saida corresponde ao golden.");
        else
            $display("FAIL: %0d diferenca(s) encontrada(s).", errors);

        $stop;
    end

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