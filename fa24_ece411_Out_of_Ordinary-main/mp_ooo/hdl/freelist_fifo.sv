module Freelist
import CDB_types::*;
#(
    // parameter P_REG_NUM = 64,
    // parameter DEPTH = 32
)
(
    input logic rst,    
    input logic clk,

    input logic enq, deq,

    input logic [$clog2(P_REG_NUM)-1:0] pd_in,

    //to rename module
    output logic [$clog2(P_REG_NUM)-1:0] pd_out,
 
    input   logic    flush,
    input   logic  [$clog2(FL_DEPTH):0] recover_free_list_head,
    output  logic [$clog2(FL_DEPTH):0] free_list_head,
    output logic empty,full  
);
    logic [$clog2(FL_DEPTH):0] head; //NEW FIFO DESIGN, head and tail have an extra bit
    logic [$clog2(FL_DEPTH):0] tail;
    logic wrap_around;            //wrap_around is set to equal head XOR tail, to check if MSB of the two are different
    logic [$clog2(P_REG_NUM)-1:0] free_list[FL_DEPTH];
    logic empty_reg,full_reg;
    logic flush_latch;

    always_ff@(posedge clk)begin
        if(rst) begin
            flush_latch <= 1'b0;
        end
        else begin
            flush_latch <= flush;
        end
    end
    always_ff@(posedge clk) begin
        if(rst) begin
            tail <= '0;
            for(int unsigned i=0; i < 32; i++) begin
                free_list[i] <= 6'(i) + 6'd32;
            end 
        end
        else if(enq && !full_reg) begin
            free_list[tail[$clog2(FL_DEPTH)-1:0]]  <= pd_in;
            tail<= tail + 1'b1;
        end
    end
    always_ff@(posedge clk) begin
        if(rst) begin
            head <= {1'b1,$clog2(FL_DEPTH)'(0)};
            pd_out <= '0;
        end 
        else if(flush) begin
            pd_out <= '0;
            // head <= {~tail[$clog2(FL_DEPTH)],tail[ $clog2(FL_DEPTH)-1 :0]};
            head <= recover_free_list_head;
        end
        else if(deq && !empty_reg) begin
            head <= head + 1'b1;
            pd_out <= free_list[head[$clog2(FL_DEPTH)-1:0]];
        end
    end

    assign wrap_around = (head[$clog2(FL_DEPTH)] ^ tail[$clog2(FL_DEPTH)]);      //If MSB of head and tail are different, and the other bits are the same, then the queue is full
    assign empty_reg = (tail == head);
    assign empty = empty_reg;
    assign full_reg = (tail[$clog2(FL_DEPTH)-1:0]==head[$clog2(FL_DEPTH)-1:0] & wrap_around);
    assign full = full_reg;
    assign free_list_head = head;
endmodule : Freelist
