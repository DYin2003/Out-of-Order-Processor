// // import "DPI-C" function string getenv(input string env_name);

// module rob_tb;

//     timeunit 1ps;
//     timeprecision 1ps;

//     // int clock_half_period_ps = getenv("ECE411_CLOCK_PERIOD_PS").atoi() / 2;

//     bit clk;
//     always #(2ns) clk = ~clk;

//     bit rst;

//     int timeout = 5000; // in cycles, change according to your needs

//     // //##########################################
//     // //FIFO test begin
//     logic enq,deq;

//     logic [ 5:0] pd_in;
//     logic [ 4:0] rd_in;

//     logic [ 3:0] rob_num_commit_ready[5];
//     logic [31:0] pc_in[5];
//     logic        br_en[5];
//     logic        regf_we_cdb[5];
    
//     logic        deq;
//     logic [ 5:0] pd_out;
//     logic [ 4:0] rd_out;
//     logic [3:0]  free_rob_num;
//     logic [3:0]  head;
//     logic [31:0] pc_out;
//     logic        flush;

//     logic [14:0]    qinputs;
//     assign {enq,pd_in,rd_in,pc_in,br_en,regf_we_cdb,rob_num_commit_ready} = qinputs;
//     ROB  #( .DEPTH(4)) Q_for_test (
//         .clk            (clk),
//         .rst            (rst),
//         .enq            (enq),
//         .pd_in          (pd_in),
//         .rd_in          (rd_in),
//         .pc_in          (pc_in),
//         .br_en          (br_en),
//         .commit_valid   (commit_valid),
//         .rob_num_commit_ready         (rob_num_commit_ready),
//         .deq            (deq),
//         .pd_out         (pd_out),
//         .rd_out         (rd_out),
//         .free_rob_num   (),
//         .empty          (),
//         .full           (),
//         .*
//     );
//     task Qtest();
//         @(posedge clk);
//         // qinputs <= {  '1,6'b100000,5'b00001,};
        

//         // @(posedge clk);
//         // qinputs <= {  '1,'0,2'b 00,6'b000001,5'b10001};
//         // @(posedge clk);
//         // qinputs <= {  '1,'0,2'b 00,6'b000010,5'b10101};
//         // @(posedge clk);
//         // qinputs <= {  '1,'0,2'b 00,6'b000011,5'b00111};
//         // @(posedge clk);
//         // qinputs <= {  '1,'0,2'b 00,6'b000100,5'b11000};
//         // @(posedge clk);
//         // qinputs <= {  '1,'1,2'b 00,6'b000101,5'b01010};
//         // @(posedge clk);
//         // qinputs <= {  '1,'0,2'b 01,6'b000110,5'b00000};
//         // @(posedge clk);
//         // qinputs <= {  '1,'0,2'b 00,6'b000111,5'b00101};
//         // @(posedge clk);
//         // qinputs <= {  '1,'0,5'b 01110,'1,64'h00000000ecebcafe,'0};
//         // @(posedge clk);
//         // qinputs <= {  '1,'0,5'b 01110,'0,64'h00000000ecebcafe,'1};
//         // @(posedge clk);
//         // qinputs <= {  '1,'0,5'b 01110,'0,64'h00000000ecebcafe,'0};
//         // // @(posedge clk);
//         // qinputs <= {  '1,'0,32'h beefbabe};
//         // @(posedge clk);
//         // qinputs <= {  '1,'0,32'h ecebcafe};
//         // @(posedge clk);
//         // qinputs <= {  '1,'1,32'h cafeeceb};
//         // @(posedge clk);
//         // qinputs <= {  '0,'1,32'h abcdefff};
//         // @(posedge clk);
//         // qinputs <= {  '1,'1,32'h 555};
//         // @(posedge clk);
//         // qinputs <= {  '0,'1,32'h beefbeef};
//         // @(posedge clk);
//         // qinputs <= {  '0,'1,32'h eceeeece};
//         // @(posedge clk);
//         // qinputs <= {  '0,'1,32'h beefbeef};
//         // @(posedge clk);
//         // qinputs <= {  '0,'1,32'h beefbeef};
//         // @(posedge clk);
//         // qinputs <= {  '0,'1,32'h beefbeef};
//         //  @(posedge clk);
//         // qinputs <= {  '1,'0,32'h 666};
//         // @(posedge clk);
//         // qinputs <= {  '1,'0, 32'h 777};
//         // @(posedge clk);
//         // qinputs <= {  '1,'0,32'h 888};
//         // @(posedge clk);
//         // qinputs <= {  '1,'1,32'h 999};
//         // @(posedge clk);
//         // qinputs <= {  '0,'1,32'h beefbeef};
//         // repeat(4)@(posedge clk);// rw when empty
//         // // qinputs <= {  '0,'1,32'h beefbeef};
//         // @(posedge clk);
//         // qinputs <= {  '1,'1,32'h AA};//rw at empty
//         // @(posedge clk);
//         // qinputs <= {  '1,'0,32'h BB};
//         // @(posedge clk);
//         // qinputs <= {  '1,'0,32'h CC};
//         // repeat(4)@(posedge clk);//rw when full
//         // qinputs <= {  '1,'1,32'h beefbeef};

        
        
//         #10ns;  
//     endtask
//     // //rob test end
//     // //##########################################
//     // `include "rvfi_reference.svh"

//     initial begin
//         $fsdbDumpfile("dump.fsdb");
//         $fsdbDumpvars(0, "+all");
//         rst = 1'b1;
//         repeat (2) @(posedge clk);
//         rst <= 1'b0;
//         // rob Test
//         Qtest();
//         $finish;
//     end

//     always @(posedge clk) begin
        
//         if (timeout == 0) begin
//             $error("TB Error: Timed out");
//             $finish;
//         end
        
//         timeout <= timeout - 1;
//     end

// endmodule