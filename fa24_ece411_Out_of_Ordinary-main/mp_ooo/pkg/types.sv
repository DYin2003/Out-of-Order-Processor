/*
    UVM package, source: Youtube, siemens UVM basic - UVM "Hello World":
    https://www.youtube.com/watch?v=jK9Olt4pyKA&list=PLWPf2kTT1_Z20pIAfQJ2gyNXLCLM1kUPB&index=2

    Why package?
    It's a way to group related items into a single thing for reuse/import
*/

package my_pkg;
`include "uvm_macros.svh"
`include "my_uvm_env.svh"
`include "my_uvm_test.svh"

import uvm_pkg::*;

endpackage: my_pkg





// original packages 
// package from mp_cache
package cache_reg;
    typedef struct packed {
        // ufp input signals
        logic   [31:0]  ufp_addr;
        logic   [3:0]   ufp_rmask;
        logic   [3:0]   ufp_wmask;
        logic   [31:0]  ufp_wdata;

    } pipeline_reg_t;

endpackage

// package from mp_verif
package rv32i_types;


    typedef enum logic [6:0] {
        op_b_lui       = 7'b0110111, // load upper immediate (U type)
        op_b_auipc     = 7'b0010111, // add upper immediate PC (U type)
        op_b_jal       = 7'b1101111, // jump and link (J type)
        op_b_jalr      = 7'b1100111, // jump and link register (I type)
        op_b_br        = 7'b1100011, // branch (B type)
        op_b_load      = 7'b0000011, // load (I type)
        op_b_store     = 7'b0100011, // store (S type)
        op_b_imm       = 7'b0010011, // arith ops with register/immediate operands (I type)
        op_b_reg       = 7'b0110011  // arith ops with register operands (R type)
    } rv32i_opcode;

    typedef enum logic [2:0] {
        arith_f3_add   = 3'b000, // check logic 30 for sub if op_reg op
        arith_f3_sll   = 3'b001,
        arith_f3_slt   = 3'b010,
        arith_f3_sltu  = 3'b011,
        arith_f3_xor   = 3'b100,
        arith_f3_sr    = 3'b101, // check logic 30 for logical/arithmetic
        arith_f3_or    = 3'b110,
        arith_f3_and   = 3'b111
    } arith_f3_t;

    typedef enum logic [2:0]{
        mul = 3'b000,
        mulh= 3'b001,
        mulhsu=3'b010,
        mulhu=3'b011
    } mul_f3_t;
    typedef enum logic [2:0]{
        div = 3'b100,
        divu= 3'b101,   
        rem=3'b110,
        remu=3'b111
    } div_f3_t;

    typedef enum logic [2:0] {
        load_f3_lb     = 3'b000,
        load_f3_lh     = 3'b001,
        load_f3_lw     = 3'b010,
        load_f3_lbu    = 3'b100,
        load_f3_lhu    = 3'b101
    } load_f3_t;

    typedef enum logic [2:0] {
        store_f3_sb    = 3'b000,
        store_f3_sh    = 3'b001,
        store_f3_sw    = 3'b010
    } store_f3_t;

    typedef enum logic [2:0] {
        branch_f3_beq  = 3'b000,
        branch_f3_bne  = 3'b001,
        branch_f3_blt  = 3'b100,
        branch_f3_bge  = 3'b101,
        branch_f3_bltu = 3'b110,
        branch_f3_bgeu = 3'b111
    } branch_f3_t;

    typedef enum logic [2:0] {
        alu_op_add     = 3'b000,
        alu_op_sll     = 3'b001,
        alu_op_sra     = 3'b010,
        alu_op_sub     = 3'b011,
        alu_op_xor     = 3'b100,
        alu_op_srl     = 3'b101,
        alu_op_or      = 3'b110,
        alu_op_and     = 3'b111
    } alu_ops;

    // somehow this file doesn't have base/variant defined.
    typedef enum logic [6:0] {
        base           = 7'b0000000,
        variant        = 7'b0100000,
        mult_div       = 7'b0000001
    } funct7_t;

    typedef union packed {
        logic [31:0] word;

        struct packed {
            logic [11:0] i_imm;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } i_type;

        struct packed {
            logic [6:0]  funct7;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } r_type;

        struct packed {
            logic [11:5] imm_s_top;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  imm_s_bot;
            rv32i_opcode opcode;
        } s_type;

        struct packed {
            logic        imm_12;
            logic [10:5] imm_10_5;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:1]  imm_4_1;
            logic        imm_11;
            rv32i_opcode opcode;
        } b_type;

        struct packed {
            logic [31:12] imm;
            logic [4:0]   rd;
            rv32i_opcode  opcode;
        } j_type;

    } instr_t;

endpackage : rv32i_types

package CDB_types;
    localparam ARB_NUM = 4;
    localparam BURST_NUMBER = 4;
    localparam BURST_SIZE = 64;
    localparam P_REG_NUM = 64;
    localparam CDB_NUM = 5;
    localparam FIFO_DEPTH = 8;
    localparam FIFO_DWIDTH = 96;
    localparam FL_DEPTH = 32;
    localparam ALU_RES_DEPTH = 4;
    localparam CMP_RES_DEPTH = 4;
    localparam MULT_RES_DEPTH = 4;
    localparam DIV_RES_DEPTH = 4;
    localparam LD_ST_RES_DEPTH = 4;
    localparam LRU_WIDTH = 3;
    localparam S_INDEX = 4;
    localparam LSQ_DEPTH = 4;
    localparam ROB_DEPTH = 32; //try 32 
    localparam VALIDARR_WIDTH = 1;
    localparam WB_CDB_NUM = 4;
    localparam div_inst_num_cyc = 11;
    localparam mult_inst_num_cyc = 3;
    localparam LOAD_QUEUE_DEPTH = 4;
    localparam STORE_QUEUE_DEPTH = 4;
    localparam EBR_NUM = 4;

typedef struct packed {

        logic               valid;
        logic   [63:0]      order;
        logic   [31:0]      inst;
        logic   [4:0]       src_1_s;
        logic   [4:0]       src_2_s;
        logic   [31:0]      src_1_v;
        logic   [31:0]      src_2_v;
        logic   [4:0]       rd_s;
        logic   [31:0]      rvfi_output;
        logic   [31:0]      pc;
        logic   [31:0]      pc_next;
        logic   [31:0]      mem_addr;
        logic   [3:0]       mem_rmask;
        logic   [3:0]       mem_wmask;
        logic   [31:0]      mem_rdata;
        logic   [31:0]      mem_wdata;
    } rvfi_val_t;

    typedef struct packed {
        logic           use_imm;
        logic           use_pc;
        logic           is_br;
        logic [1:0]     br_jump_sel;   
        logic           rd_en;
        logic   [31:0]  imm;
        logic   [2:0]   funct3;
        logic   [2:0]   func_unit;
        logic   [2:0]   alu_op;
    }   ctrl_block_t;

     typedef struct packed {
        logic [(EBR_NUM)-1:0]valid;    // if dependent on any branch
        logic  [(EBR_NUM)-1:0] [$clog2(ROB_DEPTH):0] rob_tags; //4*6 bits
        logic   [$clog2(EBR_NUM)-1:0] idx;        //2 bits index
    } dependency_t;
    
    typedef struct packed {
        logic           br_en;
        logic           we;
        logic   [$clog2(ROB_DEPTH):0]  rob_idx;
        logic   [31:0]  funct_out;
        logic   [31:0]  pc;
        logic   [31:0] pc_next;
        logic   [31:0]  inst;
        logic   [5:0]   pd;
        logic   [4:0]   rd;
        rvfi_val_t      rvfi_val;
        dependency_t    depen;

    } CDB_t;

    typedef struct packed {
        logic           valid;
        logic   [31:0]  pc;
        logic   [31:0]  inst;
        logic   [4:0]   rs1;
        logic   [4:0]   rs2;
        logic   [4:0]   rd;
        logic   [5:0]   ps1;
        logic   [5:0]   ps2;
        logic           ps1_valid;
        logic           ps2_valid;

        logic   [31:0]  pc_next;
        ctrl_block_t    ctrl_block; 
        rvfi_val_t      rvfi_val;

    } ID_RE_reg_t;

   

    typedef struct packed {
        logic           valid;
        logic           ps1_valid;
        logic   [5:0]   ps1_idx;
        logic           ps2_valid;
        logic   [5:0]   ps2_idx;
        logic   [5:0]   pd_idx;
        logic   [4:0]   rd_idx;
        logic   [$clog2(ROB_DEPTH) - 1:0]   rob_idx;
        logic   [$clog2(ROB_DEPTH) :0]   rob_tail;
        logic   [31:0]  inst;
        logic   [31:0]  pc;
        logic   [31:0]  pc_next;
        logic   [5:0]   free_list_head;
        ctrl_block_t    ctrl_block;   
        dependency_t    depen;
        logic [$clog2(LOAD_QUEUE_DEPTH):0] load_queue_tail;
        logic [$clog2(STORE_QUEUE_DEPTH):0] store_queue_tail;
    }   res_station_t;


    // have four separate pipeline reg for each functional unit
    // so that when one stalls, the others can just precede
    typedef struct packed {
        // alu unit input
        res_station_t   res_out;
        logic           res_valid;

    } IS_EX_reg_t;

    typedef enum logic[2:0] {  
        unit_alu = 3'b000,
        unit_cmp = 3'b001,
        unit_mul = 3'b010,
        unit_div = 3'b011,
        unit_ld  = 3'b100,
        unit_st  = 3'b101
    } func_unit_t;

    typedef struct packed {
        logic           out_valid;
        logic           br_en;
        logic   [1:0]   br_jump_sel;
        logic   [4:0]   rd_idx;
        logic   [5:0]   pd_idx;
        logic   [$clog2(ROB_DEPTH) -1:0]  rob_idx;
        logic   [31:0]  funct_out;
        logic   [31:0]  inst;
        logic   [31:0]  pc;
        logic   [31:0]  pc_next;    //only in CMP
        logic   [31:0]  pc_next_pred;
        // logic   [4:0]   src_1_s;
        // logic   [4:0]   src_2_s;
        logic   [31:0]  src_1_v;
        logic   [31:0]  src_2_v;
        logic   [31:0]  imm;
        dependency_t   depen;  
        logic [$clog2(STORE_QUEUE_DEPTH):0] load_queue_tail;
        logic [$clog2(STORE_QUEUE_DEPTH):0] store_queue_tail;
    }   funct_unit_out_t;
    

    typedef struct packed {
        logic   [31:0]  pc;
        logic   [31:0]  inst;
        logic   [31:0]  pc_next;
     } IF_ID_reg_t;

    typedef struct packed {
        logic   [31:0]  ufp_addr;
        logic   [3:0]   ufp_rmask;
        logic   [3:0]   ufp_wmask;
        logic   [31:0]  ufp_wdata;
    } cache_interface_t;

    typedef struct packed {
        logic               load_store; // 0 for load, 1 for store
        logic               data_valid;
        logic   [3:0]       wmask;
        logic   [3:0]       rmask;
        logic   [31:0]      addr;
        logic   [31:0]      wdata;
        logic   [31:0]      rdata;

        funct_unit_out_t    funct_out;
        dependency_t    depen;
    } lsq_entries_t;

    typedef struct packed {
        logic               valid;
        logic               ready;
        logic               data_valid;
        logic   [3:0]       rmask;
        logic   [31:0]      addr;
        logic   [31:0]      rdata;
        // counts how many stores are there ahead of the load
        logic   [$clog2(STORE_QUEUE_DEPTH):0] st_cnt;

        logic [$clog2(STORE_QUEUE_DEPTH):0] load_queue_tail;
        funct_unit_out_t    funct_out; 
        dependency_t    depen;

    } load_entries_t;

    typedef struct packed {
        logic               valid;
        logic               ready;
        logic               data_valid;
        logic   [3:0]       wmask;
        logic   [31:0]      addr;
        logic   [31:0]      wdata;

        logic [$clog2(STORE_QUEUE_DEPTH):0] store_queue_tail;
        funct_unit_out_t    funct_out;
        dependency_t    depen;
    } store_entries_t;

    //select PC
    typedef enum logic [1:0] { 
        none_br     = 2'b00,
        branch   = 2'b01,
        jump     = 2'b10,
        jump_link= 2'b11
    } br_jump_t;

    typedef struct packed {
        logic   [5:0] pd;
        logic   [4:0] rd;
        logic   [31:0] pc_next; 
        logic          br_en;   
    } ROB_t;

        typedef struct  {
        dependency_t depen;
        logic   [$clog2(P_REG_NUM)-1:0] snap_rat[32]; 
        logic   [31:0]                  snap_rat_valid;
        logic   [$clog2(FL_DEPTH):0]               free_list_head;
        logic   [$clog2(ROB_DEPTH):0] snap_rob_tail;
    }  EBR_t;

    typedef struct packed {
        logic   [31:0]  addr;
        logic   [31:0]  data;
        logic   [3:0]   mask;
    } lsq_forwarding_t;

     typedef struct packed {
        logic [$clog2(ALU_RES_DEPTH) :0] alu_res_tail;
        logic [$clog2(CMP_RES_DEPTH) :0] cmp_res_tail;
        logic [$clog2(MULT_RES_DEPTH):0] mult_res_tail;
        logic [$clog2(DIV_RES_DEPTH) :0] div_res_tail;
        logic [$clog2(LD_ST_RES_DEPTH):0] ld_st_res_tail;
     } res_tails_t;

    typedef struct packed {
       res_tails_t res_tails;
        // int unsigned alu_res_tail;
        // int unsigned cmp_res_tail;
        // int unsigned mult_res_tail;
        // int unsigned div_res_tail;
        // int unsigned  ld_st_res_tail;
        logic [$clog2(LOAD_QUEUE_DEPTH):0] load_queue_tail;
        logic [$clog2(STORE_QUEUE_DEPTH):0] store_queue_tail;
    } tails_t;

    typedef struct packed {
        logic we;
        logic taken;
        logic [31:0] pc;
        // logic [31:0] pc_target,
    }   cmp_to_IF;
    typedef enum logic [1:0] {
            ST = 2'b11, //strongly taken
            WT = 2'b10, //weakly taken
            WN = 2'b01, //weakly not taken
            SN = 2'b00 //strongly not taken
    } prediction_state;
    
endpackage

