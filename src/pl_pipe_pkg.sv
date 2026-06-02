// =============================================================================
// pl_pipe_pkg.sv  (ESTENDIDO)
// Registradores de pipeline -- RV32I pipelined estendido
//
// =============================================================================

package pl_pipe_pkg;

    // ---- IF/ID --------------------------------------------------------------
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] instr;
    } if_id_t;

    // ---- ID/EX --------------------------------------------------------------
    typedef struct packed {
        // sinais de controle
        logic        alu_src;
        logic        mem_to_reg;
        logic        reg_write;
        logic        mem_read;
        logic        mem_write;
        logic [1:0]  alu_op;
        logic [2:0]  branch_type;   // 3 bits: BEQ=001 BNE=010 BLT=011 BGE=100 BLTU=101 BGEU=110
        logic [1:0]  jal_jalr;      // 2'b00=normal 2'b01=JAL 2'b10=JALR
        // dados
        logic [31:0] pc;
        logic [31:0] pc_plus4;      // PC+4 para escrita de link (JAL/JALR)
        logic [31:0] rd1;
        logic [31:0] rd2;
        logic [4:0]  rs1;
        logic [4:0]  rs2;
        logic [4:0]  rd;
        logic [31:0] imm_ext;
        logic [2:0]  funct3;
        logic [6:0]  funct7;
    } id_ex_t;

    // ---- EX/MEM -------------------------------------------------------------
    typedef struct packed {
        logic        mem_to_reg;
        logic        reg_write;
        logic        mem_read;
        logic        mem_write;
        logic [1:0]  jal_jalr;
        logic [31:0] alu_result;
        logic [31:0] write_data;
        logic [31:0] pc_plus4;
        logic [4:0]  rd;
        logic [2:0]  funct3;
    } ex_mem_t;

    // ---- MEM/WB -------------------------------------------------------------
    typedef struct packed {
        logic        mem_to_reg;
        logic        reg_write;
        logic [1:0]  jal_jalr;
        logic [31:0] alu_result;
        logic [31:0] read_data;
        logic [31:0] pc_plus4;
        logic [4:0]  rd;
        logic [2:0]  funct3;        // para sign-extend de LB/LH/LBU
    } mem_wb_t;

endpackage