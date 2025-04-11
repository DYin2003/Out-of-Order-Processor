module ld_st_res_station 
import CDB_types::*;
import rv32i_types::*;
(
    input   logic           rst,    
    input   logic           clk,
    input   logic           write,
    input   logic           ready,
    // input   logic           flush,
    input   logic   [$clog2(P_REG_NUM) -1:0]    cdb_pd_array[CDB_NUM],
    input   res_station_t   in,

    input logic up,
    input  logic           early_flush,
    input  logic  [$clog2(EBR_NUM)-1:0] recover_idx,
    input  logic  [$clog2(ROB_DEPTH):0] depen_rob,

    input  logic    [$clog2(LD_ST_RES_DEPTH):0]  recover_tail,
    output logic    [$clog2(LD_ST_RES_DEPTH):0]  snap_tail,

    // input  logic [$clog2(LOAD_QUEUE_DEPTH):0]   load_queue_tail,
    // input  logic [$clog2(STORE_QUEUE_DEPTH):0]   store_queue_tail,

    output  logic           full,
    output  logic           out_valid,
    output  res_station_t   out
   
         
);
    localparam IDX = $clog2(LD_ST_RES_DEPTH) - 1;
    // first few logic are all int unsigned because they have to work in a for loop
    logic [$clog2(LD_ST_RES_DEPTH):0]   head, next_head, tail; 
    logic [$clog2(LD_ST_RES_DEPTH):0]   output_idx, loop_idx;
    logic wrap_around;

    // int unsigned    output_idx;
    // int unsigned    loop_idx;
    int unsigned    i,j;
    res_station_t   data   [LD_ST_RES_DEPTH]; 
    logic           full_reg;
    logic           found;
    assign snap_tail = tail;
    // always_comb begin
    //     full_reg = 1'b1;
    //     for (int unsigned i = 0; i < LD_ST_RES_DEPTH; i++) begin
    //         if (!data[i].valid) begin
    //             full_reg = 1'b0;
    //             break;
    //         end
    //     end
    // end

    always_ff @(posedge clk) begin 
        // reset logic
        if(rst) begin
            // reset all data entries
            if(rst) begin
                head <='0;
                tail <='0;
                // full_reg <= '0;
                for (j = 0; j < LD_ST_RES_DEPTH; j++) begin
                    data[j] <= '0;
                end
            end
            
        end else begin


            // handle read - if a correct data block is found, check if we need to
            // move head 
            if (found|| !(data[head[IDX:0]].valid)) begin
                
                data[output_idx[IDX:0]] <= '0;
                // update head pointer if outputting head  or head invalid (flushed)
                // and mark not full
                if ((output_idx[IDX:0] == head[IDX:0]) || !(data[head[IDX:0]].valid)) begin
                    head <= next_head;
                    full_reg <= '0;
                end
                
            end
            
            // handle write:
            if (write && !full && !early_flush) begin
                data[tail[IDX:0]] <= in;
                // if tail at the end, move it to the beginning
                // if (tail == (IDX+1'b1)'(unsigned'(LD_ST_RES_DEPTH - 1))) begin
                //     tail <= '0;

                //     // if head is also all zeros, then the station is full
                //     if (head == '0)
                //         full_reg <= '1;
                // end 

                // else begin 
                    // if tail is not all ones and tail + 1 is head, this also means 
                    // the station is full
                    if (tail + 1'b1 == head)
                        full_reg <= '1;
                    tail <= tail + 1'b1;
                // end

            end

            // handle updating valid for each register in data entry
            // if pd is broadcasted through CDB, then find if this pd exist in any
            // entries and update the valid of that entry to 1
            for (int unsigned k = 0; k < LD_ST_RES_DEPTH; k++) begin
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

            //****early flush******//
            if(early_flush) begin
                tail<=recover_tail;
                for (j=0;j <LD_ST_RES_DEPTH;j++) begin
                        if(data[j].depen.rob_tags[(recover_idx)] == depen_rob &&data[j].depen.valid[recover_idx]) begin
                            data[j].valid <='0;
                            
                    end
                end
            end
            else if(up) begin
                for (j=0;j <LD_ST_RES_DEPTH;j++) begin
                        if(data[j].depen.rob_tags[(recover_idx)] == depen_rob && data[j].depen.valid[recover_idx]) begin
                            data[j].depen.valid[recover_idx]<='0;
                            
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
        if (ready) begin
            for (i = 0; i < LD_ST_RES_DEPTH; i++) begin
                // if (i + head) is equal DEPTH, then we are overflowing
                // otherwise, just set o/p idx to i + head
                // if (i + head >= LD_ST_RES_DEPTH)
                //     output_idx = (IDX+2)'(i) + head - (IDX+2)'(unsigned'(LD_ST_RES_DEPTH));
                // else
                    output_idx = (IDX+2)'(i) + head;

                // if we found a store that's not at the head, then stop
                if ((data[output_idx[IDX:0]].inst[6:0] == op_b_store) &&
                    output_idx[IDX:0] != head[IDX:0]) begin
                    break;
                end

                // if head is a store that's not ready, then stop
                if ((data[head[IDX:0]].inst[6:0] == op_b_store) &&
                    !(data[head[IDX:0]].valid & data[head[IDX:0]].ps1_valid & 
                    data[head[IDX:0]].ps2_valid)) begin
                    break;
                end

                // check if in this entry, all valid signals are set to 1
                // if so, set found to 1 and set the o/p index 
                if (data[output_idx[IDX:0]].valid & data[output_idx[IDX:0]].ps1_valid & 
                    data[output_idx[IDX:0]].ps2_valid) begin

                    found = 1'b1;
                    break;
                end
            end

            // check if the index found was at head. If so, we need to move it
            if ((found && (output_idx[IDX:0] == head[IDX:0])) || !(data[head[IDX:0]].valid)) begin
                // check to see if there's any invalid entries ahead.  
                // if so, make head skip over them
                for (i = 1; i < LD_ST_RES_DEPTH; i++) begin
                    // if (i + head) is equal DEPTH, then we are overflowing
                    // otherwise, just set o/p idx to i + head
                    // if (i + head >= LD_ST_RES_DEPTH)
                    //     loop_idx = (IDX+2)'(i) + head - (IDX+2)'(unsigned'(LD_ST_RES_DEPTH));
                    // else
                        loop_idx = (IDX+2)'(i) + head;

                    // skip popped extry and check if next entry valid. 
                    // if so, stop the loop
                    if (data[loop_idx[IDX:0]].valid) begin
                        break;
                    end
                end

                // move head after determining how much we should move it
                if (i != LD_ST_RES_DEPTH)
                    next_head = loop_idx;
                else 
                // this means that the whole station is empty, set head to tail
                    next_head = tail;

            end
        end

    end

    assign wrap_around = (head[$clog2(LD_ST_RES_DEPTH)] ^ tail[$clog2(LD_ST_RES_DEPTH)]);
    assign full = (tail[IDX:0] == head[IDX:0]) && wrap_around;

    // If found, output the correct data and set out_valid to 1. 
    // If not, leave the out_valid to 0
    assign out = (out_valid) ? data[output_idx[IDX:0]] : '0;
    assign out_valid = found;
    // assign out = (found && !flush) ? data[output_idx] : '0;


endmodule : ld_st_res_station