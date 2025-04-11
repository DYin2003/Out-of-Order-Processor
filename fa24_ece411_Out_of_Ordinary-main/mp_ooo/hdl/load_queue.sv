module load_queue
import CDB_types::*;
import rv32i_types::*;
(
    input   logic                           rst,    
    input   logic                           clk,
    input   logic                           flush,
    input   logic                           enqueue,
    input   logic                           request,
    input   logic                           ufp_resp,
    input   logic   [31:0]                  ufp_rdata,
    input   logic                           store_committed,
    input   logic                           we,
    input   funct_unit_out_t                in,
    input   logic   [$clog2(STORE_QUEUE_DEPTH):0] st_cnt,
    input logic up,

    input  logic   [$clog2(LOAD_QUEUE_DEPTH) :0] recover_load_tail,
    output logic   [$clog2(LOAD_QUEUE_DEPTH) :0] snap_load_tail,
    input  logic  [$clog2(EBR_NUM)-1:0] recover_idx,
    input  logic  [$clog2(ROB_DEPTH):0] depen_rob, 

    input  dependency_t             depen,
    output  logic                           full,
    // output  logic                           can_output,
    output  cache_interface_t               output_to_cache,
    output  CDB_t                           output_to_CDB
         
);
    // have IDX here so I don't have to type clog(...) all the time
    localparam IDX = $clog2(LOAD_QUEUE_DEPTH)-1;
    logic   [$clog2(LOAD_QUEUE_DEPTH):0]   head, next_head, tail, head_next, wt_ptr;
    assign wt_ptr = in.load_queue_tail;

    load_entries_t  data[LOAD_QUEUE_DEPTH];
    int unsigned    i,j;
    logic   [2:0]   funct3, funct3_output;
    logic           flush_latched, wrap_around;
    logic           empty;

    assign snap_load_tail = tail;
    assign funct3 = in.out_valid ? in.inst[14:12] : '0;

    // always_comb begin
    //     head_next = head;
    //     if (flush) begin
    //         for(j = 0; j < STORE_QUEUE_DEPTH; j++) begin
    //             if((data[head + j].depen.rob_tags[recover_idx] == depen_rob && data[head + j].depen.valid) 
    //                 ) begin
    //                 head_next = head + (IDX+2)'(j);
    //             end else
    //                 break;

    //         end
    //     end
    // end

    always_ff @(posedge clk)begin
        if (rst) begin
            // when reset or flushing, reset everything
            

            if(rst) begin
                head <= '0;
                tail <= '0;
                for (i = 0; i < LOAD_QUEUE_DEPTH; i++) begin
                    data[i] <= '0;
                end
            end

            // set flush_latched
            if (rst)
                flush_latched <= 1'b0;
            

        end else begin

            // handle cache response: load data and set data valid
            if (!flush_latched && ufp_resp && (data[head[IDX:0]].rmask != '0) && (data[head[IDX:0]].ready)
                && data[head[IDX:0]].valid && (data[head[IDX:0]].st_cnt == '0)) begin
                // data[head[IDX:0]].data_valid <= '1;
                // data[head[IDX:0]].rdata <= ufp_rdata;
                data[head[IDX:0]] <= '0;
                head <= head + 1'b1;                
            end

            if (flush) begin
                // head <= '0;
                if (!empty)
                    tail <= recover_load_tail;
                for(int unsigned i = 0; i < LOAD_QUEUE_DEPTH; i++) begin
                    if(data[i].depen.rob_tags[recover_idx] == depen_rob && data[i].depen.valid[recover_idx]) begin
                        data[i].valid <= '0;
                        // update head based on what got flushed
                        // head <= head + ($clog2(LOAD_QUEUE_DEPTH) + 1)'(i);
                        if ((IDX+1)'(i) == head[IDX:0]) begin
                            head <= recover_load_tail;
                        end
                    end
                end
                // head <= head_next;
                if (flush && request)
                    flush_latched <= 1'b1;
            end
            else if(up) begin
                
                for (j=0;j <LOAD_QUEUE_DEPTH;j++) begin
                        if(data[j].depen.rob_tags[(recover_idx)] == depen_rob && data[j].depen.valid[recover_idx]) begin
                            data[j].depen.valid[recover_idx]<='0;
                            
                    end
                end
            
            end
            // enqueue logic
            if (!full && enqueue) begin
                if (flush) begin
                    if (!(depen.rob_tags[recover_idx] == depen_rob &&  depen.valid[recover_idx])) begin
                        data[recover_load_tail[IDX:0]].data_valid <= '0;
                        data[recover_load_tail[IDX:0]].rdata <= '0;
                        data[recover_load_tail[IDX:0]].ready <= '0;
                        data[recover_load_tail[IDX:0]].valid <= '1;
                        data[recover_load_tail[IDX:0]].depen <= depen; // one more bit ready,enable when write from adder
                        data[recover_load_tail[IDX:0]].st_cnt    <= st_cnt;

                        tail <= recover_load_tail + 1'b1;
                    end
                end else begin
                    data[tail[IDX:0]].data_valid <= '0;
                    data[tail[IDX:0]].rdata <= '0;
                    data[tail[IDX:0]].ready <= '0;
                    data[tail[IDX:0]].valid <= '1;
                    data[tail[IDX:0]].depen <= depen; // one more bit ready,enable when write from adder
                    data[tail[IDX:0]].st_cnt    <= st_cnt;
                    // move tail
                    tail <= tail + 1'b1;
                end
            end 

            

            if(we && data[wt_ptr[IDX:0]].valid) begin
                data[wt_ptr[IDX:0]].ready <= '1;
                // set mask
                case (funct3)
                    load_f3_lb, load_f3_lbu: begin
                        data[wt_ptr[IDX:0]].rmask <= 4'b0001 << in.funct_out[1:0];
                    end
                    load_f3_lh, load_f3_lhu: begin
                        data[wt_ptr[IDX:0]].rmask <= 4'b0011 << in.funct_out[1:0];
                    end
                    load_f3_lw: begin
                        data[wt_ptr[IDX:0]].rmask <= 4'b1111;
                    end
                    default: begin
                        data[wt_ptr[IDX:0]].rmask <= '0;
                    end
                endcase

                // set other elements
                data[wt_ptr[IDX:0]].addr      <= {in.funct_out[31:2], 2'b00};
                data[wt_ptr[IDX:0]].funct_out <= in;
                // data[wt_ptr[IDX:0]].depen <= in.depen;
                // data[wt_ptr[IDX:0]].st_cnt    <= st_cnt;
            end
               

            // handle store pointer update: if a store is committed,
            // decrement all st_cnt in the queue by one (unless already 0)
            if (store_committed) begin
                for (i = 0; i < LOAD_QUEUE_DEPTH; i++) begin
                    if (data[i].st_cnt != '0)
                        data[i].st_cnt <= data[i].st_cnt - 1'b1;
                end
            end

            // handle commit: only commit when data_valid
            // if (data[head[IDX:0]].data_valid) begin
            //     // mark the output entry as invalid
            //     data[head[IDX:0]] <= '0;
            //     head <= head + 1'b1;
            // end

            // reset flush_latched if there's an invalid response
            if (ufp_resp && flush_latched)
                flush_latched <= '0;
        end
    end

    //If MSB of head and tail are different, and the other bits are the same, then the queue is full
    assign wrap_around = (head[IDX + 1'b1] ^ tail[IDX + 1'b1]);      
    assign full = (tail[IDX:0] == head[IDX:0] & wrap_around);
    assign empty = tail == head;

    // handle output to cache and CDB
    always_comb begin
        // set defaults
        output_to_cache = '0;

        // output request
        if (!ufp_resp && data[head[IDX:0]].ready && data[head[IDX:0]].valid &&
            (data[head[IDX:0]].st_cnt == '0)) begin
            output_to_cache.ufp_addr = data[head[IDX:0]].addr;
            output_to_cache.ufp_rmask = data[head[IDX:0]].rmask;
            output_to_cache.ufp_wmask = '0;
            output_to_cache.ufp_wdata = '0;
        end

        next_head = head + 1'b1;
        // only output to CDB if data is valid
        // set default
        output_to_CDB = '0;
        if (!flush_latched && ufp_resp && (data[head[IDX:0]].rmask != '0)
            && (data[head[IDX:0]].st_cnt == '0) && data[head[IDX:0]].ready && data[head[IDX:0]].valid) begin

            // initiate new cache request
            if (data[next_head[IDX:0]].rmask != '0 && (data[next_head[IDX:0]].st_cnt == '0)
                && data[next_head[IDX:0]].ready && data[next_head[IDX:0]].valid) begin
                output_to_cache.ufp_addr = data[next_head[IDX:0]].addr;
                output_to_cache.ufp_rmask = data[next_head[IDX:0]].rmask;
                output_to_cache.ufp_wmask = '0;
                output_to_cache.ufp_wdata = '0;
            end

            output_to_CDB.we = '1;
            output_to_CDB.br_en = '0; // shouldn't branch
            output_to_CDB.rd = data[head[IDX:0]].funct_out.rd_idx;
            output_to_CDB.pd = data[head[IDX:0]].funct_out.pd_idx;
            output_to_CDB.rob_idx = data[head[IDX:0]].funct_out.rob_idx;
            output_to_CDB.rvfi_val.src_1_v = data[head[IDX:0]].funct_out.src_1_v;
            output_to_CDB.rvfi_val.src_2_v = data[head[IDX:0]].funct_out.src_2_v;
            output_to_CDB.rvfi_val.pc = data[head[IDX:0]].funct_out.pc;
            output_to_CDB.pc = data[head[IDX:0]].funct_out.pc;
            output_to_CDB.pc_next = data[head[IDX:0]].funct_out.pc + 4;
            output_to_CDB.rvfi_val.inst = data[head[IDX:0]].funct_out.inst;
            output_to_CDB.rvfi_val.mem_addr = data[head[IDX:0]].addr;
            output_to_CDB.rvfi_val.mem_rmask = data[head[IDX:0]].rmask;
            output_to_CDB.rvfi_val.mem_wmask = '0;
            output_to_CDB.rvfi_val.mem_rdata = ufp_rdata;
            output_to_CDB.rvfi_val.mem_wdata = '0;

            // output is mask dependent
            // det default and change this based on mask
            funct3_output = data[head[IDX:0]].funct_out.inst[14:12];
            output_to_CDB.funct_out = '0;
                
            
            case (data[head[IDX:0]].rmask)

                // lb, lbu
                4'b0001: begin
                    if (funct3_output == load_f3_lb)
                        output_to_CDB.funct_out = {{24{ufp_rdata[7]}}, ufp_rdata[7:0]};
                    if (funct3_output == load_f3_lbu)
                        output_to_CDB.funct_out = {{24{1'b0}}, ufp_rdata[7:0]};
                end
                4'b0010: begin
                    if (funct3_output == load_f3_lb)
                        output_to_CDB.funct_out = {{24{ufp_rdata[15]}}, ufp_rdata[15:8]};
                    if (funct3_output == load_f3_lbu)
                        output_to_CDB.funct_out = {{24{1'b0}}, ufp_rdata[15:8]};
                end    
                4'b0100: begin 
                    if(funct3_output == load_f3_lb)
                        output_to_CDB.funct_out = {{24{ufp_rdata[23]}}, ufp_rdata[23:16]};
                    if(funct3_output == load_f3_lbu)
                        output_to_CDB.funct_out = {{24{1'b0}}, ufp_rdata[23:16]};
                end
                4'b1000: begin 
                    if(funct3_output == load_f3_lb)
                        output_to_CDB.funct_out = {{24{ufp_rdata[31]}}, ufp_rdata[31:24]};
                    if(funct3_output == load_f3_lbu)
                        output_to_CDB.funct_out = {{24{1'b0}}, ufp_rdata[31:24]};
                end 
                // lh, lhu
                4'b0011: begin 
                    if(funct3_output == load_f3_lh)
                        output_to_CDB.funct_out = {{16{ufp_rdata[15]}}, ufp_rdata[15:0]};
                    if(funct3_output == load_f3_lhu)
                        output_to_CDB.funct_out = {{16{1'b0}}, ufp_rdata[15:0]};
                end 
                4'b0110: begin
                    if(funct3_output == load_f3_lh)
                        output_to_CDB.funct_out = {{16{ufp_rdata[23]}}, ufp_rdata[23:8]};
                    if(funct3_output == load_f3_lhu)
                        output_to_CDB.funct_out = {{16{1'b0}}, ufp_rdata[23:8]};
                end
                4'b1100: begin
                    if(funct3_output == load_f3_lh)
                        output_to_CDB.funct_out = {{16{ufp_rdata[31]}}, ufp_rdata[31:16]};
                    if(funct3_output == load_f3_lhu)
                        output_to_CDB.funct_out = {{16{1'b0}}, ufp_rdata[31:16]};
                end
                //lw
                4'b1111: output_to_CDB.funct_out = ufp_rdata;
                default: output_to_CDB = '0;
                

                endcase
                
        end 
    end


endmodule