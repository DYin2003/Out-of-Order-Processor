import "DPI-C" function string getenv(input string env_name);

module cacheline_adapter_tb;

    timeunit 1ps;
    timeprecision 1ps;

    int clock_half_period_ps = getenv("ECE411_CLOCK_PERIOD_PS").atoi() / 2;

    bit clk;
    always #(clock_half_period_ps) clk = ~clk;

    bit rst;

    int timeout = 10000000; // in cycles, change according to your needs

    mem_itf_banked bmem_itf(.*);
    banked_memory banked_memory(.itf(bmem_itf));

    // mon_itf #(.CHANNELS(8)) mon_itf(.*);
    // monitor #(.CHANNELS(8)) monitor(.itf(mon_itf));

    // cpu dut(
    //     .clk            (clk),
    //     .rst            (rst),

    //     .bmem_addr  (bmem_itf.addr  ),
    //     .bmem_read  (bmem_itf.read  ),
    //     .bmem_write (bmem_itf.write ),
    //     .bmem_wdata (bmem_itf.wdata ),
    //     .bmem_ready (bmem_itf.ready ),
    //     .bmem_raddr (bmem_itf.raddr ),
    //     .bmem_rdata (bmem_itf.rdata ),
    //     .bmem_rvalid(bmem_itf.rvalid)
    // );

    logic               dfp_resp;
    logic   [255:0]     dfp_data;

    cacheline_adapter dut(
        .clk            (clk),
        .rst            (rst),

        // inputs
        .rdata          (bmem_itf.rdata),
        .rvalid         (bmem_itf.rvalid),

        // outputs
        .dfp_resp       (dfp_resp),
        .dfp_rdata      (dfp_data)    
    );

    // `include "rvfi_reference.svh"

    task cacheline_adapter_test();
        bmem_itf.write <= '0;
        bmem_itf.addr <= 32'h1eceb000;
        bmem_itf.read <= 1'b1;

    endtask

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
        cacheline_adapter_test();

        repeat (20) @(posedge clk);
        $finish;

    end

    always @(posedge clk) begin
        // for (int unsigned i=0; i < 8; ++i) begin
        //     if (mon_itf.halt[i]) begin
        //         $finish;
        //     end
        // end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $finish;
        end
        // if (mon_itf.error != 0) begin
        //     repeat (5) @(posedge clk);
        //     $finish;
        // end
        if (bmem_itf.error != 0) begin
            repeat (5) @(posedge clk);
            $finish;
        end
        timeout <= timeout - 1;
    end

endmodule
