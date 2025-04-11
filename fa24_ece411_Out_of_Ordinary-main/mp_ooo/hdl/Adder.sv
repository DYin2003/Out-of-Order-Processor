module ADDER
import CDB_types::*;
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    input   logic           input_valid,
    input   logic           lsq_full,
    input   logic           flush,

    // input operands
    input   logic   [31:0]  a,
    input   logic   [31:0]  b,
    input   res_station_t   res_station_out,

    input   logic  [$clog2(EBR_NUM)-1:0] recover_idx,
    input   logic  [$clog2(ROB_DEPTH):0] depen_rob,
    // outputs
    output  logic            ready,
    output  funct_unit_out_t adder_out
    
);

    funct_unit_out_t    internal_adder_out_latched;
    funct_unit_out_t    internal_adder_out;
    logic   [31:0]      b_updated;
    logic               latched_full;
    

    always_comb begin
        // second operand will always be the imm
        b_updated = res_station_out.ctrl_block.imm;

        // do the actual calculation
        adder_op_add: internal_adder_out.funct_out = a +  b_updated;

        
        // load in other stuff
        internal_adder_out.out_valid = input_valid && (res_station_out.pc != '0);
        internal_adder_out.br_en = res_station_out.ctrl_block.is_br;  
        internal_adder_out.rd_idx = res_station_out.rd_idx;
        internal_adder_out.pd_idx = res_station_out.pd_idx;
        internal_adder_out.rob_idx = res_station_out.rob_idx;
        internal_adder_out.inst = res_station_out.inst;
        internal_adder_out.pc = res_station_out.pc;
        // internal_adder_out.src_1_s = res_station_out.ps1_idx;
        // internal_adder_out.src_2_s = res_station_out.ps2_idx;
        internal_adder_out.src_1_v = a;
        internal_adder_out.src_2_v = b;

        internal_adder_out.load_queue_tail = res_station_out.load_queue_tail;
        internal_adder_out.store_queue_tail = res_station_out.store_queue_tail;
        //for lint
        internal_adder_out.pc_next_pred = '0;
        internal_adder_out.br_jump_sel = '0;
        internal_adder_out.imm = '0;
        internal_adder_out.depen = res_station_out.depen;
        internal_adder_out.pc_next = '0;

        
    end

    always_ff @(posedge clk) begin
        if (rst | flush) begin
            if(rst) begin
                internal_adder_out_latched <= '0;
                latched_full <= '0;
            end
            else if (flush) begin
                if (res_station_out.depen.rob_tags[(recover_idx)] == depen_rob && res_station_out.depen.valid[recover_idx]) begin
                    internal_adder_out_latched <= '0;
                    latched_full <= '0;
                end
            end
        end else begin
            // we probably don't need this in cp2 but 
            // this could potentially be useful in cp3
            if (lsq_full && !latched_full) begin
                if (internal_adder_out.out_valid)
                    internal_adder_out_latched <= internal_adder_out;
                else
                    internal_adder_out_latched <= '0;
                latched_full <= '1;
            end else begin
                if (!lsq_full) begin
                    internal_adder_out_latched <= '0;
                    latched_full <= '0;
                end
            end

        end
    end

    // check if we are using the latched vaddere
    assign  adder_out = internal_adder_out; // (latched_full)? internal_adder_out_latched: 
    assign  ready = 1'b1; // !lsq_full // ready to take in another input when lsq is not full

endmodule

