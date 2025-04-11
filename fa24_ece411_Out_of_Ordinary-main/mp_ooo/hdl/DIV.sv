module DIV 
import CDB_types::*;
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    input   logic           input_valid,
    input   logic           flush,

    // input operands
    input   logic   [31:0]  a,
    input   logic   [31:0]  b,
    input   res_station_t   res_station_out,

    input   logic  [$clog2(EBR_NUM)-1:0] recover_idx,
    input   logic  [$clog2(ROB_DEPTH):0] depen_rob,
    // outputs
    output  logic           ready,
    output  funct_unit_out_t div_out

);     
    // sequential diviplier module, stuff below directly from datasheet
    parameter inst_a_width = 33;
    parameter inst_b_width = 33;
    parameter inst_tc_mode_s = 1; //TODO do we use both singed and unsinged?
    // parameter inst_tc_mode_u = 0; 
    // parameter inst_num_cyc = 3; 
    parameter inst_rst_mode = 1;
    parameter inst_input_mode = 1;
    parameter inst_output_mode = 1;
    parameter inst_early_start = 0;

    
    logic  [32:0]       inst_a, inst_b;                 // 33 bits to fix the signedness problem
    logic  [32:0]       quotient_inst, remainder_inst;
    logic               divide_by_0_inst;
    logic               hold, inst_hold;
    logic               start, inst_start;
    logic               complete, inst_complete;           
    funct_unit_out_t    internal_div_out_latched;
    funct_unit_out_t    internal_div_out;
    logic               inst_start_latched;
    logic               flush_latched;

    //* got rid of this by using the 33 bit method
    // logic  [32:0]       quotient_inst_u, remainder_inst_u;
    // logic               divide_by_0_inst_u;
    // logic              inst_complete_u;

    DW_div_seq #(inst_a_width, inst_b_width, inst_tc_mode_s, div_inst_num_cyc,
    inst_rst_mode, inst_input_mode, inst_output_mode,
    inst_early_start)
    Div_unit_signed (.clk(clk),
    .rst_n(~rst),
    .hold(inst_hold),
    .start(inst_start),
    .a(inst_a),
    .b(inst_b),
    .complete(inst_complete),
    .divide_by_0(divide_by_0_inst),
    .quotient(quotient_inst),
    .remainder(remainder_inst) );


    //* got rid of this by using the 33 bit method
    //  DW_div_seq #(inst_a_width, inst_b_width, inst_tc_mode_u, inst_num_cyc,
    // inst_rst_mode, inst_input_mode, inst_output_mode,
    // inst_early_start)
    // Div_unit_u (.clk(clk),
    // .rst_n(~rst),
    // .hold(inst_hold),
    // .start(inst_start),
    // .a(inst_a),
    // .b(inst_b),
    // .complete(inst_complete_u),
    // .divide_by_0(divide_by_0_inst_u),
    // .quotient(quotient_inst_u),
    // .remainder(remainder_inst_u) );
    
        
    assign inst_hold = '0;//TODO we probably don't need a hold

    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);
    always_comb begin
        case (res_station_out.ctrl_block.funct3)
                div,rem:begin
                    inst_a = {as[31], as}; 
                    inst_b = {bs[31], bs}; 
                end
                divu,remu:begin     // u * u rs1,rs2
                    inst_a = {1'b0, au};
                    inst_b = {1'b0, bu};
                end
                default:begin
                    inst_a = {as[31], as}; 
                    inst_b = {bs[31], bs}; 
                end
        endcase 
    end
    
    
    
    always_comb begin
        if(input_valid) begin
            inst_start = '1;
        end
        else begin
            inst_start = '0;
        end 
    end


    always_comb begin
        // b_updated = b;
        internal_div_out.pc_next_pred = '0;
        internal_div_out.out_valid = inst_start_latched && inst_complete;
        internal_div_out.br_en = res_station_out.ctrl_block.is_br;  
        internal_div_out.rd_idx = res_station_out.rd_idx;
        internal_div_out.pd_idx = res_station_out.pd_idx;
        internal_div_out.rob_idx = res_station_out.rob_idx;
        internal_div_out.inst = res_station_out.inst;
        internal_div_out.pc = res_station_out.pc;
        // internal_div_out.src_1_s = res_station_out.ps1_idx;
        // internal_div_out.src_2_s = res_station_out.ps2_idx;
        internal_div_out.br_jump_sel = res_station_out.ctrl_block.br_jump_sel;
        internal_div_out.src_1_v = a;
        internal_div_out.src_2_v = b;
        internal_div_out.funct_out='0;
        internal_div_out.imm = '0;//this field only used in branch instructions
        internal_div_out.depen = res_station_out.depen;
        internal_div_out.pc_next  = '0;
        internal_div_out.load_queue_tail = '0;
        internal_div_out.store_queue_tail = '0;
    end

    logic   check_dep, check_dep_latched;
    assign  check_dep = (internal_div_out.depen.rob_tags[(recover_idx)] == depen_rob)
                        &&internal_div_out.depen.valid[recover_idx];
    assign  check_dep_latched = (internal_div_out_latched.depen.rob_tags[(recover_idx)] == depen_rob)
                        &&internal_div_out_latched.depen.valid[recover_idx];

    always_ff @(posedge clk) begin
        if (rst) begin
            internal_div_out_latched <= '0;
            inst_start_latched <= '0;
            flush_latched <= '0;
        end else begin

            if (flush && !inst_complete && check_dep_latched)
                flush_latched <= 1'b1;

            if (flush && inst_start && check_dep)
                flush_latched <= 1'b1;

            // only latch data when input is valid
            if (input_valid)
                internal_div_out_latched <= internal_div_out;

            if (inst_start)
                inst_start_latched <= 1'b1;

            //reset inst start latched and latched data when complete
            if (inst_start_latched && inst_complete) begin
                inst_start_latched <= 1'b0;
                internal_div_out_latched <= '0;

                // reset flush latched if needed too
                if (flush_latched)
                    flush_latched <= '0;
            end

        end
    end

    // check if we are using the latched value
    always_comb begin
        div_out = (inst_start_latched && inst_complete) ? 
                    internal_div_out_latched : '0;
        div_out.out_valid = inst_start_latched && inst_complete;
        case(internal_div_out_latched.inst[14:12])

            div, divu :div_out.funct_out   =  ~divide_by_0_inst ? quotient_inst[31:0] : '1;
            // divu: div_out.funct_out =  ~divide_by_0_inst_u ? quotient_inst_u[31:0]: '1;    //use div
            rem, remu: div_out.funct_out  =  remainder_inst[31:0];
            // remu: div_out.funct_out =  remainder_inst_u[31:0];    //use remainder out
            default:  div_out.funct_out =  '0;
        endcase

        // force reset everything to zero if flush latched
        if (flush_latched)
            div_out = '0;
    end

        // if there is no instruction running in div, it is ready
    assign  ready = !(inst_start || inst_start_latched);
endmodule

