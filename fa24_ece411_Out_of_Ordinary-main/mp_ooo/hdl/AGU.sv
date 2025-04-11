module AGU 
import CDB_types::*;
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    input   logic           input_valid,

    // input operands
    input   logic   [31:0]  a,
    input   logic   [31:0]  b,
    input   res_station_t   res_station_out,

    // outputs
    output  logic           ready,
    output  funct_unit_out_t alu_out
);
    funct_unit_out_t    internal_alu_out_latched;
    funct_unit_out_t    internal_alu_out;
    logic               use_latched, currently_occupied;
    logic   [31:0]      b_updated;
    logic                  br_en;
    // logic   [31:0]          pc;
    // assign pc  = res_station_out.pc
    always_comb begin
        // choose second operand based on ctrl_block info
        // if (res_station_out.ctrl_block.use_imm)
        //     b_updated = res_station_out.ctrl_block.imm;
        // else if (res_station_out.ctrl_block.use_pc)
        //     b_updated = res_station_out.pc;
        // else
            b_updated = b;
    end

    // do the actual calculation caculate address for BR and JAL adder and cmp and mux
    
    always_comb begin
        unique case (res_station_out.ctrl_block.funct3)
            branch_f3_beq : internal_alu_out.br_en = (a == b_updated);
            branch_f3_bne : internal_alu_out.br_en = (a != b_updated);
            branch_f3_blt : internal_alu_out.br_en = (signed'(a) < signed'(b_updated));
            branch_f3_bge : internal_alu_out.br_en = (signed'(a) >= signed'(b_updated));
            branch_f3_bltu: internal_alu_out.br_en = (unsigned'(a) < unsigned'(b_updated));
            branch_f3_bgeu: internal_alu_out.br_en = (unsigned'(a) >= unsigned'(b_updated));
            default   : internal_alu_out.br_en = '0;
        endcase
    end
    assign br_en = internal_alu_out.br_en;
    always_comb begin
        unique case (res_station_out.ctrl_block.br_jump_sel)
            
            jump:  internal_alu_out.funct_out = res_station_out.pc + res_station_out.ctrl_block.imm;
            jump_link:  internal_alu_out.funct_out = res_station_out.pc +  res_station_out.src_1_v;
            default:  begin
                    if (br_en)
                       internal_alu_out.funct_out = res_station_out.pc + res_station_out.ctrl_block.imm;
                    else    
                       internal_alu_out.funct_out = res_station_out.pc + 4;
            end 
        endcase 
    end

endmodule
