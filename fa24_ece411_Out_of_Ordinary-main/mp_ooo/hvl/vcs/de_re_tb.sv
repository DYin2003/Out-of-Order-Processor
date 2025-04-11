// import "DPI-C" function string getenv(input string env_name);

module de_re_tb;

    timeunit 1ps;
    timeprecision 1ps;
    import CDB_types::*;
    // int clock_half_period_ps = getenv("ECE411_CLOCK_PERIOD_PS").atoi() / 2;

    bit clk;
    always #(2ns) clk = ~clk;

    bit rst;

    int timeout = 4000; // in cycles, change according to your needs
    // `include "rvfi_reference.svh"
    logic   [31:0]      pc;
    logic   [31:0]      inst;
    logic   [$clog2(64) -1 :0]   ps1;
    logic   [$clog2(64) -1 :0]   ps2;
    logic           ps1_valid;
    logic           ps2_valid;
    logic   [4:0]   rs1;
    logic   [4:0]   rs2;
    // write from Dispatch/Rename( From Free List)
    logic   [4:0]   rd_dispatch;
    logic   [$clog2(64) -1 :0]   pd_dispatch;
    // write from CDB: check if pd = pd_cdb, if so set valid 
    logic   [4:0]   rd_cdb;
    logic   [$clog2(64) -1 :0]   pd_cdb;
    logic   regf_we_dispatch;
    logic   regf_we_cdb;
    logic   [4:0]   rob_rd;
    logic   [$clog2(64)-1:0] rob_pd;
    
    res_station_t res_station_entry;
    // unit testing
    logic   [$clog2(64) -1 :0]   free_list_pd;
    logic   [$clog2(32)-1:0]   rob_tail;
    ID_RE_reg_t   ID_RE_reg;
    logic   rob_full;
    logic   rob_enq;
    logic               free_list_deq;

    assign rob_full = '0;
    assign rob_tail = '0;
    RAT     rat_test(
        .*
    );
    Decode deocde_test(

        .free_list_empty('1),
        .rat_rs1(rs1),
        .rat_rs2(rs2),
        .*
    );
    Rename rename_test(
        
        .*
    );
    
    task DE_RE_test();
        @(posedge clk);
        pc <= 32'h1eceb000;
        inst <= 32'h003100b3; //add x1,x2,x3
        {rd_cdb,pd_cdb,regf_we_cdb}<= '0;
        @(posedge clk);
        free_list_pd <= 6'h20;
        @(posedge clk);
        inst<= 32'h 0241c133; // div x2, x3, x4 
        free_list_pd <= 6'h21;
        @(posedge clk);
        inst<= 32'h 026285b3;    //mul x11,x5,x6
        free_list_pd <= 6'h22;
        @(posedge clk);
        inst<= 32'h 06208163;    //mul x11,x5,x6
        free_list_pd <= 6'h23;
        @(posedge clk);
        inst<=32'h 06208163;
    endtask

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
        // FIFO Test
        DE_RE_test();
        #10ns;
        $finish;
    end

    always @(posedge clk) begin
        
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $finish;
        end
        
        timeout <= timeout - 1;
    end

endmodule
