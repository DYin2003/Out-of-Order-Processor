module ARB
import CDB_types::*; 
#(
    // parameter ARB_NUM = 4
)(
    input logic clk,
    input logic  rst,
    input logic [ARB_NUM - 1:0] req,
    output logic [ARB_NUM - 1:0] grant
);
    //simple fixed priority , LSB req has highest prior
    always_comb begin
        grant = '0;
        for (int i =0; i < ARB_NUM; i++)begin
            if(req[i] =='1)begin
                grant[i] = '1;
                break;
            end
        end

    end

endmodule : ARB
