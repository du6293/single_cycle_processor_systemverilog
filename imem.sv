/* ********************************************
 *      
 *      Module: instruction memory (imem.sv)
 *      - 1 address input port
 *      - 32-bit 1 data output port
 *      - A single entry size is 32 bit, which is equivalent to the RISC-V instruction size
 *
 * ********************************************
 */


`timescale 1ns/1ps
`define FF 1

module imem
#(  parameter IMEM_DEPTH = 1024                         ,    // imem depth (default: 1024 entries = 4 KB)
              IMEM_ADDR_WIDTH = 10 )
(
    input   [IMEM_ADDR_WIDTH-1:0]       addr            ,    // 10 bit
    output  [31:0]                      dout
);

    logic   [31:0]  data[0:IMEM_DEPTH-1]        ;  // data array

    assign      dout = data[addr]               ;

    initial begin
        for (int i = 0; i < IMEM_DEPTH ; i++)
            data[i] = 'b0                       ;
        $readmemb("imem.mem", data)             ;
    end

endmodule
