// import "DPI-C" function string getenv(input string env_name);

module rrf_tb;

    timeunit 1ps;
    timeprecision 1ps;

    // int clock_half_period_ps = getenv("ECE411_CLOCK_PERIOD_PS").atoi() / 2;

    bit clk;
    always #(2ns) clk = ~clk;

    bit rst;

    int timeout = 4000; // in cycles, change according to your needs

    // //##########################################
    // //FIFO test begin
    logic regf_we, enq;

    logic [ 5:0] pd_in;
    logic [ 4:0] rd_in;

    // logic [ 1:0] rob_num_commit_ready;
    // logic        commit_valid;

    logic [ 5:0] pd_out;
    // logic [ 4:0] rd_out;

    logic [11:0]    qinputs;
    assign {regf_we,pd_in,rd_in} = qinputs;
    RRF #() Q_for_test (
        .clk            (clk),
        .rst            (rst),
        .regf_we        (regf_we),
        .pd_in          (pd_in),
        .rd_in          (rd_in),
        .pd_out         (pd_out),
        .enq            (enq)
    );
    task Qtest();
        @(posedge clk);
        qinputs <= { '0,6'b000001,5'b10001};
        @(posedge clk);
        qinputs <= { '0,6'b000001,5'b10101};
        @(posedge clk);
        qinputs <= { '1,6'b100000,5'b00001};
        @(posedge clk);
        qinputs <= { '1,6'b110011,5'b00010};
        @(posedge clk);
        qinputs <= { '1,6'b101000,5'b00011};
        @(posedge clk);
        qinputs <= { '1,6'b111000,5'b00010};
        @(posedge clk);
        qinputs <= { '1,6'b010100,5'b00011};
        

        
        
        #10ns;  
    endtask
    // //rob test end
    // //##########################################
    // `include "rvfi_reference.svh"

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
        // rob Test
        Qtest();
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