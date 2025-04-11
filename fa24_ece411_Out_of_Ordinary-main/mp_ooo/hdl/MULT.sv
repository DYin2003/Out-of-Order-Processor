module MULT
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
        output  funct_unit_out_t mult_out

);
    // sequential multiplier module, stuff below directly from datasheet
    parameter inst_a_width = 33;
    parameter inst_b_width = 33;
    parameter inst_tc_mode = 1;     // two's complement (0 for unsigned)
    // parameter inst_num_cyc = 3;
    parameter inst_rst_mode = 1;    // 1 for Synchronous reset
    parameter inst_input_mode =  1;  // registered input
    parameter inst_output_mode = 1; // registered output
    parameter inst_early_start = 0;
    

    logic  [65:0]       inst_product;
    logic  [32:0]       inst_a, inst_b;
    logic               hold, inst_hold;
    logic               start, inst_start;
    logic               complete, inst_complete;           
    funct_unit_out_t    internal_mult_out_latched;
    funct_unit_out_t    internal_mult_out;
    logic               inst_start_latched;
    logic               flush_latched;
    
    //* got rid of this by using the 33 bit method
    // logic  [65:0]       inst_product_u;
    // logic           inst_complete_u;
    // Instance of DW_mult_seq
    DW_mult_seq #(
    inst_a_width, inst_b_width, inst_tc_mode, mult_inst_num_cyc,
    inst_rst_mode, inst_input_mode, inst_output_mode,
    inst_early_start
    )
    Mult_Unit (.clk(clk), .rst_n(~rst), 
    .hold(inst_hold),
    .start(inst_start), 
    .a(inst_a), 
    .b(inst_b),
    .complete(inst_complete), 
    .product(inst_product));

    //* got rid of this by using the 33 bit method
    // DW_mult_seq #(
    // inst_a_width, inst_b_width, 0, inst_num_cyc,
    // inst_rst_mode, inst_input_mode, inst_output_mode,
    // inst_early_start
    // )
    // Mult_Unit_u (.clk(clk), .rst_n(~rst), 
    // .hold(inst_hold),
    // .start(inst_start), 
    // .a(inst_a), 
    // .b(inst_b),
    // .complete(inst_complete_u), 
    // .product(inst_product_u) );
        
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
            mul,mulh:begin
                inst_a = (a == '0) ? '0 : {as[31], signed'(as)}; 
                inst_b = (b == '0) ? '0 : {bs[31], signed'(bs)}; 
            end
            mulhu:begin     // u * u rs1,rs2
                inst_a = {1'b0, au};
                inst_b = {1'b0, bu};
            end
            mulhsu:begin    // rs1 a singed, rs2 b unsigned
                inst_a = (a == '0) ? '0 : {as[31], signed'(as)};//unsigned'(a); 
                inst_b = {1'b0, bu};
            end
            default:begin
                inst_a = {1'b0, unsigned'(as)}; 
                inst_b = {1'b0, unsigned'(bs)}; 
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
        internal_mult_out.pc_next_pred = '0;
        internal_mult_out.out_valid = inst_start_latched && inst_complete;
        internal_mult_out.br_en = res_station_out.ctrl_block.is_br;  
        internal_mult_out.rd_idx = res_station_out.rd_idx;
        internal_mult_out.pd_idx = res_station_out.pd_idx;
        internal_mult_out.rob_idx = res_station_out.rob_idx;
        internal_mult_out.inst = res_station_out.inst;
        internal_mult_out.pc = res_station_out.pc;
        // internal_mult_out.src_1_s = res_station_out.ps1_idx;
        // internal_mult_out.src_2_s = res_station_out.ps2_idx;
        internal_mult_out.br_jump_sel = res_station_out.ctrl_block.br_jump_sel;
        internal_mult_out.src_1_v = a;
        internal_mult_out.src_2_v = b;
        internal_mult_out.funct_out='0;
        internal_mult_out.imm = '0;
        internal_mult_out.depen = res_station_out.depen;
        internal_mult_out.pc_next = '0;
        internal_mult_out.load_queue_tail = '0;
        internal_mult_out.store_queue_tail = '0;
    end

    logic   check_dep, check_dep_latched;
    assign  check_dep = (internal_mult_out.depen.rob_tags[(recover_idx)] == depen_rob)
                        &&internal_mult_out.depen.valid[recover_idx];
    assign  check_dep_latched = (internal_mult_out_latched.depen.rob_tags[(recover_idx)] == depen_rob)
                        &&internal_mult_out_latched.depen.valid[recover_idx];

    always_ff @(posedge clk) begin
        if (rst) begin
            internal_mult_out_latched <= '0;
            inst_start_latched <= '0;
            flush_latched <= '0;
        end else begin

            // if latched version matches up, flush it
            if (flush && !inst_complete && check_dep_latched)
                flush_latched <= 1'b1;

            if (flush && inst_start && check_dep)
                flush_latched <= 1'b1;
                
            if (input_valid)
                internal_mult_out_latched <= internal_mult_out;

            if (inst_start)
                inst_start_latched <= 1'b1;

                //reset inst start latched
            if (inst_start_latched && inst_complete) begin
                inst_start_latched <= 1'b0;
                internal_mult_out_latched <= '0;

                // reset flush latched if needed too
                if (flush_latched)
                    flush_latched <= '0;
            end

        end
    end

    // check if we are using the latched value
    always_comb begin
        mult_out = (inst_start_latched && inst_complete) ? 
                        internal_mult_out_latched : '0;
        mult_out.out_valid = inst_start_latched && inst_complete;
        case(internal_mult_out_latched.inst[14:12])
                mul:        mult_out.funct_out = inst_product[31:0];//lower half
                mulhsu:     mult_out.funct_out = inst_product[63:32];
                mulh:       mult_out.funct_out = inst_product[63:32];
                mulhu:      mult_out.funct_out = inst_product[63:32];//upper half
                default:    mult_out.funct_out= '0;
        endcase

        // force reset everything to zero if flush latched
        if (flush_latched)
            mult_out = '0;
    end
    
    // if there is no instruction running in mult, it is ready
    assign  ready = !(inst_start || inst_start_latched);

endmodule

