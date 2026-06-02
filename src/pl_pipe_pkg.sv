// =============================================================================
// pl_pipe_pkg.sv (Pacote de Registradores do Pipeline - RV32I)
// Define as estruturas empacotadas (packed structs) para as barreiras de 
// registradores entre os estágios do pipeline.
// =============================================================================

package pl_pipe_pkg;

    // =========================================================================
    // 1. Estágio IF/ID (Instruction Fetch -> Instruction Decode)
    // =========================================================================
    typedef struct packed {
        logic [31:0] pc;        // Program Counter da instrução buscada
        logic [31:0] instr;     // Instrução bruta vinda da Memória de Instruções
    } if_id_t;

    // =========================================================================
    // 2. Estágio ID/EX (Instruction Decode -> Execute)
    // =========================================================================
    typedef struct packed {
        // --- Sinais de Controle ---
        logic        alu_src;
        logic        mem_to_reg;
        logic        reg_write;
        logic        mem_read;
        logic        mem_write;
        logic [1:0]  alu_op;
        logic [2:0]  branch_type; // BEQ=001, BNE=010, BLT=011, BGE=100, BLTU=101, BGEU=110
        logic [1:0]  jal_jalr;    // 00=Normal, 01=JAL, 10=JALR
        
        // --- Dados e Endereços ---
        logic [31:0] pc;          // PC da instrução atual
        logic [31:0] pc_plus4;    // PC+4 (Para salvar no registrador de link em JAL/JALR)
        logic [31:0] rd1;         // Dado lido do registrador fonte 1 (rs1)
        logic [31:0] rd2;         // Dado lido do registrador fonte 2 (rs2)
        logic [31:0] imm_ext;     // Imediato estendido (Sign-Extended)
        
        // --- Metadados da Instrução ---
        logic [4:0]  rs1;         // Endereço de rs1 (usado no Forwarding/Hazard)
        logic [4:0]  rs2;         // Endereço de rs2 (usado no Forwarding/Hazard)
        logic [4:0]  rd;          // Endereço do registrador destino
        logic [2:0]  funct3;      // Campo funct3 da instrução
        logic [6:0]  funct7;      // Campo funct7 da instrução
    } id_ex_t;

    // =========================================================================
    // 3. Estágio EX/MEM (Execute -> Memory Access)
    // =========================================================================
    typedef struct packed {
        // --- Sinais de Controle ---
        logic        mem_to_reg;
        logic        reg_write;
        logic        mem_read;
        logic        mem_write;
        logic [1:0]  jal_jalr;
        
        // --- Dados ---
        logic [31:0] alu_result;  // Resultado computado pela ALU
        logic [31:0] write_data;  // Dado a ser escrito na RAM (vindo de rs2 com Forwarding aplicado)
        logic [31:0] pc_plus4;    // PC+4 propagado para o Write-Back
        
        // --- Metadados ---
        logic [4:0]  rd;          // Endereço do registrador destino
        logic [2:0]  funct3;      // Necessário para escrita parcial na memória (SB, SH)
    } ex_mem_t;

    // =========================================================================
    // 4. Estágio MEM/WB (Memory Access -> Write-Back)
    // =========================================================================
    typedef struct packed {
        // --- Sinais de Controle ---
        logic        mem_to_reg;
        logic        reg_write;
        logic [1:0]  jal_jalr;
        
        // --- Dados ---
        logic [31:0] alu_result;  // Resultado da ALU propagado
        logic [31:0] read_data;   // Dado bruto lido da Memória de Dados
        logic [31:0] pc_plus4;    // PC+4 propagado
        
        // --- Metadados ---
        logic [4:0]  rd;          // Endereço do registrador destino
        logic [2:0]  funct3;      // Necessário para sign-extend no WB (LB, LH, LBU, LHU)
    } mem_wb_t;

endpackage