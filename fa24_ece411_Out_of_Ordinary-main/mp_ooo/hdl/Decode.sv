module Decode 
import CDB_types::*;
import rv32i_types::*;
#(
    // parameter P_REG_NUM = 64
)
(
    input   IF_ID_reg_t         IF_ID_reg,
    input   logic               clk,
    input   logic               rst,
    // input   logic   [31:0]      pc,
    // input   logic   [31:0]      inst,
    //output to RAT 
    output  logic   [4:0]       rat_rs1,
    output  logic   [4:0]       rat_rs2,
    //output to freelist
    input  logic               free_list_empty,
    output  logic               free_list_deq,
    //stall
    // input    logic           ps1_valid,
    // input    logic           ps2_valid,
    // input    logic   [$clog2(P_REG_NUM) -1 :0]   ps1,
    // input    logic   [$clog2(P_REG_NUM) -1 :0]   ps2,
    // input   logic   rob_full,

    input   logic              RE_stall,
    output logic                DE_stall,
    output logic                jalr_stall,
    input    logic            flush,
    
    output ID_RE_reg_t          ID_RE_reg
    
);
/*
    Rename Source Register
    Decode Instruction
*/
    //disable (set to zero) rs1,rs2 when not needed
    logic rs1_en,rs2_en, rd_en, use_imm, use_pc, is_br;
    logic [1:0] br_jump_sel;
    logic funct3_en;//jal
    ID_RE_reg_t ID_RE_reg_next, ID_RE_reg_internal;
    logic[2:0] func_unit;
    logic [31:0] imm;
    logic   [31:0]  inst;  
    logic   [31:0]  pc;
    assign  pc = IF_ID_reg.pc;
    assign  inst = IF_ID_reg.inst;

    logic   [2:0]   funct3;
    logic   [6:0]   funct7;
    
    logic   [6:0]   opcode;
    logic   [31:0]  i_imm;
    logic   [31:0]  s_imm;
    logic   [31:0]  b_imm;
    logic   [31:0]  u_imm;
    logic   [31:0]  j_imm;
    logic   [2:0]   alu_op;
    
    logic   [4:0]   rd_s;
    logic   [4:0]   rs1_s,rs2_s;
    logic           RE_stall_latched;
    // logic   [3:0]   wmask, rmask;
    assign funct3 = funct3_en ?  inst[14:12] : '0;
    assign funct7 = inst[31:25];
    assign opcode = inst[6:0];
    assign i_imm  = {{21{inst[31]}}, inst[30:20]};
    assign s_imm  = {{21{inst[31]}}, inst[30:25], inst[11:7]};
    assign b_imm  = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    assign u_imm  = {inst[31:12], 12'h000};
    assign j_imm  = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
    assign rs1_s  = rs1_en ? inst[19:15] :'0;
    assign rs2_s  = rs2_en ? inst[24:20] :'0;
    assign rd_s   = rd_en  ? inst[11:7]  :'0;

    always_comb begin
        ID_RE_reg_next.valid = IF_ID_reg != '0;
        ID_RE_reg_next.pc_next = IF_ID_reg.pc_next;
        ID_RE_reg_next.pc = pc;
        ID_RE_reg_next.inst = inst;
        ID_RE_reg_next.rd   =rd_s;
        ID_RE_reg_next.ctrl_block.use_imm = use_imm;
        ID_RE_reg_next.ctrl_block.use_pc  = use_pc;
        ID_RE_reg_next.ctrl_block.imm =  imm;
        ID_RE_reg_next.ctrl_block.funct3 = funct3;
        ID_RE_reg_next.ctrl_block.func_unit=func_unit;
        ID_RE_reg_next.ctrl_block.is_br = is_br;
        ID_RE_reg_next.ctrl_block.br_jump_sel = br_jump_sel;
        ID_RE_reg_next.ctrl_block.rd_en = rd_en;
        ID_RE_reg_next.ctrl_block.alu_op = alu_op;
        ID_RE_reg_next.rs1 = rs1_s;
        ID_RE_reg_next.rs2 = rs2_s;

        //for lint
        ID_RE_reg_next.ps1 = '0;
        ID_RE_reg_next.ps2 = '0;
        ID_RE_reg_next.ps1_valid = '0;
        ID_RE_reg_next.ps2_valid = '0;
        // ID_RE_reg_next.wmask = wmask;
        // ID_RE_reg_next.rmask = rmask;

        ID_RE_reg_next.rvfi_val = '0;
        ID_RE_reg_next.rvfi_val.pc = pc;
        ID_RE_reg_next.rvfi_val.inst = inst;
        ID_RE_reg_next.rvfi_val.src_1_s=rs1_s;
        ID_RE_reg_next.rvfi_val.src_2_s=rs2_s;
        ID_RE_reg_next.rvfi_val.rd_s = rd_s;
        
    
    end     

    //mux for alu_ops
    always_comb begin
        jalr_stall = (opcode == op_b_jalr);
        alu_op = funct3;
         case(funct3)
            arith_f3_add: begin
                if(funct7 == 7'b0000000)
                    alu_op = alu_op_add;
                else
                    alu_op = alu_op_sub;
                // alu_op = alu_op_add;
            end
            arith_f3_sll: alu_op = alu_op_sll;
            // arith_f3_sra: alu_op = alu_op_sra;

            // arith_f3_sub: alu_op = alu_op_sub;
            arith_f3_xor: alu_op = alu_op_xor;
            arith_f3_sr: begin 
                if(funct7 == 7'b0000000)
                    alu_op = alu_op_srl;
                else
                    alu_op = alu_op_sra;
            end
            arith_f3_or: alu_op = alu_op_or;
            arith_f3_and: alu_op = alu_op_and;
            default: alu_op = alu_op_add;
         endcase
        if((opcode == op_b_jal) || (opcode ==op_b_jalr) ) begin
            alu_op = alu_op_add;
        end
        


        //! add jalr and jal later
        if (opcode == op_b_lui || opcode == op_b_auipc)
            alu_op = alu_op_add;
        if (opcode == op_b_imm) begin
            if (funct3 == '0)
                alu_op = alu_op_add;
            if (funct3 == '1)
                alu_op = alu_op_and;
        end
    end

    always_comb begin
        use_pc = '0;
        unique case(opcode)
            op_b_auipc,op_b_br,op_b_jal:
                use_pc = '1;
            default:
                use_pc = '0;
        endcase 
    end

//mux for imm
    always_comb begin
        use_imm = '0;
        imm = '0;
        unique case(opcode)
            //S-type
            op_b_store:begin
                imm = s_imm;
                use_imm = '1;
            end
            // I-type
            
            op_b_jalr,op_b_load, op_b_imm:begin
                imm = i_imm;
                use_imm = '1;
            end
            //B-type
            op_b_br:begin
                imm= b_imm;
                use_imm = '1; 
            end
            //U-type
            op_b_lui,op_b_auipc: begin
                imm = u_imm;
                use_imm = '1;
            end
            //J-type
            op_b_jal:begin
                imm = j_imm;
                use_imm = '1;

            end 
            default: begin
                imm = '0;
                use_imm = '0;
            end
        endcase

    end

    // mux
    
    always_comb begin
        // Default: no registers needed
        rs1_en = 1'b0;
        rs2_en = 1'b0;
        rd_en = 1'b0;
        case (opcode)
            op_b_lui, op_b_auipc, op_b_jal:
                begin
                    
                    rd_en = 1'b1;
                end
            op_b_jalr, op_b_load, op_b_imm: 
                begin
                    rs1_en = 1'b1;
                    rd_en = 1'b1;
                end
            op_b_br, op_b_store:
                begin
                    rs1_en = 1'b1;
                    rs2_en = 1'b1;
                end
            op_b_reg:  
                begin
                    rs1_en = 1'b1;
                    rs2_en = 1'b1;
                    rd_en = 1'b1;
                end
            default: begin
                rs1_en = 1'b0;
                rs2_en = 1'b0;
                rd_en = 1'b0;
            end
        endcase
    end
    
    // Mux for function unit
    always_comb begin
        func_unit = unit_alu;
        unique case(opcode)
            op_b_reg:begin
                case(funct7[0]) 
                    1'b0: begin
                        // case(funct3)
                        //     arith_f3_slt,arith_f3_sltu:
                        //         func_unit = unit_cmp;
                        //     default:
                        //         func_unit = unit_alu; 
                        // endcase
                        func_unit = unit_alu;
                    end
                    1'b1:begin
                        case(funct3[2])
                            1'b0: func_unit = unit_mul;
                            1'b1: func_unit = unit_div;
                        endcase 
                    end
                            
                endcase
            end
            op_b_imm:begin
                // case(funct3)
                    // arith_f3_slt,arith_f3_sltu:
                        // func_unit = unit_cmp;
                    // default:
                        func_unit = unit_alu; 
                // endcase
            end 
            op_b_auipc,op_b_lui:
                func_unit = unit_alu;
            op_b_jalr,op_b_jal:
                func_unit = unit_cmp;   //new, ebr need jumps to cmp
            op_b_br:
                func_unit = unit_cmp;
            op_b_load:
                func_unit = unit_ld;
            op_b_store:
                func_unit = unit_st;
        default:
            func_unit = unit_alu;
        endcase 
    
    end
    //is branch/Jump
    always_comb begin
        br_jump_sel =  none_br;
        is_br = '0;
        unique case(opcode)
            op_b_br: begin
                is_br = '1;
                br_jump_sel = branch;
            end
            op_b_jal: begin
                is_br = '1;
                br_jump_sel = jump;
            end
            op_b_jalr: begin
                is_br = '1;
                br_jump_sel = jump_link;
            end
            default: begin
                br_jump_sel =  none_br;
                is_br = '0;
            end
        endcase 
    end

    always_comb begin
        unique case(opcode)
            op_b_auipc,op_b_lui,op_b_jal,op_b_jalr:
                funct3_en = '0;
            default:
                funct3_en = '1;
        endcase

    end

    // set wmask and rmask (before shifting based on address)
    // always_comb begin
    //     unique case(opcode)
    //         op_b_store: begin
    //             rmask = 4'b0000;
    //             case (funct3)
    //                 arith_f3_sb:    wmask = 4'b0001;
    //                 arith_f3_sh:    wmask = 4'b0011;
    //                 arith_f3_sw:    wmask = 4'b1111;
    //                 default:        wmask = 4'b0000;
    //             endcase
    //         end

    //         op_b_load:
    //             wmask = 4'b0000;
    //             case (funct3)
    //                 load_f3_lb:     rmask = 4'b0001;
    //                 load_f3_lh:     rmask = 4'b0011;
    //                 load_f3_lw:     rmask = 4'b1111;
    //                 load_f3_lbu:    rmask = 4'b0001;
    //                 load_f3_lhu:    rmask = 4'b0011;
    //                 default:        rmask = 4'b0000;
    //             endcase

    //         default:
    //             wmask = 4'b0000;
    //             rmask = 4'b0000;
    //     endcase
    // end

    // Free List FIFO, RAT
    always_comb begin
        rat_rs1 = DE_stall||RE_stall? ID_RE_reg_internal.rs1 : rs1_s;
        rat_rs2 = DE_stall||RE_stall? ID_RE_reg_internal.rs2 : rs2_s;
    end
    //only dequeue when 
    always_comb begin
        free_list_deq = (rd_s != '0) && !free_list_empty && !RE_stall  && !DE_stall;    //TODO stop deque when stalled
    end

    logic   DE_stall_latched;
    //populate stage register
    always_ff@(posedge clk) begin
        if(rst || flush ) begin
            ID_RE_reg_internal <= '0;
            RE_stall_latched <= '0;
        end
        else if(RE_stall || DE_stall) begin
            
            ID_RE_reg_internal <= ID_RE_reg_internal;
            
            // if(!DE_stall) ID_RE_reg_internal.valid <= '1;
        end
        else begin
            ID_RE_reg_internal <= ID_RE_reg_next;
        end
        RE_stall_latched <= RE_stall;
        DE_stall_latched <= DE_stall;
    end 

    always_comb begin
        ID_RE_reg = ID_RE_reg_internal;
        if (DE_stall)
            ID_RE_reg.valid = 1'b0;
        else
            ID_RE_reg.valid = ID_RE_reg_internal.valid;
    end

    assign DE_stall = free_list_empty && (rd_s != '0);
    
endmodule

