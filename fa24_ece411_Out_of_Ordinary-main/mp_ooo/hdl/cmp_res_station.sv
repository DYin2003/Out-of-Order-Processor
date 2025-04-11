module cmp_res_station 
import CDB_types::*;
#(
    parameter RES_DEPTH = 4
)
(
    input   logic           rst,    
    input   logic           clk,
    input   logic           write,
    input   logic           ready,
    input   logic   [$clog2(P_REG_NUM) -1:0]    cdb_pd_array[CDB_NUM],
    // input   logic   [31:0]  pd_0_v,pd_1_v,pd_2_v,pd_3_v,
    input   res_station_t   in,

    // input  logic           flush,
    input  logic           early_flush,
    input  logic  [$clog2(EBR_NUM)-1:0] recover_idx,
    input  logic  [$clog2(ROB_DEPTH):0] depen_rob,

    input  [$clog2(RES_DEPTH):0]  recover_tail,
    output [$clog2(RES_DEPTH):0]  snap_tail,
    output  logic           full,
    output  logic           out_valid,
    output  res_station_t   out
   
         
);
    logic sb;
    assign sb = recover_tail =='0;
    // first few logic are all int unsigned because they have to work in a for loop
    // int unsigned    head, next_head; 
    // int unsigned    tail;
    localparam IDX = $clog2(RES_DEPTH) - 1;
    logic [$clog2(RES_DEPTH):0]    head, next_head, tail;
    logic [$clog2(RES_DEPTH):0]     output_idx, loop_idx;
    logic wrap_around;

    // int unsigned    output_idx;
    // int unsigned    loop_idx;
    int unsigned    i,j;
    res_station_t   data   [RES_DEPTH]; 
    logic           full_reg, empty;
    logic           found;
    
    assign snap_tail = tail;
    
    // always_comb begin
    //     all_valid = 1'b1;
    //     for (int unsigned i = 0; i < RES_DEPTH; i++) begin
    //         if (!data[i].valid) begin
    //             all_valid = 1'b0;
    //             break;
    //         end
    //     end
    // end

    always_ff @(posedge clk) begin 
        // reset logic
        if(rst) begin
            
            // reset all data entries
            head <='0;
            tail <='0;
            // full_reg <= '0;
            for (j = 0; j < RES_DEPTH; j++) begin
                data[j] <= '0;
            end
                        
            
        end else begin

            // handle read - if a correct data block is found, check if we need to
            // move head 
            if (out_valid && !early_flush && data[head[IDX:0]].valid) begin
                // mark the output entry as invalid
                data[head[IDX:0]] <= '0;
                // update head
                head <= head + 1'b1;

            end

            //****early flush******//
            if(early_flush) begin
                tail <='0;
                head <= '0;
                // if (!empty)
                    // tail <= recover_tail;
                for (j=0;j <RES_DEPTH;j++) begin
                        if(data[j].depen.rob_tags[(recover_idx)] == depen_rob && data[j].depen.valid[recover_idx]) begin
                            data[j].valid<='0;
                            // if ((IDX+1)'(j) == head[IDX:0]) begin
                            // head <= recover_tail;
                        // end
                            
                    end
                end
            end

            // handle write:
            //? having this !early_flush here could cause problem?
            if (write && !full && !early_flush) begin
                data[tail[IDX:0]] <= in;
                tail <= tail + 1'b1;
            end

            // handle updating valid for each register in data entry
            // if pd is broadcasted through CDB, then find if this pd exist in any
            // entries and update the valid of that entry to 1
            for (int unsigned k = 0; k < RES_DEPTH; k++) begin
                // check if data valid first
                if (data[k].valid) begin

                    // if found, set it to valid
                    for (int unsigned i = 0; i < CDB_NUM; i++) begin
                        if (data[k].ps1_idx == cdb_pd_array[i])
                            data[k].ps1_valid <= 1'b1;
                        
                        if (data[k].ps2_idx == cdb_pd_array[i])
                            data[k].ps2_valid <= 1'b1;
                    end
                end
            end

        end
        
        
    end

    always_comb begin : res_station_output
        // set defaults:
        found = 1'b0;
        output_idx = '0;
        next_head = '0;
        loop_idx = '0;
        // handle outputting data: if function is ready for input: find the next
        // data that has all valid signals set to 1
        out_valid = '0;
        
        // always output head
        if (ready) begin
            
            // check if we can output head
            out_valid = (data[head[IDX:0]].valid & data[head[IDX:0]].ps1_valid & 
                        data[head[IDX:0]].ps2_valid);
            
        end

    end

    assign wrap_around = (head[$clog2(RES_DEPTH)] ^ tail[$clog2(RES_DEPTH)]);
    assign full = (tail[IDX:0] == head[IDX:0]) && wrap_around;
    assign empty = tail == head;
    
    // If found, output the correct data and set out_valid to 1. 
    // If not, leave the out_valid to 0
    // assign out_valid = found;
    assign out = (out_valid && !early_flush && data[head[IDX:0]].valid) ? data[head[IDX:0]] : '0;


endmodule : cmp_res_station

