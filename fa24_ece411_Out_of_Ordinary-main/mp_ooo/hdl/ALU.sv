module ALU 
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
    logic   [31:0]      a_updated;
    logic   [31:0]      ouput;
    always_comb begin
        // choose second operand based on ctrl_block info
        // if it is a jump or an auipc, use both imm and pc
        // if((res_station_out.ctrl_block.br_jump_sel == jump))begin
           
        //     a_updated = res_station_out.pc;
        //     b_updated = res_station_out.ctrl_block.imm;
        // end
        // else if( res_station_out.ctrl_block.br_jump_sel == jump_link) begin
        //     a_updated = a;
        //     b_updated = res_station_out.ctrl_block.imm;
        // end
        // else 
        if (res_station_out.ctrl_block.use_imm &&
                res_station_out.ctrl_block.use_pc) begin
            a_updated = res_station_out.pc;
            b_updated = res_station_out.ctrl_block.imm;
                end
        else if (res_station_out.ctrl_block.use_imm) begin
            a_updated = a;
            b_updated = res_station_out.ctrl_block.imm;
        end
        else if (res_station_out.ctrl_block.use_pc) begin
            a_updated = a;
            b_updated = res_station_out.pc;
        end
        else begin
            b_updated = b;
            a_updated = a;
        end

        // do the actual calculation
        unique case (res_station_out.ctrl_block.alu_op)
            alu_op_add: ouput = a_updated +   b_updated;
            alu_op_sll: ouput = a_updated <<  b_updated[4:0];
            alu_op_sra: ouput = unsigned'(signed'(a_updated) >>> b_updated[4:0]);
            alu_op_sub: ouput = a_updated -   b_updated;
            alu_op_xor: ouput = a_updated ^   b_updated;
            alu_op_srl: ouput = a_updated >>  b_updated[4:0];
            alu_op_or : ouput = a_updated |   b_updated;
            alu_op_and: ouput = a_updated &   b_updated;
            default   : ouput = '0;
        endcase

        // check slt/sltu
        if (res_station_out.ctrl_block.funct3 == arith_f3_slt) 
            ouput = {31'd0, (signed'(a) <  signed'(b_updated))};
        if (res_station_out.ctrl_block.funct3 == arith_f3_sltu)
            ouput = {31'd0, (unsigned'(a) <  unsigned'(b_updated))};

        // select output
        if(res_station_out.ctrl_block.br_jump_sel == jump_link) begin
            internal_alu_out.funct_out = (ouput)& 32'hfffffffe;
        end
        else begin
            internal_alu_out.funct_out = (ouput);
        end
        
        // load in other stuff
        internal_alu_out.pc_next_pred = '0;
        internal_alu_out.out_valid = input_valid && (res_station_out.pc != '0);
        internal_alu_out.br_en ='0; //res_station_out.ctrl_block.br_jump_sel == jump || res_station_out.ctrl_block.br_jump_sel == jump_link;  
        internal_alu_out.rd_idx = res_station_out.rd_idx;
        internal_alu_out.pd_idx = res_station_out.pd_idx;
        internal_alu_out.rob_idx = res_station_out.rob_idx;
        internal_alu_out.inst = res_station_out.inst;
        internal_alu_out.pc = res_station_out.pc;
        // internal_alu_out.src_1_s = res_station_out.ps1_idx;
        // internal_alu_out.src_2_s = res_station_out.ps2_idx;
        internal_alu_out.br_jump_sel = res_station_out.ctrl_block.br_jump_sel;
        internal_alu_out.src_1_v = a;
        internal_alu_out.src_2_v = b;
        internal_alu_out.imm = '0;//this field only used in branch instructions // TODO no need for this entry
        internal_alu_out.depen = res_station_out.depen;
        internal_alu_out.pc_next = 0;
        internal_alu_out.load_queue_tail = '0;
        internal_alu_out.store_queue_tail = '0;

    end

    always_ff @(posedge clk) begin
        if (rst) begin
            internal_alu_out_latched <= '0;
        end else begin
            // we probably don't need this in cp2 but 
            // this could potentially be useful in cp3
            internal_alu_out_latched <= internal_alu_out;

        end
    end

    // check if we are using the latched value
    assign  alu_out = internal_alu_out;
    assign  ready = 1'b1; // should always be ready

endmodule

