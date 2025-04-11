module predictor_reg_file
import CDB_types::*;
#(
    parameter DEPTH = 32,
    parameter DATA_LEN = 32
)(
    input  logic           clk,
    input  logic           rst,
    input  logic           we,
    input  logic          [DATA_LEN-1:0] data_in,
    input  logic          [$clog2(DEPTH) - 1:0] rd_addr,
    input  logic          [$clog2(DEPTH) - 1:0] wr_addr,
    output logic          [DATA_LEN-1:0] data_out
);
    
        logic [DATA_LEN-1:0] data [DEPTH];

        always_ff @(posedge clk) begin
            if (rst) begin
                for (int i = 0; i < DEPTH; i++) begin
                    data[i] <= '0;
                end
            end else begin
                if (we) begin
                    data[wr_addr] <= data_in;
                end
                data_out <= data[rd_addr];
            end
        end
        
        


endmodule