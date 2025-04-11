module cpu
import CDB_types::*;
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,

    output  logic   [31:0]      bmem_addr,
    output  logic               bmem_read,
    output  logic               bmem_write,
    output  logic   [63:0]      bmem_wdata,
    input   logic               bmem_ready,

    input   logic   [31:0]      bmem_raddr,
    input   logic   [63:0]      bmem_rdata,
    input   logic               bmem_rvalid
);
    // plz let us pass
    // localparam P_REG_NUM = 64;
    // localparam ROB_NUM = 16;
    // localparam CDB_NUM = 5;
    cmp_to_IF cmp_in;
    logic load_queue_enq,store_queue_enq;
    logic                           load_queue_full;
    logic                           store_queue_full;
    //EBR stuff
    logic [$clog2(ROB_DEPTH):0] rob_tail;
    logic [$clog2(FL_DEPTH):0]free_list_head;
    logic [$clog2(P_REG_NUM) -1 :0]    snap_rat_map[32];
    logic [31:0]                      snap_rat_valid;
    logic [31:0]                      recover_rat_valid;
    logic [$clog2(ROB_DEPTH):0] snap_rob_tail;
    logic [$clog2(ROB_DEPTH):0] tag_in;
    logic snap;
    logic early_flush;
    logic [$clog2(P_REG_NUM) -1 :0]    recover_rat[32];
    logic [$clog2(ROB_DEPTH):0]   recover_rob_tail;
    logic [5:0]                   recover_free_list_head;
    logic [$clog2(EBR_NUM) -1:0] EBR_recovery_idx;
    logic  [$clog2(EBR_NUM)-1:0] recover_idx;
    logic  [$clog2(ROB_DEPTH):0] depen_rob;//to res,lsq
    logic jarl_stall_release_reg;
    dependency_t dependency_out;
    // int unsigned snap_res_tail[5];
    // int unsigned recover_res_tail[5];
    tails_t snap_tails;
    tails_t recover_tails;
    logic up;
    // always_comb begin
    //     snap_tails.alu_res_tail = snap_res_tail[0];
    //     snap_tails.cmp_res_tail = snap_res_tail[1];
    //     snap_tails.mult_res_tail = snap_res_tail[2];
    //     snap_tails.div_res_tail = snap_res_tail[3];
    //     snap_tails.ld_st_res_tail = snap_res_tail[4];
    //     recover_res_tail[0] = recover_tails.alu_res_tail;
    //     recover_res_tail[1] = recover_tails.cmp_res_tail;
    //     recover_res_tail[2] = recover_tails.mult_res_tail;
    //     recover_res_tail[3] = recover_tails.div_res_tail;
    //     recover_res_tail[4] = recover_tails.ld_st_res_tail;
    // end

    logic     [$clog2(LSQ_DEPTH):0]   snap_lsq_tail;
    logic     [$clog2(LSQ_DEPTH):0]   recover_lsq_tail;
    
    
    logic [63:0] order;
    rvfi_val_t rvfi_out;//
    rvfi_val_t rvfi_in;//rat to rvfi_rob
    logic ready_for_commit;

    IF_ID_reg_t         IF_ID_reg;
    ID_RE_reg_t         ID_RE_reg;
    res_station_t res_station_entry;
    //Stall Singals
    logic res_full[5];
    logic IF_stall, RE_stall, DE_stall;
    
    //flush signals
    logic flush;
    assign flush = early_flush;
    // logic   flush_latch;
    // assign flush = '0;//TODO
    logic rs1_valid_forward, rs2_valid_forward;
    //Decode -> RAT 
    logic [4:0] rat_rs1, rat_rs2;
    //Decode -> Free List
    logic free_list_empty, free_list_deq;
    //Free List -> Rename/Dipatch
    logic   [$clog2(P_REG_NUM)-1:0] free_list_pd;

    //Rename -> Dispatch
    logic [4:0] rd_dispatch;
    logic [$clog2(P_REG_NUM) -1 :0] pd_dispatch;
    logic regf_we_dispatch;
    
    //RAT -> Rename/Dispatch
    logic ps1_valid, ps2_valid;
    logic [$clog2(P_REG_NUM)-1 :0] ps1, ps2;
    //ROB <-> Rename/Dispatch
    
    logic [$clog2(ROB_DEPTH):0] rob_head;
    logic rob_full;
    logic rob_enq;
    logic [4:0] rob_rd;
    logic [$clog2(P_REG_NUM)-1 :0] rob_pd;
    //CDB -> ROB
    logic commit_valid;
    logic [$clog2(ROB_DEPTH)-1:0] rob_num_commit_ready;
    //ROB -> RRF
    logic rrf_regf_we;
    logic [5:0] rrf_pd_in;
    logic [4:0] rrf_rd_in;
    //RRF -> Freelist
    logic fl_enq;
    logic [5:0] fl_pd_in;

    //CDB: TODO Change Struct of CDB later
    dependency_t depen_cdb[CDB_NUM];
    CDB_t           CDB[CDB_NUM];
    logic           cdb_we_array[CDB_NUM];
    logic  [4:0]    cdb_rd_array[CDB_NUM];
    logic  [$clog2(ROB_DEPTH)-1:0]  cdb_robnum_array[CDB_NUM];    //param this by Depth of rob
    logic  [$clog2(P_REG_NUM)-1:0]cdb_pd_array[CDB_NUM];
    logic  [31:0]   cdb_funct_out_array[CDB_NUM];
    logic  [31:0]   cdb_rs1_array[CDB_NUM];
    logic  [31:0]   cdb_rs2_array[CDB_NUM];
    logic  [31:0]   cdb_pc_array[CDB_NUM];
    logic  [31:0]   lsq_cdb_mem_addr;
    logic  [3:0]    lsq_cdb_mem_rmask;
    logic  [3:0]    lsq_cdb_mem_wmask;
    logic  [31:0]   lsq_cdb_mem_rdata;
    logic  [31:0]   lsq_cdb_mem_wdata;
     
    funct_unit_out_t    alu_unit_out, cmp_unit_out, mult_unit_out, div_unit_out, adder_unit_out;
    
    // jalr logic
    logic               jalr_stall, jalr_stall_latched;
    // lsq logic
    logic               lsq_full;
    assign lsq_full = load_queue_full || store_queue_full;
    // logic               lsq_out_valid;
    cache_interface_t   lsq_output_to_cache;
    CDB_t               lsq_output_to_cdb;
    logic               d_cache_resp;
    logic   [31:0]      d_cache_data;
    //cp3: branch
    logic [31:0] pc_out; //next pc 
    logic [31:0] cdb_pc_next[CDB_NUM]; //current pc
    logic br_en[CDB_NUM]; //branch enable
    logic   [$clog2(P_REG_NUM) -1 :0]   restore_rat[32]; 
    // logic   alu_out_valid, cmp_out_valid, mult_out_valid, div_out_valid;
    //####################
    EBR EBR(
        .clk(clk),
        .rst(rst),
        .rat_map(snap_rat_map),
        .snap_rob_tail(rob_tail),
        .tag_in(tag_in), // 
        .free_list_head(free_list_head),//directly from free_list
        .snap(snap),    //from issue_execute
        .early_flush(early_flush),//early_flush), 
        .recover_rat(recover_rat),
        .recover_rob_tail(recover_rob_tail),
        .recover_free_list_head(recover_free_list_head),
        .EBR_recovery_idx(recover_idx),//EBR_recovery_idx),
        .dependency_out(dependency_out),
        .rd_cdb(cdb_rd_array),
        .pd_cdb(cdb_pd_array),
        .regf_we_cdb(cdb_we_array),
        .*
    );
    //####################
    IF Fetch_stage(
         .*,
        .IF_ID_reg(IF_ID_reg),
        .dc_to_bmem_rdata(bmem_wdata)
    );
    Decode Decode_stage(
        .*,
        .rat_rs1(rat_rs1),
        .rat_rs2(rat_rs2),
        .free_list_empty(free_list_empty),
        .free_list_deq(free_list_deq),
        .ID_RE_reg(ID_RE_reg)
    );
    Rename Rename_stage(
        .free_list_pd(free_list_pd),
        .rob_tail(rob_tail[$clog2(ROB_DEPTH):0]),
        .rob_full(rob_full),
        .rob_enq(rob_enq),
        .rob_rd(rob_rd),
        .rob_pd(rob_pd),
        // .ps1_valid(ps1_valid),
        // .ps2_valid(ps2_valid),
        // .ps1(ps1),
        // .ps2(ps2),
        .rd_dispatch(rd_dispatch),
        .pd_dispatch(pd_dispatch),
        .regf_we_dispatch(regf_we_dispatch),
         .load_queue_tail(snap_tails.load_queue_tail),
        .store_queue_tail(snap_tails.store_queue_tail),
        .*
    );
    RAT Rat(
        //Decode -> RAT
        .rs1(rat_rs1),
        .rs2(rat_rs2),
        //RAT -> Rename/Dispatch
        .ps1_valid(ps1_valid),
        .ps2_valid(ps2_valid),
        .ps1(ps1),
        .ps2(ps2),
        //Dispatch/Rename -> RAT
        .rd_dispatch(rd_dispatch),
        .pd_dispatch(pd_dispatch),
        .regf_we_dispatch(regf_we_dispatch),
        //CDB -> RAT
        .rd_cdb(cdb_rd_array),
        .pd_cdb(cdb_pd_array),
        .regf_we_cdb(cdb_we_array),
        .*
    );
    ROB ROB(
        .enq(rob_enq),
        .rd_in(rob_rd),
        .pd_in(rob_pd),
        .pc_in(cdb_pc_next),
        .free_rob_num(rob_tail),
        .head(rob_head),
        .full(rob_full),
        .regf_we_cdb(cdb_we_array),
        .rob_num_commit_ready(cdb_robnum_array),
        .deq(rrf_regf_we),
        .pd_out(rrf_pd_in),
        .rd_out(rrf_rd_in),
        .empty(),
       
        .*
    );
    rvfi_rob rvfi_rob(
        .enq(rob_enq),
        .regf_we_cdb(cdb_we_array),
        .rob_num_commit_ready(cdb_robnum_array),
        .rvfi_output_cdb(cdb_funct_out_array),
        .rs1_cdb(cdb_rs1_array),
        .rs2_cdb(cdb_rs2_array),
        .addr_cdb(lsq_cdb_mem_addr),
        .rmask_cdb(lsq_cdb_mem_rmask),
        .wmask_cdb(lsq_cdb_mem_wmask),
        .rdata_cdb(lsq_cdb_mem_rdata),
        .wdata_cdb(lsq_cdb_mem_wdata),
        .ready_for_commit(ready_for_commit),
        .rvfi_out(rvfi_out),
        
        .*
    );

    Freelist Freelist(
        .empty(free_list_empty),
        .deq(free_list_deq),
        .pd_out(free_list_pd),
        .enq(fl_enq ),
        .pd_in(fl_pd_in),
        .full(),
        .flush(flush),
        .*
    );
    RRF RRF(
        .regf_we        (rrf_regf_we),
        .pd_in          (rrf_pd_in),
        .rd_in          (rrf_rd_in),
        .pd_out         (fl_pd_in),
        .enq            (fl_enq),
        .*
    );

    write_back write_back(
        .*,
        .CDB(CDB[0:3])
    );

    //assign CDB array
    always_comb begin
        for(int i = 0; i < CDB_NUM; i++) begin
            cdb_we_array[i] = CDB[i].we;
            cdb_rd_array[i] = CDB[i].rd;
            cdb_pd_array[i] = CDB[i].pd;
            cdb_robnum_array[i] = CDB[i].rob_idx[$clog2(ROB_DEPTH)-1:0];
            cdb_funct_out_array[i] = CDB[i].funct_out;
            cdb_rs1_array[i] = CDB[i].rvfi_val.src_1_v;
            cdb_rs2_array[i] = CDB[i].rvfi_val.src_2_v;
            cdb_pc_array[i] = CDB[i].pc_next;            
            br_en[i] = CDB[i].br_en;
            cdb_pc_next[i] = CDB[i].pc_next;
            depen_cdb[i] = CDB[i].depen;
        end
        // fix pc_next for load/store
        // cdb_pc_next[4] = CDB[4].pc_next;
        lsq_cdb_mem_addr = CDB[4].rvfi_val.mem_addr;
        lsq_cdb_mem_rmask = CDB[4].rvfi_val.mem_rmask;
        lsq_cdb_mem_wmask = CDB[4].rvfi_val.mem_wmask;
        lsq_cdb_mem_rdata = CDB[4].rvfi_val.mem_rdata;
        lsq_cdb_mem_wdata = CDB[4].rvfi_val.mem_wdata;
    end

    // detect jalr stall
    always_ff @ (posedge clk) begin
        if (rst) begin
            jalr_stall_latched <= '0;
        end else begin
            if (jalr_stall)
                jalr_stall_latched <= 1'b1;
            
            if ( jarl_stall_release_reg || flush)
                jalr_stall_latched <= 1'b0;
        end
    end
        

    Issue_Execute Issue_Execute_stage(
        .*, // clk, rst, pd_s, pd_v, all funct_unit_out
        .issue_execute_input(res_station_entry),
        .cdb_we_array(cdb_we_array),
        // .regf_we_0(CDB[0].we),
        // .regf_we_1(CDB[1].we),
        // .regf_we_2(CDB[2].we),
        // .regf_we_3(CDB[3].we)
        .snap_res_tail(snap_tails.res_tails),
        .recover_res_tail(recover_tails.res_tails)

    );

    LSQ lsq(
        .*, // clk, rst
        .ufp_resp(d_cache_resp), 
        .ufp_rdata(d_cache_data), 
        .in(adder_unit_out),
        .rob_head(rob_head[$clog2(ROB_DEPTH)-1:0]),

        .depen(dependency_out),
        // outputs
        // .full(lsq_full),
        // .out_valid(lsq_out_valid),
        .output_to_cache(lsq_output_to_cache),
        .output_to_CDB(lsq_output_to_cdb),
        .recover_idx( recover_idx),
        .depen_rob(depen_rob),
        .recover_load_tail(recover_tails.load_queue_tail),
        .snap_load_tail(snap_tails.load_queue_tail),
        .recover_store_tail(recover_tails.store_queue_tail),
        .snap_store_tail(snap_tails.store_queue_tail)
    );

    assign CDB[4] = lsq_output_to_cdb;

    

    //connect RVFI
    logic           monitor_valid;
    logic   [63:0]  monitor_order;
    logic   [31:0]  monitor_inst;
    logic   [4:0]   monitor_rs1_addr;
    logic   [4:0]   monitor_rs2_addr;
    logic   [31:0]  monitor_rs1_rdata;
    logic   [31:0]  monitor_rs2_rdata;
    logic   [4:0]   monitor_rd_addr;
    logic   [31:0]  monitor_rd_wdata;
    logic   [31:0]  monitor_pc_rdata;
    logic   [31:0]  monitor_pc_wdata;
    logic   [31:0]  monitor_mem_addr;
    logic   [3:0]   monitor_mem_rmask;
    logic   [3:0]   monitor_mem_wmask;
    logic   [31:0]  monitor_mem_rdata;
    logic   [31:0]  monitor_mem_wdata;


    // use RVFI ROB
    assign monitor_valid     = ready_for_commit;
    assign monitor_order     = order;
    assign monitor_inst      = rvfi_out.inst;
    assign monitor_rs1_addr  = rvfi_out.src_1_s;
    assign monitor_rs2_addr  = rvfi_out.src_2_s;
    assign monitor_rs1_rdata = rvfi_out.src_1_v;  
    assign monitor_rs2_rdata = rvfi_out.src_2_v;
    assign monitor_rd_addr   = rvfi_out.rd_s;
    assign monitor_rd_wdata  = rvfi_out.rvfi_output;
    assign monitor_pc_rdata  = rvfi_out.pc;  
    assign monitor_pc_wdata  = rvfi_out.pc_next;
    assign monitor_mem_addr  = rvfi_out.mem_addr;
    assign monitor_mem_rmask = rvfi_out.mem_rmask;
    assign monitor_mem_wmask = rvfi_out.mem_wmask;
    assign monitor_mem_rdata = rvfi_out.mem_rdata;
    assign monitor_mem_wdata = rvfi_out.mem_wdata;


    //This is only used to remove warning
    // TODO: default them to suppress warnings, change later
    // assign bmem_wdata = '0;
    // assign bmem_write = '0;
    logic sb;
    assign sb = bmem_ready;

endmodule : cpu

