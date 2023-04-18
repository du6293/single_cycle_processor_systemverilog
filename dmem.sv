/* ********************************************
 *
 *      Module: data memory (dmem.sv)
 *      - 1 address input port
 *      - 32-bit 1 data input and output ports
 *      - A single entry size is 64-bit
 *
 * ********************************************
 */


`timescale 1ns/1ps
`define FF 1
module dmem
#(  parameter DMEM_DEPTH = 1024,    // dmem depth (default: 1024 entries = 8 KB)
              DMEM_ADDR_WIDTH = 10 )
(
    input                               clk                             ,
    input   [DMEM_ADDR_WIDTH-1:0]       addr                            ,
    input   [31:0]                      din                             ,
    input                               mem_read                        ,
    input                               mem_write                       ,
    output  [31:0]                      dout
);


    logic   [31:0]  data[0:DMEM_DEPTH-1]                        ;


    // Write operation:
    always_ff @ (posedge clk) begin
        if (mem_write== 1'b1)
            data[addr] <= din                                   ;
    end


    // Read operation:
    // - dout = 0 if (mem_read==0)
    assign dout = (mem_read == 1'b1) ? data[addr] : 'b0         ;
  
    initial begin
        $readmemh("dmem.mem", data)                             ;
    end


endmodule
