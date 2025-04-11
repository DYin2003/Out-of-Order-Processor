module rvfi_rob 
import CDB_types::*;
import rv32i_types::*;
#(
    // parameter DEPTH = 16,
    // parameter CDB_NUM = 5
)
(
    input logic rst,    
    input logic clk,
    input logic flush,
  
    // from rename unit
    input logic enq,
    input rvfi_val_t rvfi_in,
    
    //from CDB
    input logic regf_we_cdb[CDB_NUM],
    input logic [$clog2(ROB_DEPTH)-1:0] rob_num_commit_ready[CDB_NUM],
    input logic [31:0] rvfi_output_cdb[CDB_NUM],
    input logic [31:0] rs1_cdb[CDB_NUM],
    input logic [31:0] rs2_cdb[CDB_NUM],
    input logic [31:0] cdb_pc_next[CDB_NUM],
    
    // Memory operation signals from LSQ
    input logic [31:0] addr_cdb,
    input logic [3:0]  rmask_cdb,
    input logic [3:0]  wmask_cdb,
    input logic [31:0] rdata_cdb,
    input logic [31:0] wdata_cdb,
    
    //from LSQ CDB
    // input CDB_t lsq_output_to_cdb,
    input  logic [$clog2(ROB_DEPTH):0]   recover_rob_tail,
    //outputs 
    output logic ready_for_commit,
    output rvfi_val_t rvfi_out,
    output logic [63:0] order
);

    logic [$clog2(ROB_DEPTH):0] head, tail;
    rvfi_val_t rvfi_tags[ROB_DEPTH];
    logic commit_ready[ROB_DEPTH];
    logic valid[ROB_DEPTH];
    logic empty_reg, full_reg;
    logic wrap_around;
    logic full, empty;
    logic [63:0] order_counter;
    logic flush_latch;
    always_ff@(posedge clk) begin
        if(rst) begin
            flush_latch <= '0;
        end
        else begin
            flush_latch <= flush;
        end
    end
    always_ff @(posedge clk) begin
        if (rst ) begin
            head <= '0;
            tail <= '0;
            if(rst)
                order_counter <= '0;
            for (int unsigned i = 0; i < ROB_DEPTH; i++) begin
                valid[i] <= '0;
                    rvfi_tags[i] <= '0;
                commit_ready[i] <= '0;

            end
        end
        else begin
             // Update from CDB
             for (int i = 0; i < CDB_NUM; i++) begin
                if (regf_we_cdb[i]) begin
                    commit_ready[rob_num_commit_ready[i]] <= '1;
                    rvfi_tags[rob_num_commit_ready[i]].rvfi_output <= rvfi_output_cdb[i];
                    rvfi_tags[rob_num_commit_ready[i]].src_1_v <= rs1_cdb[i];
                    rvfi_tags[rob_num_commit_ready[i]].src_2_v <= rs2_cdb[i];
                    rvfi_tags[rob_num_commit_ready[i]].pc_next <= cdb_pc_next[i];
                    if(i == 4) begin
                        rvfi_tags[rob_num_commit_ready[i]].mem_addr <= addr_cdb;
                        rvfi_tags[rob_num_commit_ready[i]].mem_rmask <= rmask_cdb;
                        rvfi_tags[rob_num_commit_ready[i]].mem_wmask <= wmask_cdb;
                        rvfi_tags[rob_num_commit_ready[i]].mem_rdata <= rdata_cdb;
                        rvfi_tags[rob_num_commit_ready[i]].mem_wdata <= wdata_cdb;       
                    end
                end
            end
             if (enq && !full_reg) begin
                // Only enqueue
                rvfi_tags[tail[$clog2(ROB_DEPTH)-1:0]] <= rvfi_in;
                commit_ready[tail[$clog2(ROB_DEPTH)-1:0]] <= '0;
                valid[tail[$clog2(ROB_DEPTH)-1:0]] <= '1;
                 tail <= tail + 1'b1;
            end
             if (commit_ready[head[$clog2(ROB_DEPTH)-1:0]] && !empty_reg && valid[head[$clog2(ROB_DEPTH)-1:0]]) begin
                // Only dequeue
                commit_ready[head[$clog2(ROB_DEPTH)-1:0]] <= '0;
                order_counter <= order_counter + 1'b1;
                valid[head[$clog2(ROB_DEPTH)-1:0]] <= '0;
                 head <= head + 1'b1;
            end
            if(flush) begin
               tail <= recover_rob_tail; 
                //invalidating [ recover_rob_tail : tail] distingushing wrap around bit of two tails
                if(recover_rob_tail[$clog2(ROB_DEPTH)] ^ tail[$clog2(ROB_DEPTH)]) begin
                    for(int unsigned i = 0; i < ROB_DEPTH; i++) begin
                        if (i >= int '(recover_rob_tail[$clog2(ROB_DEPTH)-1:0]))
                            valid[i] <= '0;
                    end
                    for(int unsigned i = 0; i < ROB_DEPTH; i++) begin
                        if (i <= int '(tail[$clog2(ROB_DEPTH)-1:0]))
                            valid[i] <= '0;
                    end
                end
                else begin
                for(int unsigned i = 0; i < ROB_DEPTH; i++) begin
                    if ((i >= int'(recover_rob_tail[$clog2(ROB_DEPTH)-1:0])) && (i <= int '(tail[$clog2(ROB_DEPTH)-1:0])))
                        valid[i] <= '0;
                    end 
                end
            end
            
        end
    end

    // Combinational logic
    always_comb begin
        if (ready_for_commit) begin
            rvfi_out = rvfi_tags[head[$clog2(ROB_DEPTH)-1:0]];
            order = order_counter;
        end
        else begin
            rvfi_out = '0;
            order = order_counter;
        end
    end

    assign wrap_around = (head[$clog2(ROB_DEPTH)] ^ tail[$clog2(ROB_DEPTH)]);
    assign ready_for_commit = commit_ready[head[$clog2(ROB_DEPTH)-1:0]] &&valid[head[$clog2(ROB_DEPTH)-1:0]];
    assign empty_reg = (tail == head);
    assign full_reg = (tail[$clog2(ROB_DEPTH)-1:0] == head[$clog2(ROB_DEPTH)-1:0] & wrap_around);
    assign full = full_reg;
    assign empty = empty_reg;
endmodule : rvfi_rob
