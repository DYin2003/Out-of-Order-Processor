module counter_reg_file
import CDB_types::*;
#(
    parameter DEPTH = 32
    // parameter DATA_LEN = 2
)(
    input  logic           clk,
    input  logic           rst,
    input  logic           we,
    // input  logic          [DATA_LEN-1:0] data_in,
    input  logic          taken,
    input  logic          [$clog2(DEPTH) - 1:0] rd_addr,
    input  logic          [$clog2(DEPTH) - 1:0] wr_addr,
    output logic          [1:0] data_out
);
        localparam  DATA_LEN = 2;
    
        logic [DATA_LEN-1:0] data [DEPTH];

        always_ff @(posedge clk) begin
            if (rst) begin
                for (int i = 0; i < DEPTH; i++) begin
                    data[i] <= '0;
                end
            end else begin
                if (we) begin
                    if(taken) begin
                        unique case(data[wr_addr]) 
                            ST: data[wr_addr] <= ST;  // Stay strongly taken
                            WT: data[wr_addr] <= ST;  // Move to strongly taken
                            WN: data[wr_addr] <= WT;  // Move to weakly taken
                            SN: data[wr_addr] <= WN;  // Move to weakly not taken
                            
                        endcase 
                    end
                    else begin
                        unique case(data[wr_addr])
                            ST: data[wr_addr] <= WT;  // Move to weakly taken
                            WT: data[wr_addr] <= WN;  // Move to weakly not taken  
                            WN: data[wr_addr] <= SN;  // Move to strongly not taken
                            SN: data[wr_addr] <= SN;  // Stay strongly not taken
                            
                        endcase
                    end
                end
                data_out <= data[rd_addr];
            end
        end
        
        


endmodule