module Rename
import CDB_types::*;
#(
    // parameter P_REG_NUM = 64,
    // parameter ROB_NUM   = 16,
    // parameter CDB_NUM   = 5
)
(
    input   logic                               clk,
    input   logic                               rst,
    //from ID/RE reg
    input   ID_RE_reg_t                         ID_RE_reg,
    input   logic       DE_stall,
    // input   rs1_valid_forward,
    // input   rs2_valid_forward,
    
    //from/to fifo
    input   logic   [$clog2(P_REG_NUM)-1:0]     free_list_pd,
    //to ROB
    input    logic   [$clog2(ROB_DEPTH):0]   rob_tail,
    input    logic   rob_full,
    output   logic   rob_enq,
    output   logic   [4:0]   rob_rd,
    output   logic   [$clog2(P_REG_NUM)-1:0] rob_pd,

     // accept broadcast in rename stage
    input   logic                               cdb_we_array[CDB_NUM],
    input   logic   [$clog2(P_REG_NUM) -1:0]    cdb_pd_array[CDB_NUM],

    //to rvfi_rob
    output  rvfi_val_t                          rvfi_in,

    output  logic   [4:0]                       rd_dispatch,
    output  logic   [$clog2(P_REG_NUM)-1:0]     pd_dispatch,
    output  logic                               regf_we_dispatch,
    //trying 
    // output  logic   [4:0]       rat_rs1,
    // output  logic   [4:0]       rat_rs2,
    
    input   logic   [5:0]                       ps1,
    input   logic   [5:0]                       ps2,
    input   logic                               ps1_valid,
    input   logic                               ps2_valid,
    input   logic                               res_full[5],
    output  logic                               RE_stall,

    input  logic [$clog2(LOAD_QUEUE_DEPTH):0]   load_queue_tail,
    input  logic [$clog2(STORE_QUEUE_DEPTH):0]   store_queue_tail,
    output  logic                               load_queue_enq,
    output  logic                               store_queue_enq,
    input  logic                           load_queue_full,
    input  logic                           store_queue_full,
    // input   logic   flush,
    //To Rservation Station: 
    input logic [$clog2(FL_DEPTH):0] free_list_head,
    output  res_station_t res_station_entry    
);
    
    // logic rename_stall; //if 1. free_list is empty and rd_en, 2.rob is full 
    logic           rd_en;
    logic   [4:0]   rd,rs1,rs2;
    logic   [5:0]   ps1_lat,ps2_lat;
    logic           RE_stall_latched;
    logic           latch;
    res_station_t   rename_output, rename_output_latched;
    assign rd = ID_RE_reg.rd;
    assign rd_en = ID_RE_reg.ctrl_block.rd_en;
    
    //forwarding rs1,rs2 valid signals
    // logic rs1_forward,rs2_forward;
    // assign rat_rs1 = ID_RE_reg.rs1;
    // assign rat_rs2 = ID_RE_reg.rs2;
    
    logic p1_valid_latch,p2_valid_latch;
    always_ff@(posedge clk) begin
        if(rst) begin
            p1_valid_latch <= '0;
            p2_valid_latch<=  '0;
            ps1_lat<='0;
            ps2_lat<='0;
            latch <= '0;
        end
        else if (RE_stall && !latch) begin
            RE_stall_latched <= 1'b1;
             ps1_lat <= ps1;
             ps2_lat <= ps2;
             latch <= '1;
            if(ps1_valid)begin
                p1_valid_latch <= ps1_valid;
               
            end
            if(ps2_valid) begin
                p2_valid_latch <= ps2_valid;
                
            end
        end
        else begin
            
            if(!RE_stall) begin
            RE_stall_latched <= 1'b0;
            p1_valid_latch <= '0;
            p2_valid_latch<=  '0;
            ps1_lat<='0;
            ps2_lat<='0;
            latch <= '0;
            end

        end
        if (RE_stall ) begin //| RE_stall_latched
            for (int unsigned i = 0; i < CDB_NUM; i++) begin
                if (cdb_we_array[i]) begin
                    if (((cdb_pd_array[i] == ps1_lat) && (ps1_lat!= '0)) || 
                        ((cdb_pd_array[i] == ps1) && (ps1!= '0))) begin
                        p1_valid_latch <= 1'b1;
                    end
                    if (((cdb_pd_array[i] == ps2_lat) && (ps2_lat!= '0)) || 
                        ((cdb_pd_array[i] == ps2) && (ps2!= '0))) begin
                        p2_valid_latch <= 1'b1;
                    end
                end
            end

            // reset latched signal if latched ps is not valid
            // if (ps1_lat == '0)
            //     p1_valid_latch <= '0;
            // if (ps2_lat == '0)
            //     p2_valid_latch <= '0;
        end
    end


    always_comb begin
        // connect RAT -> Res Station
        //TODO
        res_station_entry.valid    =     '1;
        // res_station_entry.ps1_valid=    rs1_valid_forward ||ID_RE_reg.ps1_valid;
        // res_station_entry.ps1_idx  =     ID_RE_reg.ps1;
        // res_station_entry.ps2_valid=    rs2_valid_forward || ID_RE_reg.ps2_valid;
        // res_station_entry.ps2_idx  =     ID_RE_reg.ps2;
        res_station_entry.ps1_valid=    p1_valid_latch | ps1_valid;
        res_station_entry.ps1_idx  =    RE_stall_latched? ps1_lat : ps1; //p1_valid_latch
        res_station_entry.ps2_valid=    p2_valid_latch | ps2_valid;
        res_station_entry.ps2_idx  =    RE_stall_latched? ps2_lat : ps2;

        res_station_entry.pd_idx   =     (rd!='0)? free_list_pd: '0;
        res_station_entry.rd_idx   =     ID_RE_reg.rd;
        res_station_entry.rob_idx  =     rob_tail; //tail of rob
        res_station_entry.rob_tail =     rob_tail;
        res_station_entry.inst     =     ID_RE_reg.inst;
        res_station_entry.pc       =     ID_RE_reg.pc;
        res_station_entry.ctrl_block=    ID_RE_reg.ctrl_block;
        res_station_entry.free_list_head = free_list_head; 
        res_station_entry.load_queue_tail = load_queue_tail;
        res_station_entry.store_queue_tail = store_queue_tail;
        res_station_entry.pc_next = ID_RE_reg.pc_next;
        if (RE_stall || ID_RE_reg.valid=='0) begin
            res_station_entry.valid = '0;
        end
    end 

    // always_ff @(posedge clk)begin
    //     if (rst) begin
    //         RE_stall_latched <= '0;
    //     end else begin
    //         if (RE_stall)
    //             RE_stall_latched <= '1;
    //         else
    //             RE_stall_latched <= '0;
    //     end

    // end
    //RAT: if rd is not enabled( use store, branch), don't map
    always_comb begin
        rd_dispatch = ID_RE_reg.rd;
        pd_dispatch = free_list_pd;
        
        regf_we_dispatch = rd_en && !DE_stall; 
    end 
    //
    //  TO ROB
    always_comb begin
        
        rob_enq = ~RE_stall && (ID_RE_reg.valid != '0);  //TODO don't enq when stalled(should stall when rob is full)
        rob_pd = (rd != '0)?free_list_pd: '0;
        rob_rd = (rd != '0)?ID_RE_reg.rd: '0;

    end
    
    //rvfi_in
    always_comb begin
        rvfi_in = ID_RE_reg.rvfi_val;     
    end

    //load/store queue
    always_comb begin
        load_queue_enq = ID_RE_reg.ctrl_block.func_unit == unit_ld && !RE_stall  && (ID_RE_reg.valid != '0);
        store_queue_enq = ID_RE_reg.ctrl_block.func_unit == unit_st && !RE_stall  && (ID_RE_reg.valid != '0);
    end

    // logic for performance counter, doesn't affect functionality
    logic   res_full_stall;
    always_comb begin
        if((ID_RE_reg.ctrl_block.func_unit == unit_alu && res_full[0]) ||
            (ID_RE_reg.ctrl_block.func_unit == unit_cmp && res_full[1]) ||
            (ID_RE_reg.ctrl_block.func_unit == unit_mul && res_full[2]) ||
            (ID_RE_reg.ctrl_block.func_unit == unit_div && res_full[3]) ||
            (ID_RE_reg.ctrl_block.func_unit == unit_ld && load_queue_full) || 
            (ID_RE_reg.ctrl_block.func_unit == unit_st && store_queue_full) ||    
            ((ID_RE_reg.ctrl_block.func_unit == unit_st || ID_RE_reg.ctrl_block.func_unit == unit_ld) && res_full[4]))
        begin
            res_full_stall = 1'b1;
            RE_stall = 1'b1;
        end
        else begin
            res_full_stall = 1'b0;
            RE_stall = rob_full && (ID_RE_reg.inst != '0);
        end
    end
endmodule

