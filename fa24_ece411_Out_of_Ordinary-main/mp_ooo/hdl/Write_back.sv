module write_back
import CDB_types::*;
import rv32i_types::*;
#(
        // parameter CDB_NUM=4
)
(  
    input   logic   clk,
    input   logic   rst,
    // input   logic    flush,
    // input   logic   alu_out_valid,
    // input   logic   cmp_out_valid,
    // input   logic   mult_out_valid,
    // input   logic   div_out_valid,
    // input from four function units
    input   funct_unit_out_t    alu_unit_out,
    input   funct_unit_out_t    cmp_unit_out,
    input   funct_unit_out_t    mult_unit_out,
    input   funct_unit_out_t    div_unit_out,

    // output four CDBs
    output  CDB_t   CDB   [WB_CDB_NUM]
);
    // EX_WB_reg_t   EX_WB_reg, EX_WB_reg_next;
    funct_unit_out_t   funct_unit_out[WB_CDB_NUM];
    funct_unit_out_t   funct_unit_out_next[WB_CDB_NUM];

    logic br_en[WB_CDB_NUM];
    logic [1:0] br_jump_sel[WB_CDB_NUM];
    logic [31:0] pc_next[WB_CDB_NUM];
    always_comb begin
        for (int i = 0; i < WB_CDB_NUM; i++) begin
            br_en[i] = funct_unit_out[i].br_en;
            br_jump_sel[i] = funct_unit_out[i].br_jump_sel;
        end
    end

    always_comb begin
        funct_unit_out_next[0] = alu_unit_out;
        funct_unit_out_next[1] = cmp_unit_out;
        funct_unit_out_next[2] = mult_unit_out;
        funct_unit_out_next[3] = div_unit_out;
    end

    always_comb begin
        for (int unsigned i = 0; i < WB_CDB_NUM; i++) begin
              
                if (br_jump_sel[i] !=0 ) begin 
                    pc_next[i] = funct_unit_out[i].pc_next;
                end
                else begin  
                    pc_next[i] = funct_unit_out[i].pc + 4;
                end
        end
    end

    always_comb begin
        for (int unsigned i = 0; i < WB_CDB_NUM; i++) begin
            CDB[i].depen = funct_unit_out[i].depen;
            CDB[i].br_en = funct_unit_out[i].br_en;
            CDB[i].rob_idx = funct_unit_out[i].rob_idx;
            CDB[i].funct_out = funct_unit_out[i].funct_out;
            CDB[i].pc = funct_unit_out[i].pc;
            if( br_jump_sel[i] == jump ||br_jump_sel[i] == jump_link) begin
                CDB[i].funct_out = funct_unit_out[i].pc +4;
            end
            CDB[i].pc_next = pc_next[i];
            CDB[i].inst = funct_unit_out[i].inst;
            CDB[i].pd = funct_unit_out[i].pd_idx;
            CDB[i].rd = funct_unit_out[i].rd_idx;
            CDB[i].we = funct_unit_out[i].out_valid;
            

            // rvfi stuff: should CDB store all rvfi stuff?
            // set defaults
            CDB[i].rvfi_val = '0;
            CDB[i].rvfi_val.inst = funct_unit_out[i].inst;
            CDB[i].rvfi_val.src_1_s = '0; // funct_unit_out[i].src_1_s;
            CDB[i].rvfi_val.src_2_s = '0; // funct_unit_out[i].src_2_s;
            CDB[i].rvfi_val.src_1_v = funct_unit_out[i].src_1_v;
            CDB[i].rvfi_val.src_2_v = funct_unit_out[i].src_2_v;
            CDB[i].rvfi_val.rd_s = funct_unit_out[i].rd_idx;
            CDB[i].rvfi_val.pc = funct_unit_out[i].pc;
            CDB[i].rvfi_val.pc_next = pc_next[i];
            CDB[i].rvfi_val.mem_addr = '0;
            CDB[i].rvfi_val.mem_rmask = '0;
            CDB[i].rvfi_val.mem_wmask = '0;
            CDB[i].rvfi_val.mem_rdata = '0;
            CDB[i].rvfi_val.mem_wdata = '0;

        end

        // CDB[0].we = alu_out_valid;
        // CDB[1].we = cmp_out_valid;
        // CDB[2].we = mult_out_valid;
        // CDB[3].we = div_out_valid;
    end

    

    always_ff @(posedge clk) begin
        if (rst ) begin //|| flush
            for (int unsigned i = 0; i < WB_CDB_NUM; i++) begin
                funct_unit_out[i] <= '0;
            end
        end else begin
            for (int unsigned i = 0; i < WB_CDB_NUM; i++) begin
                funct_unit_out[i] <= funct_unit_out_next[i] ;
            end
        end
    end

endmodule

