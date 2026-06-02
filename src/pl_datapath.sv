// =============================================================================
// pl_datapath.sv (Caminho de Dados Pipelined de 5 Estágios)
// Suporta o RV32I completo com as seguintes extensões:
// - Desvios Condicionais (BEQ, BNE, BLT, BGE, BLTU, BGEU) resolvidos no EX.
// - Saltos Incondicionais (JAL, JALR) com flush de 2 bolhas se tomados.
// - Acesso parcial à memória: Loads (LB, LH, LBU, LHU) e Stores (SB, SH).
// =============================================================================

`timescale 1ns / 1ps

import pl_pipe_pkg::*;

module pl_datapath (
    input  logic        clk,
    input  logic        rst_n,

    // Sinais de controle vindos da Unidade de Controle (Estágio ID)
    input  logic        ALUSrc,
    input  logic        MemtoReg,
    input  logic        RegWrite,
    input  logic        MemRead,
    input  logic        MemWrite,
    input  logic [2:0]  BranchType, 
    input  logic [1:0]  JalJalr,
    input  logic [1:0]  ALUOp,

    // Código de operação para a ALU (vindo do pl_alu_ctrl)
    input  logic [3:0]  ALU_CC,

    // Feedbacks enviados de volta para o Top/Controle
    output logic [6:0]  Opcode,
    output logic [2:0]  Funct3_EX,
    output logic [6:0]  Funct7_EX,
    output logic [1:0]  ALUOp_EX,
    output logic [31:0] PC,

    // Interface de I/O (MMIO - Placa FPGA)
    input  logic [17:0] SW,
    input  logic [3:0]  KEY,
    output logic [17:0] LEDR,
    output logic [8:0]  LEDG,
    output logic        UART_TXD,
    input  logic        UART_RXD,

    // Sondas de observabilidade para o Testbench
    output logic        wb_reg_write,
    output logic [4:0]  wb_reg_dst,
    output logic [31:0] wb_reg_data,
    output logic        mem_wr_en,
    output logic [7:0]  mem_wr_addr,
    output logic [31:0] mem_wr_data
);

    // =========================================================================
    // Sinais Internos e Estruturas dos Registradores de Pipeline
    // =========================================================================
    logic [31:0] pc_reg, pc_plus4;

    if_id_t  if_id;   // Registrador de Pipeline IF/ID
    id_ex_t  id_ex;   // Registrador de Pipeline ID/EX
    ex_mem_t ex_mem;  // Registrador de Pipeline EX/MEM
    mem_wb_t mem_wb;  // Registrador de Pipeline MEM/WB

    logic        stall;
    logic        pc_src; // 1 = Salto/Branch tomado (limpa o pipeline), 0 = Segue PC+4
    logic [31:0] branch_target;

    logic [31:0] rd1, rd2, imm_ext;

    logic [1:0]  fwd_a, fwd_b;
    logic [31:0] fwd_srca, fwd_srcb, alu_srcb;
    logic [31:0] alu_result;
    logic        zero;

    logic [31:0] wb_data;
    logic        mmio_sel;
    logic [31:0] dmem_rd, mmio_rd, mem_read_data;

    // =========================================================================
    // ESTÁGIO 1: IF (Instruction Fetch) - Busca de Instrução
    // =========================================================================
    logic [31:0] instr_if;

    // Gerenciamento do Program Counter (PC)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)      pc_reg <= 32'b0;
        else if (pc_src) pc_reg <= branch_target; // Correção de fluxo (Branch/Jump tomado)
        else if (!stall) pc_reg <= pc_plus4;       // Avança normal se não houver conflito (Hazard)
    end

    assign PC       = pc_reg;
    assign pc_plus4 = pc_reg + 32'd4;

    // Memória de Instruções (ROM)
    pl_imem imem (
        .addr  (pc_reg[9:2]),
        .instr (instr_if)
    );

    // --- REGISTRADOR DE PIPELINE IF/ID ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id.pc    <= 32'b0;
            if_id.instr <= 32'b0;
        end else if (pc_src) begin // Flush: transforma a instrução em NOP se houver salto
            if_id.pc    <= 32'b0;
            if_id.instr <= 32'b0;
        end else if (!stall) begin
            if_id.pc    <= pc_reg;
            if_id.instr <= instr_if;
        end
    end

    // =========================================================================
    // ESTÁGIO 2: ID (Instruction Decode) - Decodificação e Leitura de Registradores
    // =========================================================================
    assign Opcode = if_id.instr[6:0];

    // Unidade de Detecção de Hazard (Stall por dependência de dados em Loads)
    pl_hazard hazard (
        .if_id_rs1      (if_id.instr[19:15]),
        .if_id_rs2      (if_id.instr[24:20]),
        .id_ex_rd       (id_ex.rd),
        .id_ex_mem_read (id_ex.mem_read),
        .stall          (stall)
    );

    // Banco de Registradores (Leitura assíncrona, escrita síncrona)
    pl_regfile regfile (
        .clk       (clk),
        .RegWrite  (mem_wb.reg_write),
        .rs1       (if_id.instr[19:15]),
        .rs2       (if_id.instr[24:20]),
        .rd        (mem_wb.rd),
        .WriteData (wb_data),
        .ReadData1 (rd1),
        .ReadData2 (rd2)
    );

    // Extensor de Sinal (Gera os imediatos para Tipo-I, S, B, U, J)
    pl_sign_ext sign_ext (
        .Instr  (if_id.instr),
        .ImmExt (imm_ext)
    );

    // LÓGICA DE FORMATAÇÃO DE LOADS PARCIAIS (Atua no estágio WB)
    logic [31:0] mem_read_wb;
    always_comb begin
        case (mem_wb.funct3)
            3'b000: // LB: Lê byte e estende o sinal de 8 para 32 bits
                case (mem_wb.alu_result[1:0])
                    2'd0: mem_read_wb = {{24{mem_wb.read_data[7]}},  mem_wb.read_data[7:0]};
                    2'd1: mem_read_wb = {{24{mem_wb.read_data[15]}}, mem_wb.read_data[15:8]};
                    2'd2: mem_read_wb = {{24{mem_wb.read_data[23]}}, mem_wb.read_data[23:16]};
                    2'd3: mem_read_wb = {{24{mem_wb.read_data[31]}}, mem_wb.read_data[31:24]};
                endcase
            3'b001: // LH: Lê halfword e estende o sinal de 16 para 32 bits
                mem_read_wb = mem_wb.alu_result[1] ?
                    {{16{mem_wb.read_data[31]}}, mem_wb.read_data[31:16]} :
                    {{16{mem_wb.read_data[15]}}, mem_wb.read_data[15:0]};
            3'b010: // LW: Lê a palavra inteira de 32 bits
                mem_read_wb = mem_wb.read_data;
            3'b100: // LBU: Lê byte e preenche com zeros (unsigned)
                case (mem_wb.alu_result[1:0])
                    2'd0: mem_read_wb = {24'b0, mem_wb.read_data[7:0]};
                    2'd1: mem_read_wb = {24'b0, mem_wb.read_data[15:8]};
                    2'd2: mem_read_wb = {24'b0, mem_wb.read_data[23:16]};
                    2'd3: mem_read_wb = {24'b0, mem_wb.read_data[31:24]};
                endcase
            3'b101: // LHU: Lê halfword e preenche com zeros (unsigned)
                mem_read_wb = mem_wb.alu_result[1] ?
                    {16'b0, mem_wb.read_data[31:16]} :
                    {16'b0, mem_wb.read_data[15:0]};
            default:
                mem_read_wb = mem_wb.read_data;
        endcase
    end

    // Mux de seleção do dado de Write-Back (ALU, Memória ou endereço de retorno PC+4)
    assign wb_data = mem_wb.mem_to_reg        ? mem_read_wb :
                     (mem_wb.jal_jalr != 2'b00) ? mem_wb.pc_plus4 :
                                                  mem_wb.alu_result;

    assign wb_reg_write = mem_wb.reg_write;
    assign wb_reg_dst   = mem_wb.rd;
    assign wb_reg_data  = wb_data;

    // --- REGISTRADOR DE PIPELINE ID/EX ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || stall || pc_src) begin // Limpa (Insere bolha) em caso de Stall ou Desvio tomado
            id_ex.alu_src     <= 1'b0; id_ex.mem_to_reg  <= 1'b0; id_ex.reg_write   <= 1'b0;
            id_ex.mem_read    <= 1'b0; id_ex.mem_write   <= 1'b0; id_ex.alu_op      <= 2'b00;
            id_ex.branch_type <= 3'b000; id_ex.jal_jalr  <= 2'b00; id_ex.pc         <= 32'b0;
            id_ex.pc_plus4    <= 32'b0; id_ex.rd1        <= 32'b0; id_ex.rd2        <= 32'b0;
            id_ex.rs1         <= 5'b0;  id_ex.rs2        <= 5'b0;  id_ex.rd         <= 5'b0;
            id_ex.imm_ext     <= 32'b0; id_ex.funct3     <= 3'b0;  id_ex.funct7     <= 7'b0;
        end else begin
            id_ex.alu_src     <= ALUSrc;     id_ex.mem_to_reg  <= MemtoReg;
            id_ex.reg_write   <= RegWrite;   id_ex.mem_read    <= MemRead;
            id_ex.mem_write   <= MemWrite;   id_ex.alu_op      <= ALUOp;
            id_ex.branch_type <= BranchType; id_ex.jal_jalr    <= JalJalr;
            id_ex.pc          <= if_id.pc;   id_ex.pc_plus4    <= if_id.pc + 32'd4;
            id_ex.rd1         <= rd1;        id_ex.rd2         <= rd2;
            id_ex.rs1         <= if_id.instr[19:15];
            id_ex.rs2         <= if_id.instr[24:20];
            id_ex.rd          <= if_id.instr[11:7];
            id_ex.imm_ext     <= imm_ext;
            id_ex.funct3      <= if_id.instr[14:12];
            id_ex.funct7      <= if_id.instr[31:25];
        end
    end

    assign Funct3_EX = id_ex.funct3;
    assign Funct7_EX = id_ex.funct7;
    assign ALUOp_EX  = id_ex.alu_op;

    // =========================================================================
    // ESTÁGIO 3: EX (Execute) - Execução de Contas e Resolução de Desvios
    // =========================================================================
    
    // Unidade de Adiantamento (Forwarding Unit para resolver Hazards de dados)
    pl_forward forward (
        .id_ex_rs1        (id_ex.rs1),
        .id_ex_rs2        (id_ex.rs2),
        .ex_mem_rd        (ex_mem.rd),
        .mem_wb_rd        (mem_wb.rd),
        .ex_mem_reg_write (ex_mem.reg_write),
        .mem_wb_reg_write (mem_wb.reg_write),
        .forward_a        (fwd_a),
        .forward_b        (fwd_b)
    );

    // Muxes de adiantamento para os operandos A e B da ALU
    always_comb begin
        case (fwd_a)
            2'b10:   fwd_srca = ex_mem.alu_result;
            2'b01:   fwd_srca = wb_data;
            default: fwd_srca = id_ex.rd1;
        endcase
    end

    always_comb begin
        case (fwd_b)
            2'b10:   fwd_srcb = ex_mem.alu_result;
            2'b01:   fwd_srcb = wb_data;
            default: fwd_srcb = id_ex.rd2;
        endcase
    end

    // Mux que escolhe entre o registrador rs2 adiantado ou o valor Imediato
    assign alu_srcb = id_ex.alu_src ? id_ex.imm_ext : fwd_srcb;

    // Instância da ALU
    pl_alu alu (
        .SrcA      (fwd_srca),
        .SrcB      (alu_srcb),
        .Operation (ALU_CC),
        .ALUResult (alu_result),
        .Zero      (zero)
    );

    // LÓGICA DE AVALIAÇÃO DOS BRANCHES (Condições de Desvio)
    logic [2:0] eff_branch_type;
    assign eff_branch_type = (id_ex.branch_type == 3'b111) ? id_ex.funct3 : id_ex.branch_type;

    logic branch_taken;
    always_comb begin
        case (eff_branch_type)
            3'b000: branch_taken = zero;               // BEQ
            3'b001: branch_taken = ~zero;              // BNE
            3'b100: branch_taken = alu_result[0];      // BLT  (Resultado do SLT vira 1)
            3'b101: branch_taken = ~alu_result[0];     // BGE  (Resultado do SLT vira 0)
            3'b110: branch_taken = alu_result[0];      // BLTU (Resultado do SLTU vira 1)
            3'b111: branch_taken = ~alu_result[0];     // BGEU (Resultado do SLTU vira 0)
            default: branch_taken = 1'b0;
        endcase
    end

    // CÁLCULO DOS ALVOS DE SALTO (Targets)
    logic [31:0] jal_target, jalr_target;
    assign jal_target  = id_ex.pc + id_ex.imm_ext;
    assign jalr_target = {alu_result[31:1], 1'b0}; // Zera o LSB conforme especificação do RISC-V

    always_comb begin
        case (id_ex.jal_jalr)
            2'b01:   branch_target = jal_target;
            2'b10:   branch_target = jalr_target;
            default: branch_target = id_ex.pc + id_ex.imm_ext; // Alvo padrão de Branch
        endcase
    end

    // Controla se o PC vai desviar (Ativa se for qualquer Branch tomado OU se for JAL/JALR)
    assign pc_src = (id_ex.branch_type != 3'b000 && branch_taken) || (id_ex.jal_jalr != 2'b00);

    // --- REGISTRADOR DE PIPELINE EX/MEM ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem.mem_to_reg  <= 1'b0; ex_mem.reg_write   <= 1'b0; ex_mem.mem_read    <= 1'b0;
            ex_mem.mem_write   <= 1'b0; ex_mem.jal_jalr    <= 2'b00; ex_mem.alu_result  <= 32'b0;
            ex_mem.write_data  <= 32'b0; ex_mem.pc_plus4    <= 32'b0; ex_mem.rd          <= 5'b0;
            ex_mem.funct3      <= 3'b0;
        end else begin
            ex_mem.mem_to_reg  <= id_ex.mem_to_reg;
            ex_mem.reg_write   <= id_ex.reg_write;
            ex_mem.mem_read    <= id_ex.mem_read;
            ex_mem.mem_write   <= id_ex.mem_write;
            ex_mem.jal_jalr    <= id_ex.jal_jalr;
            ex_mem.alu_result  <= alu_result;
            ex_mem.write_data  <= fwd_srcb; // Passa o dado correto de rs2 (mesmo com forwarding) para o Store
            ex_mem.pc_plus4    <= id_ex.pc_plus4;
            ex_mem.rd          <= id_ex.rd;
            ex_mem.funct3      <= id_ex.funct3;
        end
    end

    // =========================================================================
    // ESTÁGIO 4: MEM (Memory Access) - Leitura e Escrita em Memória / IO
    // =========================================================================
    
    // Mapeamento de I/O: Se o bit 10 do endereço for 1, direciona para os periféricos (MMIO)
    assign mmio_sel = ex_mem.alu_result[10];

    // Memória de Dados Física (RAM) com suporte interno a escrita parcial (SB, SH, SW via funct3)
    pl_dmem dmem (
        .clk       (clk),
        .MemWrite  (ex_mem.mem_write & ~mmio_sel),
        .funct3    (ex_mem.funct3),
        .addr      (ex_mem.alu_result[9:0]),
        .WriteData (ex_mem.write_data),
        .ReadData  (dmem_rd)
    );

    // Unidade de MMIO (Interface com Chaves, Botões e LEDs da FPGA)
    pl_mmio mmio (
        .clk       (clk),
        .rst_n     (rst_n),
        .MemWrite  (ex_mem.mem_write &  mmio_sel),
        .MemRead   (ex_mem.mem_read  &  mmio_sel),
        .addr      (ex_mem.alu_result[4:2]),
        .WriteData (ex_mem.write_data),
        .SW        (SW),
        .KEY       (KEY),
        .ReadData  (mmio_rd),
        .LEDR      (LEDR),
        .LEDG      (LEDG),
        .UART_TXD  (UART_TXD),
        .UART_RXD  (UART_RXD)
    );

    // Mux que unifica a leitura de dados (RAM vs Periféricos)
    assign mem_read_data = mmio_sel ? mmio_rd : dmem_rd;

    // Conexão dos barramentos de monitoramento externo do testbench
    assign mem_wr_en   = ex_mem.mem_write & ~mmio_sel;
    assign mem_wr_addr = ex_mem.alu_result[9:2];
    assign mem_wr_data = ex_mem.write_data;

    // --- REGISTRADOR DE PIPELINE MEM/WB ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb.mem_to_reg <= 1'b0;  mem_wb.reg_write  <= 1'b0; mem_wb.jal_jalr   <= 2'b00;
            mem_wb.alu_result <= 32'b0; mem_wb.read_data  <= 32'b0; mem_wb.pc_plus4   <= 32'b0;
            mem_wb.rd         <= 5'b0;  mem_wb.funct3     <= 3'b0;
        end else begin
            mem_wb.mem_to_reg <= ex_mem.mem_to_reg;
            mem_wb.reg_write  <= ex_mem.reg_write;
            mem_wb.jal_jalr   <= ex_mem.jal_jalr;
            mem_wb.alu_result <= ex_mem.alu_result;
            mem_wb.read_data  <= mem_read_data;
            mem_wb.pc_plus4   <= ex_mem.pc_plus4;
            mem_wb.rd         <= ex_mem.rd;
            mem_wb.funct3     <= ex_mem.funct3;
        end
    end

    // Nota: O ESTÁGIO 5 (WB - Write Back) se conclui no início do arquivo, 
    // realimentando os sinais 'wb_data' e 'mem_wb.reg_write' diretamente no bloco 'regfile'.

endmodule