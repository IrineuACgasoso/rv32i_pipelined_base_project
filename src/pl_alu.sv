// =============================================================================
// pl_alu.sv  (ESTENDIDO)
// Unidade Logica e Aritmetica de 32 bits -- RV32I pipelined
//
// Operacoes:
//   4'd01 ADD    4'd02 SUB    4'd03 XOR    4'd04 OR     4'd05 AND
//   4'd06 SLL    4'd07 SRL    4'd08 SRA    4'd11 SLT    4'd12 SLTU
// =============================================================================

`timescale 1ns / 1ps

module pl_alu (
    input  logic [31:0] SrcA,
    input  logic [31:0] SrcB,
    input  logic [3:0]  Operation,
    output logic [31:0] ALUResult,
    output logic        Zero
);

    always_comb begin
        case (Operation)
            4'd01: ALUResult = $signed(SrcA) + $signed(SrcB);
            4'd02: ALUResult = $signed(SrcA) - $signed(SrcB);
            4'd03: ALUResult = SrcA ^ SrcB;
            4'd04: ALUResult = SrcA | SrcB;
            4'd05: ALUResult = SrcA & SrcB;
            4'd06: ALUResult = SrcA << SrcB[4:0];
            4'd07: ALUResult = SrcA >> SrcB[4:0];
            4'd08: ALUResult = $signed(SrcA) >>> SrcB[4:0];
            4'd11: ALUResult = ($signed(SrcA) < $signed(SrcB)) ? 32'd1 : 32'd0;
            4'd12: ALUResult = (SrcA < SrcB) ? 32'd1 : 32'd0;   // SLTU
            default: ALUResult = 32'b0;
        endcase
    end

    assign Zero = (ALUResult == 32'b0);

endmodule