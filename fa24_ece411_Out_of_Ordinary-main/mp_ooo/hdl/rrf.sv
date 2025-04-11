module RRF
import CDB_types:: ROB_t;
import CDB_types::*;
#(
    // parameter P_REG_NUM = 64
)
(
    input   logic   clk,
    input   logic   rst,
    // input   logic   flush,
    //from ROB
    input   logic       regf_we,
    input   logic [$clog2(P_REG_NUM)-1:0] pd_in,
    input   logic [4:0] rd_in,

    //to free list
    output  logic [$clog2(P_REG_NUM)-1:0] pd_out,
    output  logic       enq,
    // output  logic flush_latch,
    output   logic   [$clog2(P_REG_NUM) -1 :0]   restore_rat[32]
);
    logic [$clog2(P_REG_NUM)-1:0] free_me;              //pd that is being replaced in rrf, sent to freelist
    logic [$clog2(P_REG_NUM)-1:0] rrf_tags[32];         //holds all pds that are in use
    
    // always_ff@(posedge clk) begin
    //     if(rst) begin
    //         flush_latch <= '0;
    //     end
    //     else begin
    //         // flush_latch <= flush;
    //     end
    // end
   
    always_ff@(posedge clk) begin
        if(rst) begin                                   //reset signals
            // enq <= '0;      
            for(int unsigned i=0; i < 32; i++) begin
                rrf_tags[i] <= 6'(i);
            end  
        end          
        else if (regf_we ) begin                         //if ROB is trying to write to rrf
            free_me<='0;                                //for initial starting case when rd passed in is 0, set free_me to 0 and enq to 0 (does not enqueue)
            // enq <= '0;
            if(rd_in != '0) begin                       //for all other rd's
                free_me <= rrf_tags[rd_in];             //freed pd is old pd that corresponds to rd_in, send to freelist (enq=1)
                // enq <= '1;                              
                rrf_tags[rd_in] <= pd_in;               //in index rd_in, assign new in-use pd
                // pd_out = rrf_tags[rd_in];
            end
        end
        else begin
        //    enq <= '0;                                   //set enq to 0 for safety
        end
    end

    

    assign enq = (rd_in != '0) && regf_we;              //enq is high when rd_in is not 0 and regf_we is high
   
    assign pd_out = rrf_tags[rd_in];//free_me; 
    assign restore_rat = rrf_tags;                      //restore_rat is the rrf_tags
endmodule : RRF

