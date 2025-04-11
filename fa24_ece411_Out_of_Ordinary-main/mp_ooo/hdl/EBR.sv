module EBR 
import CDB_types::*;
#(
    // parameter P_REG_NUM = 64
    //parameter EBR_NUM = 4 
)
(
    input   logic     clk,
    input   logic     rst,
    input   logic     [$clog2(P_REG_NUM)-1:0] rat_map[32],  //from stage Res
    input   logic     [$clog2(ROB_DEPTH):0] snap_rob_tail, //from stage Res, 
    input   logic     [$clog2(ROB_DEPTH):0] tag_in,       //from stage Dispatch
    input   logic     [5:0]               free_list_head,//from stage Dispatch
    // input   logic     [$clog2(LSQ_DEPTH):0]       snap_lsq_tail,
    input   logic     snap,     //snap when branch is detected in stage Res
    input   logic     early_flush, 
    // input   int unsigned snap_res_tail[5],
    input   dependency_t depen_cdb[CDB_NUM],
    input   logic   [4:0]   rd_cdb[CDB_NUM],
    input   logic   [$clog2(P_REG_NUM) -1 :0]   pd_cdb[CDB_NUM],
    input   logic   regf_we_cdb[CDB_NUM],
        input logic up,
    //output to be restored when misspredict
    input         logic   [31:0]                      snap_rat_valid,
    output         logic   [31:0]                      recover_rat_valid,
    // output  int unsigned recover_res_tail[5],
    // output  logic      [$clog2(LSQ_DEPTH):0]        recover_lsq_tail,
    input  tails_t snap_tails,
    output tails_t recover_tails,

    output  logic     [$clog2(P_REG_NUM)-1:0] recover_rat[32],
    output  logic     [$clog2(ROB_DEPTH):0]   recover_rob_tail,
    output  logic    [$clog2(FL_DEPTH):0]     recover_free_list_head,
    input   logic     [$clog2(EBR_NUM) -1:0] EBR_recovery_idx,
    //debugging some crazy edge case ... clear the rob tag when it is committed
    // input logic ready_for_commit,
    // input logic [$clog2(ROB_DEPTH):0] rob_head,
    //ouput to reservation station
    output dependency_t dependency_out  //ouput to res station
);
    
    // localparam EBR_NUM = 4;
    EBR_t EBR_data[EBR_NUM];
    // logic   [$clog2(P_REG_NUM)-1:0] snap_rat_array [EBR_NUM][32];
    // logic   [4:0]               free_list_head[EBR_NUM];
    // logic   [$clog2(ROB_DEPTH):0] sn ap_rob_tail[EBR_NUM];
    //pass to reservation station for dependency check
    logic[(EBR_NUM)-1:0] [$clog2(ROB_DEPTH):0] rob_tags;//[EBR_NUM];
    logic [$clog2(EBR_NUM) -1:0] EBR_idx;
    logic [$clog2(EBR_NUM) -1:0] EBR_idx_no;
    logic [(EBR_NUM)-1:0]valid,valid_next;
    // logic [$clog2(LSQ_DEPTH):0]lsq_tail[EBR_NUM];
    // int unsigned res_tail[EBR_NUM][5];
    tails_t tails[EBR_NUM];
    logic [(EBR_NUM)-1:0][$clog2(ROB_DEPTH):0] rob_tags_next;
    logic [$clog2(EBR_NUM)-1:0] ebr_cdb_idx;
    logic [$clog2(ROB_DEPTH):0] tag_cdb;

    always_ff@(posedge clk) begin
        if(rst |early_flush) begin
            EBR_idx_no<='1;
            EBR_idx <= '0;
            valid <= '0;
            for (int unsigned i = 0; i < EBR_NUM; i++) begin
                // EBR_data[i].snap_rat <= '0;
                for(int unsigned j = 0; j < 32; j++) begin
                    EBR_data[i].snap_rat[j] <= '0;
                end
                
                tails[i] <= '0;
                // lsq_tail[i] <= '0;
                EBR_data[i].snap_rat_valid<='0;
                EBR_data[i].snap_rob_tail <= '0;
                EBR_data[i].free_list_head <= '0;
                rob_tags[i] <= '0;
                EBR_data[i].depen.valid     <='0;
                EBR_data[i].depen.rob_tags <= '0;
                EBR_data[i].depen.idx <= '0;
            end
        end
        // else if(early_flush)begin  
        //     EBR_idx_no<='1;
        //     EBR_idx <= '0;
        //     valid <= '0;
        //     for (int unsigned i = 0; i < EBR_NUM; i++) begin
        //         rob_tags[i] <= '0;
        //         EBR_data[i].depen.valid     <='0;
        //         EBR_data[i].depen.rob_tags <= '0;
        //         EBR_data[i].depen.idx <= '0;
        //         if(  EBR_recovery_idx == ($clog2(EBR_NUM))'(i) ) begin
        //             for(int unsigned j = 0; j < 32; j++) begin
        //                 EBR_data[i].snap_rat[j] <= '0;
        //             end
        //             tails[i] <= '0;
        //             EBR_data[i].snap_rat_valid<='0;
        //             EBR_data[i].snap_rob_tail <= '0;
        //             EBR_data[i].free_list_head <= '0;
        //             rob_tags[i] <= '0;
        //             EBR_data[i].depen.valid     <='0;
        //             EBR_data[i].depen.rob_tags <= '0;
        //             EBR_data[i].depen.idx <= '0;
        //         end
        //     end
        // end
        else begin
            // if(ready_for_commit) begin
            //      for (int unsigned i = 0; i < EBR_NUM; i++) begin
            //         if(rob_tags[i] == rob_head && valid[i] == 1'b1) begin
            //             rob_tags[i] <= '0;
            //             valid[i] <= '0;
            //             for (int unsigned j = 0; j < EBR_NUM; j++) begin 
            //                 EBR_data[j].depen.rob_tags[i] <= '0; 
            //                 EBR_data[j].depen.valid[i] <= '0;
            //             end
            //         end
            //      end
            // end
             if(up)begin
                rob_tags[EBR_recovery_idx] <= '0;
                valid[EBR_recovery_idx] <= '0;
                EBR_data[EBR_recovery_idx].depen.valid <= valid_next;
                EBR_data[EBR_recovery_idx].depen.rob_tags <= rob_tags_next; 
            end 
            if(snap) begin
                //data needed for recovery
                valid[EBR_idx] <= '1 ;
                EBR_data[EBR_idx].depen.valid <= valid_next;
                EBR_data[EBR_idx].depen.rob_tags <= rob_tags_next; 
                EBR_data[EBR_idx].depen.idx <= EBR_idx;
                EBR_data[EBR_idx].snap_rat <= rat_map;
                EBR_data[EBR_idx].snap_rat_valid<= snap_rat_valid;
                EBR_data[EBR_idx].snap_rob_tail <= snap_rob_tail+1'b1;
                EBR_data[EBR_idx].free_list_head <= free_list_head;
                rob_tags[EBR_idx] <= tag_in;
                EBR_idx <= EBR_idx + 1'b1;
                EBR_idx_no<=EBR_idx_no + 1'b1;
                tails[EBR_idx] <= snap_tails;

                    // if(tag_in ==  rob_tags[EBR_idx] && valid[EBR_idx]) begin //overlapped, invalid all others
                    //     for(int unsigned i =0; i < EBR_NUM;i++) begin
                    //         if( EBR_idx != ($clog2(EBR_NUM))'(i) ) begin
                    //             valid[i] <= '0;
                    //             rob_tags[i] <= '0;  
                    //             EBR_data[i].depen.valid <= '0;
                    //         end
                    //     end
                    // end
            end
            if(valid != '0 ||snap) begin
                for (int unsigned k = 0; k < CDB_NUM; k++) begin
                    if(regf_we_cdb[k] &&rd_cdb[k]!='0) begin
                        // ebr_cdb_idx = depen_cdb[k].idx;
                        // tag_cdb = depen_cdb[k].rob_tags[ebr_cdb_idx];
                        for (int unsigned j=0; j < EBR_NUM;j++) begin
                            // if( depen_cdb[k].rob_tags[depen_cdb[k].idx] != EBR_data[j].depen.rob_tags[depen_cdb[k].idx] || depen_cdb[k].valid==0 
                            //     || ( depen_cdb[k].rob_tags[depen_cdb[k].idx] == EBR_data[j].depen.rob_tags[depen_cdb[k].idx] && depen_cdb[k].idx != EBR_data[j].depen.idx) ) begin
                            if( (depen_cdb[k].rob_tags[depen_cdb[k].idx] == EBR_data[j].depen.rob_tags[depen_cdb[k].idx] && depen_cdb[k].valid[depen_cdb[k].idx]== 1'b1 )
                                || depen_cdb[k].valid[j] == '0
                               ) begin   
                                if(pd_cdb[k] == EBR_data[j].snap_rat[rd_cdb[k]]) begin
                                    EBR_data[j].snap_rat_valid[rd_cdb[k]] <= '1;
                                end
                            end
                        end

                    end

                end
            end
            
            
        end
    end

    
    always_comb begin

        
        rob_tags_next = rob_tags;
        valid_next = valid;
        if(up)begin
                rob_tags_next[EBR_recovery_idx] = '0;
                valid_next[EBR_recovery_idx] = '0;
                for (int unsigned i = 0; i < EBR_NUM; i++) begin
                dependency_out.rob_tags[i] = rob_tags_next[i];
                dependency_out.valid[i] = valid_next[i];
            end
            dependency_out.idx = EBR_idx;       
        end 
        
        if(snap ) begin
            valid_next[EBR_idx] = '1;
            
            rob_tags_next[EBR_idx] = tag_in;
            for (int unsigned i = 0; i < EBR_NUM; i++) begin
                dependency_out.rob_tags[i] = rob_tags_next[i];
                dependency_out.valid[i] = valid_next[i];
            end

            dependency_out.idx = EBR_idx;
        end
        
        else begin
            // dependency_out.rob_tags = rob_tags;
            // for (int unsigned i = 0; i < EBR_NUM; i++) begin
            //     dependency_out.rob_tags[i] = rob_tags[i];
            // end
            // dependency_out.idx = EBR_idx;
            dependency_out = EBR_data[EBR_idx_no].depen;

        end
    end

    always_comb begin 
        // if(early_flush) begin
            recover_rat = EBR_data[EBR_recovery_idx].snap_rat;
            recover_rob_tail = EBR_data[EBR_recovery_idx].snap_rob_tail;
            recover_free_list_head = EBR_data[EBR_recovery_idx].free_list_head;
            // recover_lsq_tail = lsq_tail[EBR_recovery_idx];
            // recover_res_tail = res_tail[EBR_recovery_idx];
            recover_tails = tails[EBR_recovery_idx];
            recover_rat_valid = EBR_data[EBR_recovery_idx].snap_rat_valid;
        // end
        // else begin
        //     for (int unsigned i = 0; i < 32; i++) begin
        //         recover_rat[i] = '0;
        //     end
        //     recover_rob_tail = '0;
        //     recover_free_list_head = '0;
        //     recover_rat_valid  = '0;
            
            // recover_res_tail = '0;
        // end 
    end

    /*
    /   How to check dependencies: eg: EBR_NUM = 2
    /   each reservation station have dependency_out storing which branch they are dependent on
    /   branch one 
        and its following non branch instruction have 
        [][8] idx = 0
        branch two 
        [4][8] idx = 1
        if branch one miss predicts,
            we search for rob_tail[pivot] = 8 in the reservation stations and flush them
        if branch one hits, we let branch 3 in (cmp res station depth = EBR_NUM)) 
            branch three come in, similarly it can be flushed by branch 2 
            if we flush branch 3
                it keeps isntructions dependent on branch one
        [8][12] idx = 0
    */ 
endmodule