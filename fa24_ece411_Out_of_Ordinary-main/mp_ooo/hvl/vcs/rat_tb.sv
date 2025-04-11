import "DPI-C" function string getenv(input string env_name);

module rat_tb;

    timeunit 1ps;
    timeprecision 1ps;

    // int clock_half_period_ps = getenv("ECE411_CLOCK_PERIOD_PS").atoi() / 2;

    bit clk;
    always #(2ns) clk = ~clk;

    bit rst;

    int timeout = 4000; // in cycles, change according to your needs
    //  mem_itf_banked mem_itf(.*);
    // dram_w_burst_frfcfs_controller mem(.itf(mem_itf));
    // cpu dut(
    //     .clk            (clk),
    //     .rst            (rst),

    //     .bmem_addr  (mem_itf.addr  ),
    //     .bmem_read  (mem_itf.read  ),
    //     .bmem_write (mem_itf.write ),
    //     .bmem_wdata (mem_itf.wdata ),
    //     .bmem_ready (mem_itf.ready ),
    //     .bmem_raddr (mem_itf.raddr ),
    //     .bmem_rdata (mem_itf.rdata ),
    //     .bmem_rvalid(mem_itf.rvalid)
    // );
    // //##########################################
    // //FIFO test begin
    // read rs1,rs2 from Decode Stage
      
    //output
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
    RAT   rat (
        .*
    );
    task rat_test();
        //###CC1: Read rs1,rs2, should ouput valid 
        @(posedge clk);
        {rs1,rs2} <= {5'd 1,5'd 2};
        {rd_cdb,pd_cdb,regf_we_cdb}<= '0;
        {rd_dispatch,pd_dispatch,regf_we_dispatch} <= '0;
        //###CC2: Map rs1 to pd 32,
        @(posedge clk);
        {rs1,rs2} <= {5'd 0,5'd 0};
        {rd_dispatch,pd_dispatch,regf_we_dispatch} <= {5'd 1, 6'd 32, '1};
        //###CC3: Read rs1 again, should be invalid
         @(posedge clk);
        {rs1,rs2} <= {5'd 1,5'd 2};
        {rd_dispatch,pd_dispatch,regf_we_dispatch} <= '0;
        //##CC4: CDB set valid of rs1 
        @(posedge clk);
        {rs1,rs2} <= {5'd 0,5'd 0};
        {rd_cdb,pd_cdb,regf_we_cdb}<= {5'd1,6'd32,'1};
        //###CC5: Read Rs1 again should be valid 
        @(posedge clk);
        {rs1,rs2} <= {5'd 1,5'd 15};
        {rd_cdb,pd_cdb,regf_we_cdb}<= '0;
        {rd_dispatch,pd_dispatch,regf_we_dispatch} <= '0;
        #10ns;  
    endtask
    // //FIFO test end
    // //##########################################
    // `include "rvfi_reference.svh"

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
        // FIFO Test
        rat_test();
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
