module ROB 
import CDB_types:: ROB_t;
import CDB_types::*;
#(
    // parameter DEPTH = 16,
    // parameter DWIDTH = 32,
    // parameter P_REG_NUM = 64, 
    // parameter CDB_NUM = 5
)
(
    input logic rst,    
    input logic clk,
    // input logic flush,
  
    // from rename unit
    input logic enq,
    input logic [$clog2(P_REG_NUM)-1:0] pd_in,
    input logic [4:0] rd_in,
    //from CDB
    //cp3:
    input logic  [31:0] pc_in[CDB_NUM], //next pc values
    input  logic        br_en[CDB_NUM],
    input  logic   regf_we_cdb[CDB_NUM],
    input  logic   [$clog2(ROB_DEPTH) -1:0] rob_num_commit_ready [CDB_NUM], //valid bit from ALU/MULT/BR
    //outputs to RRF
    output logic       deq,
    output logic [$clog2(P_REG_NUM)-1:0] pd_out,
    output logic [4:0] rd_out,
    // needs next free rob_num
    output logic [$clog2(ROB_DEPTH):0] free_rob_num,
    output logic [$clog2(ROB_DEPTH):0] head, //always points to the oldest instruction
    
    //flush for 
    input  logic [$clog2(ROB_DEPTH):0]   recover_rob_tail,
    // output logic [31:0] pc_out,
    input logic flush,
    output logic empty,full     
);
    // localparam IDX_MAX = (DEPTH)-1; //Largest Index Into FIFO  
    logic [$clog2(ROB_DEPTH):0] tail; //points to the next free spot in ROB
    ROB_t rob_tags[ROB_DEPTH]; //rob_tags[i] holds addresses of physical registers (pd)
    logic commit_ready[ROB_DEPTH]; //commit_ready[i] is 1 when instruction i is ready to commit 
    logic valid[ROB_DEPTH]; //added for EBR
    logic empty_reg,full_reg;
    logic wrap_around;            //wrap_around is set to equal head XOR tail, to check if MSB of the two are different
    logic we;                  //write enable to rrf high when commit[head] is high
    logic flush_latch;         //flush_latch is high when flush is high
    always_ff @(posedge clk) begin 
        if(rst ) begin                                       //reset all signals
            head <='0;
            tail <='0;
            we <='0;
            for(int unsigned i =0; i < ROB_DEPTH; i++) begin
                valid[i] <= '0;
                rob_tags[i] <= '0;
                commit_ready[i] <= '0;     
            end 
        end

        else begin
            for (int unsigned i = 0; i < CDB_NUM; i++) begin                  //looking through all 4 CDB regf_we signals
            if(regf_we_cdb[i]) begin                                //if CDB is writing, check the CDB's rob_num, and set that index to high in commit_ready
                commit_ready[rob_num_commit_ready[i]] <= '1;
                rob_tags[rob_num_commit_ready[i]].pc_next <= pc_in[i];
                rob_tags[rob_num_commit_ready[i]].br_en <= br_en[i];
            end
            end
             if(enq && !full_reg) begin         //write to rob
                rob_tags[tail[$clog2(ROB_DEPTH) - 1:0]].pd  <= pd_in;
                rob_tags[tail[$clog2(ROB_DEPTH) - 1:0]].rd  <= rd_in;
                 commit_ready[tail[$clog2(ROB_DEPTH) - 1:0]] <= '0; 
                 valid[tail[$clog2(ROB_DEPTH) - 1:0]] <= '1;
                tail<= tail + 1'b1;      
            end
            if(commit_ready[head[$clog2(ROB_DEPTH)-1:0]] && !empty_reg && valid[head[$clog2(ROB_DEPTH)-1:0]]) begin     //oldest instruction is ready to commit, begin deq
                commit_ready[head[$clog2(ROB_DEPTH) - 1:0]] <= '0;                        //reset head's commit_ready signal
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

    always_ff @(posedge clk) begin
        if(rst) 
            flush_latch <= 1'b0;
        else begin
            flush_latch <= flush;
        end
    end
    
    // assign we = commit_ready[head];
    always_comb begin
        if(deq && !empty_reg) begin
            pd_out  = rob_tags[head[$clog2(ROB_DEPTH) - 1:0]].pd;
            rd_out  = rob_tags[head[$clog2(ROB_DEPTH) - 1:0]].rd;
            // pc_out = rob_tags[head[$clog2(ROB_DEPTH) - 1:0]].pc_next;
            // flush = rob_tags[head[$clog2(ROB_DEPTH) - 1:0]].br_en; 
        end
        else begin
            pd_out  = '0;
            rd_out  = '0;
            // pc_out = '0;
            // flush = '0; 
        end
    end
    assign wrap_around = (head[$clog2(ROB_DEPTH)] ^ tail[$clog2(ROB_DEPTH)]);
    assign deq = commit_ready[head[$clog2(ROB_DEPTH) - 1:0]] && valid[head[$clog2(ROB_DEPTH) - 1:0]];
    assign empty_reg = (tail == head);
    assign empty = empty_reg;
    assign full_reg = (tail[$clog2(ROB_DEPTH)-1:0]==head[$clog2(ROB_DEPTH)-1:0] & wrap_around);
    assign full = full_reg;
    assign free_rob_num = tail;//[$clog2(ROB_DEPTH) - 1:0];



endmodule : ROB
