/********************************************
*
*Module: top design of the single-cycle CPU (single_cycle_cpu.sv)
*- Top design of the single-cycle CPU
*
********************************************/

`timescale 1ns/1ps
`define FF 1
module single_cycle_cpu
#(  parameter   IMEM_DEPTH      = 1024  ,           // imem depth (default: 1024 entries = 4 KB)
                IMEM_ADDR_WIDTH = 10    ,
                REG_WIDTH       = 32    ,
                DMEM_DEPTH      = 1024  ,           // dmem depth (default: 1024 entries = 8 KB)
                DMEM_ADDR_WIDTH = 10 )
(
    input           clk                 ,          // System clock
    input           reset_b                         // Asychronous negative reset
);

    // Wires for datapath elements
    // 1. imem
    logic          [IMEM_ADDR_WIDTH-1:0]        imem_addr               ;
    logic          [31:0]                       inst                    ;   // instructions = an output of imem
    // 2. regfile
    logic           [4:0]                       rs1, rs2, rd            ;    // register numbers
    logic           [REG_WIDTH-1:0]             rd_din                  ;
    logic                                       reg_write               ;
    logic           [REG_WIDTH-1:0]             rs1_dout, rs2_dout      ;
    // 3. alu
    logic           [REG_WIDTH-1:0]             alu_in1, alu_in2        ;
    logic           [3:0]                       alu_control             ;    // ALU control signal
    logic           [REG_WIDTH-1:0]             alu_result              ;
    logic                                       alu_zero                ;
    logic                                       alu_sign                ;
    // 4. dmem
    logic           [DMEM_ADDR_WIDTH-1:0]       dmem_addr               ;
    logic           [31:0]                      dmem_din, dmem_dout     ;
    logic                                       mem_read, mem_write     ;
    
    /* Main control unit */
    logic           [6:0]                       opcode                  ;
    logic           [5:0]                       branch                  ;
    logic                                       alu_src, mem_to_reg     ;
    logic           [1:0]                       alu_op                  ;

    logic           [2:0]                       funct3                  ;
    logic           [6:0]                       funct7                  ;
  
    assign              opcode = inst[6:0]                              ; 
    assign              branch[0] = ( opcode == 7'b1100011 && funct3 == 3'b000 ) ? 1'b1 : 1'b0          ;       // BEQ
    assign              branch[1] = ( opcode == 7'b1100011 && funct3 == 3'b001 ) ? 1'b1 : 1'b0          ;       // BNE
    assign              branch[2] = ( opcode == 7'b1100011 && funct3 == 3'b100 ) ? 1'b1 : 1'b0          ;       // BLT
    assign              branch[3] = ( opcode == 7'b1100011 && funct3 == 3'b101 ) ? 1'b1 : 1'b0          ;       // BGE
    assign              branch[4] = ( opcode == 7'b1100011 && funct3 == 3'b110 ) ? 1'b1 : 1'b0          ;       // BLTU
    assign              branch[5] = ( opcode == 7'b1100011 && funct3 == 3'b111 ) ? 1'b1 : 1'b0          ;       // BGEU

    /*main control unit*/
    assign              mem_read   = ( opcode == 7'b0000011 )  ? 1'b1 : 1'b0                    ;    // load
    assign              mem_write  = ( opcode == 7'b0100011 )  ? 1'b1 : 1'b0                    ;    // store
    assign              mem_to_reg = ( opcode == 7'b0000011 )  ? 1'b1 : 1'b0                    ;    // load
   
    assign              reg_write  = ( opcode == 7'b0000011 || opcode == 7'b0110011 || opcode == 7'b0010011|| opcode == 7'b1100011||opcode==7'b1100111||opcode==7'b1100111||opcode==7'b01    10111||opcode==7'b0010111) ? 1: 0;
    assign              alu_src = (opcode == 7'b0000011||opcode==7'b0100011||opcode==7'b0010011||opcode==7'b1100111||opcode==7'b1101111||opcode==7'b0110111||opcode==7'b0010111) ? 1:0;
    assign              funct3 = (opcode == 7'b0110111 || opcode == 7'b0010111) ? 3'b0 : inst[14:12]        ;
    assign              funct7 = (opcode == 7'b0110011) ? inst[31:25] : 7'b0                                ;

    /* alu operation */
    always_comb begin
        if      (opcode == 7'b0000011 || opcode == 7'b0100011) alu_op = 2'b00         ;   // load, store
        else if (opcode == 7'b1100011)                         alu_op = 2'b01         ;   // sb-type
        else if (opcode == 7'b0110011)                         alu_op = 2'b10         ;   // r-type
        else if (opcode == 7'b0010011)                         alu_op = 2'b10         ;   // i-type
        else if (opcode == 7'b0110111)                         alu_op = 2'b11         ;   // lui
        else                                                   alu_op = 2'b00         ;   // auipc,jal,jalr
    end

    /* alu control */
    always_comb begin
        if      (alu_op == 2'b00)       alu_control = 4'b0010 ;             // lw, sw ADD, jal,jalr, auipc
        else if (alu_op == 2'b01)       alu_control = 4'b0111 ;             // sb-type SUB
        else if (alu_op == 2'b11)       alu_control = 4'b1010 ;             // lui
        else if (alu_op == 2'b10) begin   // r-type, i-type
                if      (funct3 == 3'b001)                          alu_control = 4'b0100     ; // sll, slii
                else if (funct3 == 3'b101 && funct7 == 7'b0000000)  alu_control = 4'b0101     ; // srl, srli
                else if (funct3 == 3'b101 && funct7 == 7'b0100000)  alu_control = 4'b0110     ; // sra, srai
                else if (funct3 == 3'b000) begin
                        if (funct7 == 7'b0100000) alu_control = 4'b0111 ;   // sub
                        else alu_control = 4'b0010                      ;   // add, addi
                end
                else if (funct3 == 3'b100) alu_control = 4'b0011        ; //xor, xori
                else if (funct3 == 3'b110) alu_control = 4'b0001        ; //or, ori
                else if (funct3 == 3'b111) alu_control = 4'b0000        ; //and, andi
                else if (funct3 == 3'b010) alu_control = 4'b1000        ; //slt, slti
                else if (funct3 == 3'b011) alu_control = 4'b1001        ; //sltu, sltiu
                else                       alu_control = 4'b0100        ;
        end
    end
    
    
    logic       [REG_WIDTH-1:0]         imm32                           ;  // 32 bit
    logic       [REG_WIDTH-1:0]         imm32_branch                    ;  // imm32 left shifted by 1
    logic       [11:0]                  imm12                           ;  // 12-bit immediate value extracted from inst
    logic       [19:0]                  imm20                           ;  // 20-bit immediate value extracted from inst
  
    /* immediate generator */
    always_comb begin
                if (opcode == 7'b0000011)      imm12[11:0] = inst[31:20]                        ; //load, 12 bit
                else if (opcode == 7'b1100111|| opcode == 7'b0010011) imm12[11:0] = inst[31:20] ; // i-type, JALR
                else if (opcode == 7'b0100011) begin  // store, 12 bit
                        imm12[11:5] = inst[31:25]                               ;
                        imm12[4:0]  = inst[11:7]                                ;
                end
                else if (opcode == 7'b1100011) begin // sb-type
                        imm12[10] = inst[7]                             ;
                        imm12[3:0] = inst[11:8]                         ;
                        imm12[9:4] = inst[30:25]                        ;
                        imm12[11] = inst[31]                            ;
                end
                else if (opcode == 7'b1101111) begin // uj-type, 20bit, JAL
                        imm20[19] = inst[31]                            ;
                        imm20[9:0] =inst[30:21]                         ;
                        imm20[10] = inst[20]                            ;
                        imm20[18:11] = inst[19:12]                      ;
                end
                else if (opcode == 7'b0110111) // u-type, 20bit, LUI
                        imm20 = inst[31:12]                             ;
                else if (opcode == 7'b0010111)  // u-type, 20bit, AUIPC
                        imm20 = inst[31:12]                             ;
                else    imm12 = 12'b0                                   ;
     end

    /* immediate extension*/
    always_comb begin
             if ( opcode == 7'b0000011 )    imm32 = {{20{imm12[11]}},imm12}         ; // load
             else if (opcode == 7'b0100011) imm32 = {{20{imm12[11]}},imm12}         ; // store
             else if (opcode == 7'b0010011) begin    // i-type
                     if (funct3 == 3'b011) imm32 = {{20{1'b0}},imm12}               ; // sltiu
                     else                  imm32 = {{20{imm12[11]}},imm12}          ;
             end
             else if (opcode == 7'b1100011) begin   // sb-type
                     if (funct3 == 3'b110 || funct3 == 3'b111) imm32 = {{20{1'b0}},imm12}       ; // bltu, bgeu
                     else                  imm32 = {{20{imm12[11]}},imm12}                      ;
             end
             else if (opcode == 7'b1101111) imm32 = {{12{imm20[19]}},imm20}     ; // jal, uj-type
             else if (opcode == 7'b1100111) imm32 = {{20{imm12[11]}},imm12}     ; // jalr, i-type
             else if (opcode == 7'b0110111) imm32 = {imm20,12'b0}               ; // lui
             else if (opcode == 7'b0010111) imm32 = {imm20,12'b0}               ; // auipc
             else                           imm32 = 32'b0                       ;
    end

    assign              imm32_branch = (imm32 << 1)                     ; // beq, jal
    // Program counter
    logic       [31:0]          pc_curr, pc_next                        ;
    logic                       pc_next_sel                             ;    // selection signal for pc_next
    logic       [31:0]          pc_next_plus4, pc_next_branch           ;

  
    assign      pc_next_plus4 = pc_curr + 'b100                         ;    // pc_curr <- pc_curr + 4

    /* program counter */
    always_ff @ (posedge clk or negedge reset_b) begin
        if (~reset_b) begin
            pc_curr <= 'b0              ;
        end else begin
            pc_curr <= pc_next          ;        // pc_curr <- pc_next + 4
        end
    end
  
    /* calculate in alu and decide to branch or not to branch */
    always_comb begin
                if      (branch[0] == 1'b1 && alu_zero == 1'b1)                     pc_next_sel = 1'b1  ; // BEQ
                else if (branch[1] == 1'b1 && alu_zero == 1'b0)                     pc_next_sel = 1'b1  ; // BNE
                else if (branch[2] == 1'b1 && alu_sign == 1'b1 && alu_zero == 1'b0) pc_next_sel = 1'b1  ; // BLT
                else if (branch[3] == 1'b1 && alu_sign == 1'b0)                     pc_next_sel = 1'b1  ; // BGE
                else if (branch[4] == 1'b1 && alu_zero == 1'b0 && alu_sign == 1'b1) pc_next_sel = 1'b1  ; // BLTU (unsigned)
                else if (branch[5] == 1'b1 && alu_sign == 1'b0)                     pc_next_sel = 1'b1  ; // BGEU (unsgined)
                else if (opcode == 7'b1101111 || (opcode == 7'b1100111))            pc_next_sel = 1'b1  ; // jal, jalr
                else                                                                pc_next_sel = 1'b0  ; // don't jump
      end

    always_comb begin
                 if (pc_next_sel == 1'b1) begin
                        if (opcode == 7'b1100111)      pc_next_branch = alu_result                      ; // jalr
                        else if (opcode == 7'b1101111) pc_next_branch = pc_curr + imm32_branch          ; // jal
                        else if (opcode == 7'b1100011) pc_next_branch = pc_curr + imm32_branch          ; // sb-type
                 end
    end

    assign       pc_next = (pc_next_sel) ? pc_next_branch : pc_next_plus4                               ; // if branch is taken, pc_next_sel == 1'b1
  
    assign  alu_in1 = (opcode == 7'b0010111 || opcode == 7'b1101111) ? pc_curr : (opcode == 7'b0110111) ? 32'b0 : rs1_dout  ;
    assign  alu_in2 = (alu_src == 1'b0) ? rs2_dout : (alu_src == 1'b1 && opcode != 7'b0010111) ? imm32 : ( imm32 << 1)      ;
  
    /* write data */
    always_comb begin
            if (mem_to_reg == 1'b1) begin
                if (funct3 ==3'b000 )           rd_din = {{24{dmem_dout[7]}},dmem_dout[7:0]}            ;  // LB
                else if (funct3 == 3'b001)      rd_din = {{16{dmem_dout[15]}},dmem_dout[15:0]}          ;  // LH
                else if (funct3 == 3'b010 )     rd_din = dmem_dout                                      ;  // LW
                else if (funct3 == 3'b100)      rd_din = {24'b0, dmem_dout[7:0]}                        ;  // LBU (unsigned)
                else if (funct3 == 3'b101)      rd_din = {16'b0, dmem_dout[15:0]}                       ;  // LHU (unsigned)
            end

            else if (mem_to_reg == 1'b0) begin
                if (opcode == 7'b0010011)       rd_din = alu_result     ;// i-type

                else if (opcode == 7'b0110011)  rd_din = alu_result     ;// r-type
                 else if (opcode == 7'b1100011)                         rd_din = pc_next_plus4                  ;  // sb-type
                 else if (opcode == 7'b1101111 || opcode == 7'b1100111) rd_din = pc_next_plus4                  ;  // JAL,i-type JALR rd -> pc+4
                 else if (opcode == 7'b0110111)                         rd_din = alu_result                     ;  // LUI
                 else if (opcode == 7'b0010111)                         rd_din = alu_result                     ;  // AUIPC
         end

    end

    assign      imem_addr = pc_curr[11:2]       ;
    assign      rs1 = (opcode == 7'b0000011 || opcode == 7'b0110011 || opcode == 7'b0010011 || opcode == 7'b0100011 || opcode == 7'b1100011 || opcode == 7'b1100111|| opcode == 7'b1100111) ? inst[19:15] : 5'b0     ; // lo    ad, store, r-type, i-type, sb-type, jalr
    assign      rs2 = (opcode == 7'b0100011 || opcode == 7'b0110011 || opcode == 7'b1100011) ? inst[24:20] : 5'b0    ; // store, r-type, sb-type
    assign      rd  = (opcode == 7'b0000011 || opcode == 7'b0110011 || opcode == 7'b0010011 || opcode == 7'b0110111 || opcode ==  7'b0010111 || opcode ==  7'b1100111 || opcode == 7'b1101111) ? inst[11:7] : 5'b0   ;
    assign      dmem_addr =     alu_result[11:2]        ;
    
    /* store data to dmem */
    always_comb begin
        if (mem_write == 1'b1) begin
                if (funct3 == 3'b000 )                  dmem_din = {24'b0,rs2_dout[7:0]}                ; // SB
                else if (funct3 == 3'b001)              dmem_din = {16'b0, rs2_dout[15:0]}              ; // SH
                else if (funct3 == 3'b010 )             dmem_din = rs2_dout                             ; // SW
        end
    end
  
    // IMEM
    imem #(
        .IMEM_DEPTH         (IMEM_DEPTH)                ,
        .IMEM_ADDR_WIDTH    (IMEM_ADDR_WIDTH)
    ) u_imem_0 (
        .addr               ( imem_addr )               ,
        .dout               (  inst   )
    );

    // REGFILE
    regfile #(
        .REG_WIDTH              (REG_WIDTH)
    ) u_regfile_0 (

        .clk                    (clk)                   ,
        .rs1                    (rs1)                   ,
        .rs2                    (rs2)                   ,
        .rd                     (rd)                    ,
        .rd_din                 (rd_din)                ,
        .rs1_dout               (rs1_dout)              ,
        .rs2_dout               (rs2_dout)              ,
        .reg_write              (reg_write)
   );
    // ALU
    alu #(
        .REG_WIDTH              (REG_WIDTH)
    ) u_alu_0 (
        .in1                    (alu_in1)               ,
        .in2                    (alu_in2)               ,
        .alu_control            (alu_control)           ,
        .result                 (alu_result)            ,
        .zero                   (alu_zero)              ,
        .sign                   (alu_sign)
    );
  
   // DMEM

   dmem #(
        .DMEM_DEPTH             (DMEM_DEPTH)            ,
        .DMEM_ADDR_WIDTH        (DMEM_ADDR_WIDTH)
) u_dmem_0 (
        .clk                    (clk)                   ,
        .addr                   (dmem_addr)             ,
        .din                    (dmem_din)              ,
        .mem_write              (mem_write)             ,
        .mem_read               (mem_read)              ,
        .dout                   (dmem_dout)
);

endmodule

  
