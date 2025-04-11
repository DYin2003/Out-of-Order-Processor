module Issue_Execute
import CDB_types::*;
import rv32i_types::*;
#(
    // parameter P_REG_NUM = 64,
    // parameter CDB_NUM = 5 
)
(
    input   logic   clk,
    input   logic   rst,
   
    // pd broadcast from CDB
    input   logic                               cdb_we_array[CDB_NUM],
    input   logic   [$clog2(P_REG_NUM) -1:0]    cdb_pd_array[CDB_NUM], 
    input   logic   [31:0]                      cdb_funct_out_array[CDB_NUM],
    // take input from the ID RE stage
    input   res_station_t       issue_execute_input,
    input   logic               lsq_full,

    output logic up,
    // input   logic               RE_stall,
    input   logic               flush,
    // four functional unit outputs 
    output  funct_unit_out_t    alu_unit_out,
    output  funct_unit_out_t    cmp_unit_out,
    output  funct_unit_out_t    mult_unit_out,
    output  funct_unit_out_t    div_unit_out,
    output  funct_unit_out_t    adder_unit_out,
    // output  logic   alu_out_valid, cmp_out_valid, mult_out_valid, div_out_valid

    output  logic               res_full[5],

    //FROM EBR 
    input   dependency_t dependency_out,
    output   logic early_flush,
    output  [31:0] pc_out,
    output  logic [$clog2(ROB_DEPTH):0] tag_in, 
    output  logic snap,
    output  logic  [$clog2(EBR_NUM)-1:0] recover_idx, //
    output  logic  [$clog2(ROB_DEPTH):0] depen_rob, //
    output  res_tails_t snap_res_tail,
    //output to be restored when misspredict
    input  res_tails_t recover_res_tail,
    
    output cmp_to_IF cmp_in,
    output logic jarl_stall_release_reg
);
    // logic  [(EBR_NUM)-1:0] [$clog2(ROB_DEPTH):0] rob_tags;
    logic early_flush_inst;
    // for flushing Reservation Station
    logic  jarl_stall_release;
    assign jarl_stall_release_reg = jarl_stall_release;
    // logic  [$clog2(EBR_NUM)-1:0] depen_idx;//to res
    
    logic early_flush_reg;                  // from CMP
    logic [31:0] pc_next_reg;               // to cpu IF stage
    dependency_t cmp_depen;
    //

    // assign flush = early_flush_reg;     // to res station
    assign early_flush = early_flush_reg;//output to cpu
    assign pc_out  = pc_next_reg;
    assign tag_in = issue_execute_input.rob_tail[$clog2(ROB_DEPTH):0];
    assign snap = issue_execute_input.ctrl_block.is_br && issue_execute_input.valid != '0 && ! early_flush_inst; 
    
    assign recover_idx = cmp_depen.idx;   //from CMP to res station
    assign depen_rob = cmp_depen.rob_tags[recover_idx];   //
   
    res_station_t       issue_execute_input_processed;
    //four control for the four modules
    logic   alu_res_write, cmp_res_write, mult_res_write, div_res_write, ld_st_res_write;
    logic   alu_res_full, cmp_res_full, mult_res_full, div_res_full, ld_st_res_full;
    logic   alu_ready, cmp_ready, mult_ready, div_ready, adder_ready;
    assign res_full[0] = alu_res_full;
    assign res_full[1] = cmp_res_full;
    assign res_full[2] = mult_res_full;
    assign res_full[3] = div_res_full;
    assign res_full[4] = ld_st_res_full;

    // logic   agu_res_wrtie, agu_res_full,agu_ready;
    //* trying to use pipeline reg to improve the critical path
    // logic   alu_res_valid, cmp_res_valid, mult_res_valid, div_res_valid;
    // res_station_t   alu_res_out, cmp_res_out, mult_res_out, div_res_out;
    IS_EX_reg_t     alu_reg_next, alu_reg;
    IS_EX_reg_t     cmp_reg_next, cmp_reg;
    IS_EX_reg_t     mult_reg_next, mult_reg;
    IS_EX_reg_t     div_reg_next, div_reg;
    IS_EX_reg_t     ld_st_reg_next, ld_st_reg;
    // IS_EX_reg_t     agu_reg_next, agu_reg;

    
    // four register file outputs for four functional units
    logic   [5:0]   rs1_s [5];
    logic   [5:0]   rs2_s [5];
    logic   [31:0]  rs1_v [5];
    logic   [31:0]  rs2_v [5];

    always_ff @(posedge clk) begin
        if (rst) begin
            // set all the pipeline registers to zero
            alu_reg <= '0;
            cmp_reg <= '0;
            mult_reg <= '0;
            div_reg <= '0;
            ld_st_reg <= '0;
            // agu_reg <= '0;
        end
        else begin
            // only update the pipeline registers if the ready signal is high
            if (alu_ready)
                alu_reg <= alu_reg_next;
            if (cmp_ready)
                cmp_reg <= cmp_reg_next;
            if (adder_ready)
                ld_st_reg <= ld_st_reg_next;

            // if not ready, keep the pipeline register to zero
            if (mult_ready)
                mult_reg <= mult_reg_next;
            else
                mult_reg <= '0;

            if (div_ready)
                div_reg <= div_reg_next;
            else
                div_reg <= '0;
            // if(agu_ready)
            //     agu_reg <= agu_reg_next;
            // else
            //     agu_reg <= '0;

        end
    end
    
    always_comb begin

        // TODO: assigned all ready signal to zero for now, change later
        // alu_ready = '0;
        // cmp_ready = '0;
        // mult_ready = '0;
        // div_ready = '0;

        // set defaults
        alu_res_write = '0;
        cmp_res_write = '0;
        mult_res_write = '0;
        div_res_write = '0;
        ld_st_res_write = '0;
        // agu_res_wrtie = '0;

        // don't set any write signal if stall is high
        if (issue_execute_input.valid != '0) begin
        // decide which res station we are writing into
            case(issue_execute_input.ctrl_block.func_unit)
                unit_alu: alu_res_write = '1;
                unit_cmp: cmp_res_write = '1;
                unit_mul: mult_res_write = '1;
                unit_div: div_res_write = '1;
                unit_ld, unit_st: ld_st_res_write = '1;
                // unit_br: agu_res_wrtie = '1;//branch and jump
            endcase
        end
        // issue_execute_input_processed.load_queue_tail = load_queue_tail;
        // issue_execute_input_processed.store_queue_tail = store_queue_tail;
        issue_execute_input_processed = issue_execute_input;
        issue_execute_input_processed.depen = dependency_out;
        // pick up broadcasted data from CDB
        for (int unsigned i = 0; i < CDB_NUM; i++) begin

            if (cdb_pd_array[i] == issue_execute_input_processed.ps1_idx
                && cdb_we_array[i])
                issue_execute_input_processed.ps1_valid = '1;

            if (cdb_pd_array[i] == issue_execute_input_processed.ps2_idx
                && cdb_we_array[i])
                issue_execute_input_processed.ps2_valid = '1;

        end
    end

    
    always_comb begin
        // assign res station outputs to the register file inputs
        rs1_s[0] = alu_reg_next.res_out.ps1_idx;
        rs2_s[0] = alu_reg_next.res_out.ps2_idx;
        rs1_s[1] = cmp_reg_next.res_out.ps1_idx;
        rs2_s[1] = cmp_reg_next.res_out.ps2_idx;
        rs1_s[2] = mult_reg_next.res_out.ps1_idx;
        rs2_s[2] = mult_reg_next.res_out.ps2_idx;
        rs1_s[3] = div_reg_next.res_out.ps1_idx;
        rs2_s[3] = div_reg_next.res_out.ps2_idx;
        rs1_s[4] = ld_st_reg_next.res_out.ps1_idx;
        rs2_s[4] = ld_st_reg_next.res_out.ps2_idx;
        

    end

    // instantiate the four functional units
    ALU alu(
        .*, // clk, rst
        .input_valid    (alu_reg.res_valid),
        .a              (rs1_v[0]),
        .b              (rs2_v[0]),
        .res_station_out(alu_reg.res_out),

        // outputs
        .ready          (alu_ready),
        // .output_valid   (alu_out_valid),
        .alu_out        (alu_unit_out)
    );

    CMP cmp(
        .*, // clk, rst
        .input_valid    (cmp_reg.res_valid),
        .a              (rs1_v[1]),
        .b              (rs2_v[1]),
        .res_station_out(cmp_reg.res_out),

        // outputs
        .ready          (cmp_ready),
        // .output_valid   (cmp_out_valid),
        .cmp_out        (cmp_unit_out)
    );

    MULT mult(
        .*, // clk, rst
        .input_valid    (mult_reg.res_valid),
        .a              (rs1_v[2]),
        .b              (rs2_v[2]),
        .res_station_out(mult_reg.res_out),

        // outputs
        .ready          (mult_ready),
        // .output_valid   (mult_out_valid),
        .mult_out       (mult_unit_out)
    );

    DIV DIV_UNIT(
        .*, // clk, rst
        .input_valid    (div_reg.res_valid),
        .a              (rs1_v[3]),
        .b              (rs2_v[3]),
        .res_station_out(div_reg.res_out),

        // outputs
        .ready          (div_ready),
        // .output_valid   (div_out_valid),
        .div_out        (div_unit_out)
    );

    ADDER adder(
        .*, // clk, rst
        .clk            (clk),
        .rst            (rst),
        .input_valid    (ld_st_reg.res_valid),
        .lsq_full       (lsq_full),
        .a              (rs1_v[4]),
        .b              (rs2_v[4]),
        .res_station_out(ld_st_reg.res_out),

        // outputs
        .ready          (adder_ready),
        // .output_valid   (alu_out_valid),
        .adder_out      (adder_unit_out)
    );

    // instantiate the four res stations
    res_station #(.RES_DEPTH(ALU_RES_DEPTH)) alu_res_station(
        .*, //clk, rst, pd_0 - pd_3, 
        .write      (alu_res_write),
        .ready      (alu_ready),
        .in         (issue_execute_input_processed),

        // o/p
        .full       (alu_res_full),
        .out_valid  (alu_reg_next.res_valid),
        .out        (alu_reg_next.res_out),
        .snap_tail(snap_res_tail.alu_res_tail),
        .recover_tail(recover_res_tail.alu_res_tail)

    );

    cmp_res_station #(.RES_DEPTH(CMP_RES_DEPTH)) cmp_res_station(
        .*, //clk, rst, pd_0 - pd_3, 
        .write      (cmp_res_write),
        .ready      (cmp_ready),
        .in         (issue_execute_input_processed),

        // o/p
        .full       (cmp_res_full),
        .out_valid  (cmp_reg_next.res_valid),
        .out        (cmp_reg_next.res_out),
        .snap_tail(snap_res_tail.cmp_res_tail),
        .recover_tail(recover_res_tail.cmp_res_tail)

    );

    res_station #(.RES_DEPTH(MULT_RES_DEPTH)) mult_res_station(
        .*, //clk, rst, pd_0 - pd_3, 
        .write      (mult_res_write),
        .ready      (mult_ready),
        .in         (issue_execute_input_processed),

        // o/p
        .full       (mult_res_full),
        .out_valid  (mult_reg_next.res_valid),
        .out        (mult_reg_next.res_out),
        .snap_tail(snap_res_tail.mult_res_tail),
        .recover_tail(recover_res_tail.mult_res_tail)

    );

    res_station #(.RES_DEPTH(DIV_RES_DEPTH)) div_res_station(
        .*, //clk, rst, pd_0 - pd_3, 
        .write      (div_res_write),
        .ready      (div_ready),
        .in         (issue_execute_input_processed),

        // o/p
        .full       (div_res_full),
        .out_valid  (div_reg_next.res_valid),
        .out        (div_reg_next.res_out),
        .snap_tail(snap_res_tail.div_res_tail),
        .recover_tail(recover_res_tail.div_res_tail)

    );

    ld_st_res_station ld_st_res_station(
        .*, //clk, rst, pd_0 - pd_3, 
        .write      (ld_st_res_write),
        .ready      (adder_ready),
        .in         (issue_execute_input_processed),

        // o/p
        .full       (ld_st_res_full),
        .out_valid  (ld_st_reg_next.res_valid),
        .out        (ld_st_reg_next.res_out),
        .snap_tail(snap_res_tail.ld_st_res_tail),
        .recover_tail(recover_res_tail.ld_st_res_tail)
    );

    phys_reg_file phys_reg_file(
        .* //clk, rst, regf_we, all pd_v, pd_s, rs1_v, rs2_v
    );

    
endmodule
