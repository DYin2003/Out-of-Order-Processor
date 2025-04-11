// import "DPI-C" function string getenv(input string env_name);

module fifo_tb;

    timeunit 1ps;
    timeprecision 1ps;

    // int clock_half_period_ps = getenv("ECE411_CLOCK_PERIOD_PS").atoi() / 2;

    bit clk;
    always #(2ns) clk = ~clk;

    bit rst;

    int timeout = 4000; // in cycles, change according to your needs

    // //##########################################
    // //FIFO test begin
    logic enq,deq;
    logic [ 31:0] qin;
    logic [ 31:0] qout;
    logic [33:0]    qinputs;
    assign {enq,deq,qin} = qinputs;
    fifo  #( .DEPTH(4)) Q_for_test (
        .clk            (clk),
        .rst            (rst),
        .enq            (enq),
        .deq            (deq),
        .din            (qin),
        .dout           (qout),
        .empty          (),
        .full           () 
    );
    task Qtest();
        @(posedge clk);
        qinputs <= {  '1,'0,32'h 111};
        @(posedge clk);
        qinputs <= {  '1,'0, 32'h222};
        @(posedge clk);
        qinputs <= {  '1,'0,32'h 333};
        @(posedge clk);
        qinputs <= {  '1,'0,32'h 444};
        @(posedge clk);
        qinputs <= {  '1,'0,32'h beefbabe};
        @(posedge clk);
        qinputs <= {  '1,'0,32'h ecebcafe};
        @(posedge clk);
        qinputs <= {  '1,'1,32'h cafeeceb};
        @(posedge clk);
        qinputs <= {  '0,'1,32'h abcdefff};
        @(posedge clk);
        qinputs <= {  '1,'1,32'h 555};
        @(posedge clk);
        qinputs <= {  '0,'1,32'h beefbeef};
        @(posedge clk);
        qinputs <= {  '0,'1,32'h eceeeece};
        @(posedge clk);
        qinputs <= {  '0,'1,32'h beefbeef};
        @(posedge clk);
        qinputs <= {  '0,'1,32'h beefbeef};
        @(posedge clk);
        qinputs <= {  '0,'1,32'h beefbeef};
         @(posedge clk);
        qinputs <= {  '1,'0,32'h 666};
        @(posedge clk);
        qinputs <= {  '1,'0, 32'h 777};
        @(posedge clk);
        qinputs <= {  '1,'0,32'h 888};
        @(posedge clk);
        qinputs <= {  '1,'1,32'h 999};
        @(posedge clk);
        qinputs <= {  '0,'1,32'h beefbeef};
        repeat(4)@(posedge clk);// rw when empty
        // qinputs <= {  '0,'1,32'h beefbeef};
        @(posedge clk);
        qinputs <= {  '1,'1,32'h AA};//rw at empty
        @(posedge clk);
        qinputs <= {  '1,'0,32'h BB};
        @(posedge clk);
        qinputs <= {  '1,'0,32'h CC};
        repeat(4)@(posedge clk);//rw when full
        qinputs <= {  '1,'1,32'h beefbeef};

        
        
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
