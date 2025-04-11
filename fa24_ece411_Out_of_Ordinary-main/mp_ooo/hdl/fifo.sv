module fifo
import CDB_types::*;
 #(
//     parameter DEPTH = 8,
    // parameter DWIDTH = 32   
)
(
    input logic rst,    
    input logic clk,
    input logic flush,
    input logic enq, deq,   // write read

    input logic [FIFO_DWIDTH-1:0] din,
    output logic [FIFO_DWIDTH-1:0] dout,
    output logic empty,full     
);
    // localparam IDX_MAX = (DEPTH)-1; //Largest Index Into FIFO  
    logic [$clog2(FIFO_DEPTH) -1:0] head; 
    logic [$clog2(FIFO_DEPTH) -1:0] tail;
    logic [FIFO_DWIDTH-1:0] fifo[FIFO_DEPTH]; 
    logic empty_reg,full_reg;
    
    always_ff @(posedge clk ) begin 
        if(rst || flush) begin
            head <='0;
            tail <='0;
            empty_reg <='1;
            full_reg <= '0;
            // dout <= '0;
        end
        else if( enq && deq && !empty && !full) begin
            // dout <= fifo[head];
            fifo[tail]  <= din;
            if(tail == '1) tail <= '0;
            else tail <= tail + 1'b1;
            if(head == '1) head <= '0;
            else head <= head + 1'b1;
        end

        else if(enq && !full_reg) begin         //write to q
            empty_reg <= '0;
            fifo[tail]  <= din;
            if(tail == '1) begin
                tail <= '0; //circular overflow
                if( head == '0) begin
                     full_reg <= '1;
                end
            end
            else begin
                if(tail + 1'b1 == head) begin
                    full_reg <= '1;                  // head laps tail -> full 
                end
                tail<= tail + 1'b1;
            end
            
        end
        else if (deq && !empty_reg) begin     //read from q
            // dout <= fifo[head];
            full_reg <= '0;
            if(head == '1) begin
                head <= '0; //circular overflow
                if( tail == '0) begin
                     empty_reg <= '1;
                end
            end
            else begin
                if(head + 1'b1 == tail) begin
                    empty_reg <= '1;                  // head laps tail -> full 
                end
                head<= head + 1'b1;
            end
        end

    end
    
    always_comb begin
        if(flush) begin
            dout <= '0;
        end
        else if(!deq)begin
            dout <= '0;
        end
        else begin 
            dout <= fifo[head];
        end
     end
    assign empty = empty_reg;
    assign full = full_reg;


endmodule : fifo

