`timescale 1ns/1ps
`define FF 1

module alu
#(  parameter REG_WIDTH = 32 )  // ALU input data width is equal to the width of register file
(
    input   [REG_WIDTH-1:0] in1                 ,    // Operand 1
    input   [REG_WIDTH-1:0] in2                 ,    // Operand 2
    input   [3:0]   alu_control                 ,    // ALU control signal
    output  logic [REG_WIDTH-1:0] result        , // ALU output

    output          zero        ,   // zero_flag -> the result is 0
    output          sign            // sign_flag -> the result's sign bit is 1
);

        always_comb begin
                case (alu_control)
                        4'b0000: result = in1 & in2         ; // and
                        4'b0001: result = in1 | in2         ; // or
                        4'b0010: result = $signed(in1) + $signed(in2)         ; // add
                        4'b0011: result = in1 ^ in2         ; // xor
                        4'b0100: result = in1 << in2        ; // sll, slli, unsigned left shift
                        4'b0101: result = in1 >> in2        ; // srl, srli unsigned right shift
                        4'b0110: result = $signed(in1) >> $signed(in2)      ; // sra, srai signed shift
                        4'b0111: result = $signed(in1) - $signed(in2)         ; // sub
                        4'b1000: result = ($signed(in1) < $signed(in2)) ? 32'b1 : 32'b0;  // slt, slti signed
                        4'b1001: result = ($unsigned(in1) < $unsigned(in2)) ? 32'b1 : 32'b0;  // sltu, sltiu unsigned
                        4'b1010: result = in1 | in2         ;    // lui
                        default: result = in1 + in2         ;    // default = add
                   endcase
        end
    assign zero = ( result == 'b0 ) ? 1'b1 : 1'b0               ;
    assign sign = result[31]                                    ;


endmodule
