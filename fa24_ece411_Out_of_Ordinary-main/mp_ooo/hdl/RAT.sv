module RAT
import CDB_types::*;
#(
    // parameter P_REG_NUM = 64,
    // parameter CDB_NUM = 5
)
(
    input   logic   clk,
    input   logic   rst,
    input   logic   flush,

    output  logic   rs1_valid_forward,
    output  logic   rs2_valid_forward,
    // read rs1,rs2 from Decode Stage
    input   logic   [4:0]   rs1,
    input   logic   [4:0]   rs2,
    output  logic           ps1_valid,
    output  logic           ps2_valid,
    output  logic   [$clog2(P_REG_NUM) -1 :0]   ps1,
    output  logic   [$clog2(P_REG_NUM) -1 :0]   ps2,
    // write from Dispatch/Rename( From Free List)
    input   logic   [4:0]   rd_dispatch,
    input   logic   [$clog2(P_REG_NUM) -1 :0]   pd_dispatch,
    // write from CDB: check if pd = pd_cdb, if so set valid 
    input   logic   [4:0]   rd_cdb[CDB_NUM],
    input   logic   [$clog2(P_REG_NUM) -1 :0]   pd_cdb[CDB_NUM],
    input   logic   regf_we_dispatch,
    input   logic   regf_we_cdb[CDB_NUM],
    output   logic   [$clog2(P_REG_NUM) -1 :0]    snap_rat_map[32],
    output         logic   [31:0]                      snap_rat_valid,
    input         logic   [31:0]                      recover_rat_valid,
    input   [$clog2(P_REG_NUM) -1 :0]   recover_rat[32] //restore RAT from checkpoint

    
);
    //arrays of entries
    logic [$clog2(P_REG_NUM) -1 :0]    rat_map[32];
    // assign snap_rat_map = rat_map;
    logic   [31:0]                      rat_valid;
   
    logic   ps1_valid_reg,ps2_valid_reg;
    logic   flush_latch;
    always_ff@(posedge clk) begin
        if(rst) begin
            flush_latch <= '0;
        end
        else begin
            flush_latch <= flush;
        end
    end
    logic   [4:0]   rs1_decode;
    logic   [4:0]   rs2_decode;
    always_comb begin 
        snap_rat_valid = rat_valid;
        snap_rat_map = rat_map;
        for (int unsigned i = 0; i < CDB_NUM; i++) begin
                if(regf_we_cdb[i] && rd_cdb[i] != '0) begin
                    if(pd_cdb[i] == rat_map[rd_cdb[i]]) begin
                        snap_rat_valid[rd_cdb[i]] = '1;
                    end
                end
            end
        if(regf_we_dispatch && rd_dispatch != '0) begin
                snap_rat_map[rd_dispatch] = pd_dispatch;
                snap_rat_valid[rd_dispatch] = '0;
            end
    end


    always_ff @(posedge clk) begin
        if(rst) begin
            rat_valid <= '1;
            for(int unsigned i =0; i < 32; i++) begin
                rat_map[i] <= 6'(i);      
            end 
        end

        else if (flush) begin
            // rat_valid <= recover_rat_valid;
            for(int unsigned i =0; i < 32; i++) begin
                rat_map[i] <= (recover_rat[i]);  
                rat_valid[i] <= recover_rat_valid[i];    
            end 
            for (int unsigned i = 0; i < CDB_NUM; i++) begin
                if(regf_we_cdb[i] && rd_cdb[i] != '0) begin
                    if(pd_cdb[i] == recover_rat[rd_cdb[i]]) begin
                        rat_valid[rd_cdb[i]] <= '1;
                    end
                end
                
                    
            end
        end

        else begin 
            
            for (int unsigned i = 0; i < CDB_NUM; i++) begin
                if(regf_we_cdb[i] && rd_cdb[i] != '0) begin
                    if(pd_cdb[i] == rat_map[rd_cdb[i]]) begin
                        rat_valid[rd_cdb[i]] <= '1;
                    end
                end
            end
            if(regf_we_dispatch && rd_dispatch != '0) begin
                rat_map[rd_dispatch] <= pd_dispatch;
                rat_valid[rd_dispatch] <= '0;
            end
            
        end
    end 

always_comb begin
         rs1_valid_forward = 1'b0;
          rs2_valid_forward = 1'b0;
end
//input rs1,rs2
    always_ff@(posedge clk) begin
        if(rst) begin
            ps1_valid_reg <= '0;
            ps2_valid_reg <= '0;
            ps1 <= '0;
            ps2 <= '0;
        end
        else begin
            ps1 <= rat_map[rs1];
            ps2 <= rat_map[rs2];
            ps1_valid<=rat_valid[rs1];
            ps2_valid<=rat_valid[rs2];
            for (int unsigned i = 0; i < CDB_NUM; i++) begin
                if (regf_we_cdb[i] && rd_cdb[i] != '0) begin
                    if (pd_cdb[i] == rat_map[rd_cdb[i]]) begin
                        if(rs1 == rd_cdb[i]) begin
                            // ps1 = pd_cdb[i];
                            ps1_valid<='1;
                        end
                        if(rs2==rd_cdb[i]) begin
                            // ps2 = pd_cdb[i];
                            ps2_valid<='1;
                        end
                    end
                 end
            end
            if(regf_we_dispatch && rd_dispatch != '0) begin
                if(rs1 == rd_dispatch) begin
                    ps1 <= pd_dispatch;
                    ps1_valid<='0;
                end
                if(rs2==rd_dispatch) begin
                    ps2 <= pd_dispatch;
                    ps2_valid<= '0;
                end
            end
        end
    end 

endmodule

