// =============================================================================
// pl_alu.sv
// Unidade Logica e Aritmetica de 32 bits -- RV32I pipelined
//
// Codificacao de operacao (Operation[3:0]):
//   4'd01 : ADD  -- adicao com sinal
//   4'd02 : SUB  -- subtracao com sinal  (BEQ usa Zero)
//   4'd03 : XOR  -- XOR bit a bit
//   4'd04 : OR   -- OU bit a bit
//   4'd05 : AND  -- E bit a bit
//   4'd06 : SLL  -- shift left logical
//   4'd07 : SRL  -- shift right logical
//   4'd08 : SRA  -- shift right arithmetic
//   4'd11 : SLT  -- set-less-than com sinal
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
            4'd01: // ADD
                ALUResult = $signed(SrcA) + $signed(SrcB);
            4'd02: // SUB
                ALUResult = $signed(SrcA) - $signed(SrcB);
            4'd03: // XOR
                ALUResult = SrcA ^ SrcB;
            4'd04: // OR
                ALUResult = SrcA | SrcB;
            4'd05: // AND
                ALUResult = SrcA & SrcB;
            4'd06: // SLL
                ALUResult = SrcA << SrcB[4:0];
            4'd07: // SRL
                ALUResult = SrcA >> SrcB[4:0];
            4'd08: // SRA
                ALUResult = $signed(SrcA) >>> SrcB[4:0];
            4'd11: // SLT (set-less-than)
                ALUResult = ($signed(SrcA) < $signed(SrcB))
                            ? 32'd1 : 32'd0;
            default:
                ALUResult = 32'b0;

        endcase
    end

    assign Zero = (ALUResult == 32'b0);

endmodule
