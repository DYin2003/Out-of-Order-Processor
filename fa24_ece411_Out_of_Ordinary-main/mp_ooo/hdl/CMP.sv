module CMP 
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
    output  funct_unit_out_t cmp_out,

    output  logic            early_flush_reg,
    output  logic            early_flush_inst,
    output logic [31:0]           pc_next_reg,
    output  logic jarl_stall_release,
    output dependency_t cmp_depen,
    output logic  up,
    output cmp_to_IF cmp_in

);
    cmp_to_IF cmp_in_next;
    logic up_next;
    //Register Flush, PC_next
    logic [31:0] pc_next;
    logic early_flush;
    dependency_t cmp_depen_next;
    logic jarl_stall_release_next;

    funct_unit_out_t    internal_cmp_out_latched;
    funct_unit_out_t    internal_cmp_out;
    logic   [31:0]      b_updated;
    logic [1:0] br_jump_sel;
    assign br_jump_sel = res_station_out.ctrl_block.br_jump_sel;
    always_comb begin
        // set defaults
        jarl_stall_release_next = 1'b0;
        internal_cmp_out.pc_next = '0; // shouldn't happen
        if(res_station_out.valid == '0) begin
            internal_cmp_out.br_en = 1'b0;
            internal_cmp_out.funct_out = '0;
        end
        else
        begin
            internal_cmp_out.br_en = 1'b0;
            internal_cmp_out.funct_out = '0;
            if(br_jump_sel == branch) begin
                unique case (res_station_out.ctrl_block.funct3)
                    
                    branch_f3_beq : internal_cmp_out.br_en = (a == b);
                    branch_f3_bne : internal_cmp_out.br_en = (a != b);
                    branch_f3_blt : internal_cmp_out.br_en = (signed'(a) < signed'(b));
                    branch_f3_bge : internal_cmp_out.br_en = (signed'(a) >=  signed'(b)); // changed from ">" to ">="
                    branch_f3_bltu: internal_cmp_out.br_en = (unsigned'(a)  < unsigned'(b));
                    branch_f3_bgeu: internal_cmp_out.br_en = (unsigned'(a)  >= unsigned'(b)); // changed from ">" to ">="
                    default       : begin
                        internal_cmp_out.br_en = 1'b0;
                        internal_cmp_out.funct_out = '0;
                    end
                endcase 
                if(internal_cmp_out.br_en) begin
                        internal_cmp_out.pc_next = res_station_out.ctrl_block.imm + res_station_out.pc;
                    end
                else begin
                    internal_cmp_out.pc_next = 4 + res_station_out.pc;
                end
            end
            else if(br_jump_sel==jump) begin
                internal_cmp_out.br_en = 1'b1;
                internal_cmp_out.funct_out = 4 + res_station_out.pc;
                internal_cmp_out.pc_next = res_station_out.ctrl_block.imm + res_station_out.pc;
            end
            else if (br_jump_sel==jump_link) begin
                jarl_stall_release_next = 1'b1;  //release the stall
                internal_cmp_out.br_en = 1'b1;
                internal_cmp_out.funct_out = 4+ res_station_out.pc;
                internal_cmp_out.pc_next = (a + res_station_out.ctrl_block.imm)& 32'hfffffffe;
            end
            
            
        end
        // load in other stuff
        internal_cmp_out.pc_next_pred = res_station_out.pc_next;
        internal_cmp_out.out_valid = input_valid && (res_station_out.pc != '0);
        internal_cmp_out.rd_idx = res_station_out.rd_idx;
        internal_cmp_out.pd_idx = res_station_out.pd_idx;
        internal_cmp_out.rob_idx = res_station_out.rob_idx;
        internal_cmp_out.inst = res_station_out.inst;
        internal_cmp_out.pc = res_station_out.pc;
        // internal_cmp_out.src_1_s = res_station_out.ps1_idx;
        // internal_cmp_out.src_2_s = res_station_out.ps2_idx;
        internal_cmp_out.br_jump_sel = res_station_out.ctrl_block.br_jump_sel;
        internal_cmp_out.src_1_v = a;
        internal_cmp_out.src_2_v = b;
        internal_cmp_out.imm = res_station_out.ctrl_block.imm;
        internal_cmp_out.depen = res_station_out.depen;
        internal_cmp_out.load_queue_tail = '0;
        internal_cmp_out.store_queue_tail = '0;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            internal_cmp_out_latched <= '0;
        end else begin
            // we probably don't need this in cp2 but 
            // this could potentially be useful in cp3
            internal_cmp_out_latched <= internal_cmp_out;

        end
    end

    // check if we are using the latched value
    assign  cmp_out = internal_cmp_out;
    assign  ready = 1'b1; // should always be ready
    // assign  pc_next = //TODO::predict pc+4, so flush if taken
    assign early_flush = (early_flush_reg)? 1'b0: (internal_cmp_out.pc_next != 
                                internal_cmp_out.pc_next_pred) && res_station_out.valid; // TODO: we need to handle stalling conditions 
    assign pc_next =  internal_cmp_out.pc_next;
    assign cmp_depen_next = res_station_out.depen ;
    assign early_flush_inst = early_flush;
    assign up_next = res_station_out.valid && !early_flush_reg;

    always_comb begin
        cmp_in_next.we = br_jump_sel == branch;
        cmp_in_next.taken = internal_cmp_out.br_en && res_station_out.valid;
        cmp_in_next.pc = internal_cmp_out.pc;
    end

    always_ff@(posedge clk) begin
        if(rst) begin
            pc_next_reg <= '0;
            early_flush_reg <= '0;
            cmp_depen <= '0;
            jarl_stall_release <= '0;
            cmp_in<='0;
        end
        else begin
            pc_next_reg <= pc_next;
            early_flush_reg <= early_flush;
            cmp_depen <= cmp_depen_next;
            jarl_stall_release <= jarl_stall_release_next;
            cmp_in <= cmp_in_next;
            up <= up_next;
        end
    end 
endmodule

