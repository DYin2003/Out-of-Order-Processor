module top_tb;

    timeunit 1ps;
    timeprecision 1ps;

    import CDB_types::*;
    import rv32i_types::*;
    import my_pkg::*;

    localparam string RED         = "\033[31m";  // Red color
    localparam string RESET       = "\033[0m";   // Reset color
    localparam string GREEN       = "\033[32m";  // Green color
    localparam string YELLOW      = "\033[33m";  // Yellow color
    localparam string BLUE        = "\033[34m";  // Blue color
    localparam string MAGENTA     = "\033[35m";  // Magenta color
    localparam string CYAN        = "\033[36m";  // Cyan color
    localparam string BOLD        = "\033[1m";   // Bold text

    // performance counter stuff:
    logic   [63:0]  total_cycles, total_commit_cycles;
    logic   [31:0]  total_if_stalls, total_re_stalls, total_de_stalls;
    logic   [31:0]  total_branches, total_flushes, total_jal_jalr;
    logic   [31:0]  alu_res_count, cmp_res_count, mult_res_count, div_res_count, ld_st_res_count;
    logic   [31:0]  alu_full_count, cmp_full_count, mult_full_count, div_full_count, ld_st_full_count;
    logic   [31:0]  load_stalls, store_stalls, res_full_stalls, rob_full_stalls;
    logic   [31:0]  load_queue_full, store_queue_full, forwarded_count;
    logic   [31:0]  cache_hit_count, cache_miss_count;
    logic           counted, accessed;

    int clock_half_period_ps;
    longint timeout = 64'd100;
    initial begin
        $value$plusargs("CLOCK_PERIOD_PS_ECE411=%d", clock_half_period_ps);
        clock_half_period_ps = clock_half_period_ps / 2;
        $value$plusargs("TIMEOUT_ECE411=%d", timeout);
    end

    bit clk;
    always #(clock_half_period_ps) clk = ~clk;

    bit rst;

    mem_itf_banked mem_itf(.*);
    dram_w_burst_frfcfs_controller mem(.itf(mem_itf));

    mon_itf #(.CHANNELS(8)) mon_itf(.*);
    monitor #(.CHANNELS(8)) monitor(.itf(mon_itf));
    // random_tb random_tb(.itf(mem_itf)); // For randomized testing

    cpu dut(
        .clk            (clk),
        .rst            (rst),

        .bmem_addr  (mem_itf.addr  ),
        .bmem_read  (mem_itf.read  ),
        .bmem_write (mem_itf.write ),
        .bmem_wdata (mem_itf.wdata ),
        .bmem_ready (mem_itf.ready ),
        .bmem_raddr (mem_itf.raddr ),
        .bmem_rdata (mem_itf.rdata ),
        .bmem_rvalid(mem_itf.rvalid)
    );

    `include "rvfi_reference.svh"
    `include "macros/uvm_global_defines.svh"

    task reset_performance_counters();
        total_cycles <= 64'd0;

        total_if_stalls <= 32'd0; 
        total_re_stalls <= 32'd0; 
        total_de_stalls <= 32'd0;

        total_branches <= 32'd0;
        total_flushes <= 32'd0;

        alu_res_count <= 32'd0;
        cmp_res_count <= 32'd0;
        mult_res_count <= 32'd0;
        div_res_count <= 32'd0;
        ld_st_res_count <= 32'd0;

        alu_full_count <= 32'd0;
        cmp_full_count <= 32'd0;
        mult_full_count <= 32'd0;
        div_full_count <= 32'd0;
        ld_st_full_count <= 32'd0;

        load_stalls <= 32'd0;
        store_stalls <= 32'd0;
        res_full_stalls <= 32'd0;
        rob_full_stalls <= 32'd0;

        total_commit_cycles <= 64'd0;
        total_jal_jalr <= 32'd0;
        load_queue_full <= 32'd0;
        store_queue_full <= 32'd0;
        forwarded_count <= 32'd0;

        cache_hit_count <= '0;
        cache_miss_count <= '0;
        counted <= '0;
        accessed <= '0;

        
    endtask

    task print_parameters();
        $display("localparam ARB_NUM =          %3d;", ARB_NUM);
        $display("localparam BURST_NUMBER =     %3d;", BURST_NUMBER);
        $display("localparam BURST_SIZE =       %3d;", BURST_SIZE);
        $display("localparam P_REG_NUM =        %3d;", P_REG_NUM);
        $display("localparam CDB_NUM =          %3d;", CDB_NUM);
        $display("localparam FIFO_DEPTH =       %3d;", FIFO_DEPTH);
        $display("localparam FIFO_DWIDTH =      %3d;", FIFO_DWIDTH);
        $display("localparam FL_DEPTH =         %3d;", FL_DEPTH);
        $display("localparam ALU_RES_DEPTH =    %3d;", ALU_RES_DEPTH);
        $display("localparam CMP_RES_DEPTH =    %3d;", CMP_RES_DEPTH);
        $display("localparam MULT_RES_DEPTH =   %3d;", MULT_RES_DEPTH);
        $display("localparam DIV_RES_DEPTH =    %3d;", DIV_RES_DEPTH);
        $display("localparam LD_ST_RES_DEPTH =  %3d;", LD_ST_RES_DEPTH);
        $display("localparam LRU_WIDTH =        %3d;", LRU_WIDTH);
        $display("localparam S_INDEX =          %3d;", S_INDEX);
        $display("localparam LSQ_DEPTH =        %3d;", LSQ_DEPTH);
        $display("localparam ROB_DEPTH =        %3d;", ROB_DEPTH);
        $display("localparam VALIDARR_WIDTH =   %3d;", VALIDARR_WIDTH);
        $display("localparam WB_CDB_NUM =       %3d;", WB_CDB_NUM);
        $display("localparam div_inst_num_cyc = %3d;", div_inst_num_cyc);
        $display("localparam mult_inst_num_cyc =%3d;", mult_inst_num_cyc);
        $display("localparam LOAD_QUEUE_DEPTH = %3d;", LOAD_QUEUE_DEPTH);
        $display("localparam STORE_QUEUE_DEPTH =%3d;", STORE_QUEUE_DEPTH);
    endtask

    task print_performance_counters();
        // set color
        $display(" \n \n \n%s", BLUE);

        // print performance counter info
        // print total cycles
        $display("%s", BOLD);
        $display("Printing Performance Counter Info:");
        $display("%s%s", RESET, BLUE);
        $display("Total cycles:         %-10d, IPC = %-10f", total_cycles, real'(total_commit_cycles)/real'(total_cycles));
        $display("Total instructions:   %-10d", total_commit_cycles);

        // print current parameters
        $display("%s", BOLD);
        $display("\nParameters:");
        $display("%s%s", RESET, BLUE);
        print_parameters();
        

        // print stall info
        $display("%s", BOLD);
        $display(" \nStall Stats:");
        $display("%s%s", RESET, BLUE);
        $display("Total IF stall (inst queue empty) cycles: %d, percent of total cycles:    %d%%", 
                 total_if_stalls, total_if_stalls*100/total_cycles);
        $display("Total RE stall cycles:                    %d, percent of total cycles:    %d%%",
                 total_re_stalls, total_re_stalls*100/total_cycles);
        $display("Cycles stalled because of ROB full:       %d, percent of RE_stall cycles: %d%%",
                 rob_full_stalls, rob_full_stalls*100/total_re_stalls);
        $display("Cycles stalled because of RES full:       %d, percent of RE_stall cycles: %d%%",
                 res_full_stalls, res_full_stalls*100/total_re_stalls);

        $display("Total DE stall (free list empty)  cycles: %d, percent of total cycles:    %d%%",
                 total_de_stalls, total_de_stalls*100/total_cycles);


        // print branch info
        $display("%s", BOLD);
        $display(" \nBranch Stats:");
        $display("%s%s", RESET, BLUE);
        $display("Total branches: %d", total_branches);
        $display("Total jal/jalr: %d", total_jal_jalr);
        $display("Total flushes:  %d", total_flushes);
        $display("Prediction accuracy: %d%%", 100 - (total_flushes - total_jal_jalr)*100/(total_branches));


        // print res station info
        $display("%s", BOLD);
        $display("\nRes Station Stats:");
        $display("%s%s", RESET, BLUE);
        $display("ALU res station usage:        %d%%", alu_res_count* 100 /(total_cycles * ALU_RES_DEPTH));
        $display("CMP res station usage:        %d%%", cmp_res_count* 100 /(total_cycles * CMP_RES_DEPTH));
        $display("MULT res station usage:       %d%%", mult_res_count* 100 /(total_cycles * MULT_RES_DEPTH));
        $display("DIV res station usage:        %d%%", div_res_count* 100 /(total_cycles * DIV_RES_DEPTH));
        $display("LD/ST res station usage:      %d%%", ld_st_res_count* 100 /(total_cycles * LD_ST_RES_DEPTH));
        // print full res station info
        $display("ALU res station full cycles:  %d", alu_full_count);
        $display("CMP res station full cycles:  %d", cmp_full_count);
        $display("MULT res station full cycles: %d", mult_full_count);
        $display("DIV res station full cycles:  %d", div_full_count);
        $display("LD/ST res station full cycles:%d", ld_st_full_count);

        // print memory info
        $display("%s", BOLD);
        $display("\nMemory Stats:");
        $display("%s%s", RESET, BLUE);

        // print load and store stall info
        $display("Total load stall cycles:      %d, percent of total cycles: %d%%", 
                 load_stalls, load_stalls*100/total_cycles);
        $display("Total store stall cycles:     %d, percent of total cycles: %d%%",
                 store_stalls, store_stalls*100/total_cycles);

        $display("Cache hits: %d", cache_hit_count);
        $display("Cache misses: %d", cache_miss_count);
        $display("Cache hit rate: %d%%", cache_hit_count*100/(cache_hit_count+cache_miss_count));
        // $display("Total load queue full cycles: %d, percent of total cycles: %d%%",
        //          load_queue_full, load_queue_full*100/total_cycles);
        // $display("Total store queue full cycles:%d, percent of total cycles: %d%%",
        //          store_queue_full, store_queue_full*100/total_cycles);
        // $display("Total forwarded count:        %d", forwarded_count);



        // reset color
        $display(" \n \n \n%s", RESET);

    endtask

    logic   [3:0]   prev_r_mask, prev_w_mask;

    always @(posedge clk) begin
        if (!rst) begin
            // count total cycles
            total_cycles <= total_cycles + 1;
            if (dut.monitor_valid) begin
                total_commit_cycles <= total_commit_cycles + 1;
            end

            // count total stalls
            if (dut.Fetch_stage.IF_stall) begin
                total_if_stalls <= total_if_stalls + 1;
            end
            if (dut.Fetch_stage.RE_stall) begin
                total_re_stalls <= total_re_stalls + 1;
                if (dut.Rename_stage.rob_full)
                    rob_full_stalls <= rob_full_stalls + 1;
            end
            if (dut.Fetch_stage.DE_stall) begin
                total_de_stalls <= total_de_stalls + 1;
            end

            // count total branches
            if (dut.rvfi_out.inst[6:0] == op_b_br) begin
                total_branches <= total_branches + 1;
            end
            if ((dut.rvfi_out.inst[6:0] == op_b_jal) || 
                (dut.rvfi_out.inst[6:0] == op_b_jalr)) begin
                total_jal_jalr <= total_jal_jalr + 1;
            end

            // count total flushes
            if (dut.flush)
                total_flushes <= total_flushes + 1;

            // count res station usage
            //* this is not completely correct, needs more thoughts
            alu_res_count <= alu_res_count + 
                             dut.Issue_Execute_stage.alu_res_station.tail - 
                             dut.Issue_Execute_stage.alu_res_station.head;

            cmp_res_count <= cmp_res_count +
                             dut.Issue_Execute_stage.cmp_res_station.tail - 
                             dut.Issue_Execute_stage.cmp_res_station.head;

            mult_res_count <= mult_res_count +
                             dut.Issue_Execute_stage.mult_res_station.tail - 
                             dut.Issue_Execute_stage.mult_res_station.head;
            
            div_res_count <= div_res_count +
                             dut.Issue_Execute_stage.div_res_station.tail - 
                             dut.Issue_Execute_stage.div_res_station.head;

            ld_st_res_count <= ld_st_res_count +
                             dut.Issue_Execute_stage.ld_st_res_station.tail - 
                             dut.Issue_Execute_stage.ld_st_res_station.head;

            // count # of cycles marked full
            if (dut.Issue_Execute_stage.alu_res_station.full) begin
                alu_full_count <= alu_full_count + 1;
            end

            if (dut.Issue_Execute_stage.cmp_res_station.full) begin
                cmp_full_count <= cmp_full_count + 1;
            end

            if (dut.Issue_Execute_stage.mult_res_station.full) begin
                mult_full_count <= mult_full_count + 1;
            end

            if (dut.Issue_Execute_stage.div_res_station.full) begin
                div_full_count <= div_full_count + 1;
            end

            if (dut.Issue_Execute_stage.ld_st_res_station.full) begin
                ld_st_full_count <= ld_st_full_count + 1;
            end

            // record load and store stalls
            if ((dut.rvfi_rob.rvfi_tags[dut.rvfi_rob.head[$clog2(ROB_DEPTH)-1:0]].inst[6:0] == op_b_load) && 
                (dut.rvfi_out.valid == 1'b0)) begin
                load_stalls <= load_stalls + 1;
            end

            if ((dut.rvfi_rob.rvfi_tags[dut.rvfi_rob.head[$clog2(ROB_DEPTH)-1:0]].inst[6:0] == op_b_store) && 
                (dut.rvfi_out.valid == 1'b0)) begin
                store_stalls <= store_stalls + 1;
            end

            prev_r_mask <= dut.Fetch_stage.d_cache.ufp_rmask;
            prev_w_mask <= dut.Fetch_stage.d_cache.ufp_wmask;

            if (((dut.Fetch_stage.d_cache.ufp_rmask != '0) &&
                (dut.Fetch_stage.d_cache.ufp_rmask != prev_r_mask)) ||
                ((dut.Fetch_stage.d_cache.ufp_wmask != '0) &&
                (dut.Fetch_stage.d_cache.ufp_wmask != prev_w_mask))
                ) begin
                    accessed <= 1'b1;
                end else begin
                    accessed <= 1'b0;
                end

            if (accessed && dut.Fetch_stage.d_cache.ufp_resp) begin
                cache_hit_count <= cache_hit_count + 1;
                accessed <= 1'b0;
            end else if (accessed) begin
                cache_miss_count <= cache_miss_count + 1;
                accessed <= 1'b0;
            end

            // record stalls because of lsq full
            // if (dut.lsq.load_full) begin
            //     load_queue_full <= load_queue_full + 1;
            // end
            // if (dut.lsq.store_full) begin
            //     store_queue_full <= store_queue_full + 1;
            // end

            // record stalls because of res full (part of RE_stalls)
            if (dut.Rename_stage.res_full_stall) begin
                res_full_stalls <= res_full_stalls + 1;
            end

            // if (dut.lsq.load_queue.forwarded) begin
            //     forwarded_count <= forwarded_count + 1;
            // end
        end
    end

    initial begin
        // $display("%sThis is a red line.%s", RED, RESET);
        run_test("my_test"); // call test
        
        $fsdbDumpfile("dump.fsdb");
        if ($test$plusargs("NO_DUMP_ALL_ECE411")) begin
            $fsdbDumpvars(0, dut, "+all");
            $fsdbDumpoff();
        end else begin
            $fsdbDumpvars(0, "+all");
        end
        reset_performance_counters();
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;

        // repeat (300000) @(posedge clk);
        // $error("Sim timed out");
        // $finish;
    end

    always @(posedge clk) begin
        for (int unsigned i = 0; i < 8; ++i) begin
            if (mon_itf.halt[i]) begin
                print_performance_counters();
                $finish;
            end
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        if (mon_itf.error != 0) begin
            repeat (5) @(posedge clk);
            $fatal;
        end
        if (mem_itf.error != 0) begin
            repeat (5) @(posedge clk);
            $fatal;
        end
        timeout <= timeout - 1;
    end

endmodule
