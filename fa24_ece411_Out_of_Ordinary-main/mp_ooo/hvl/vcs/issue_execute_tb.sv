// import "DPI-C" function string getenv(input string env_name);

module issue_execute_tb;

    timeunit 1ps;
    timeprecision 1ps;

    // int clock_half_period_ps = getenv("ECE411_CLOCK_PERIOD_PS").atoi() / 2;
    import CDB_types::*;
    import rv32i_types::*;

    bit clk;
    always #(2ns) clk = ~clk;

    bit rst;

    int timeout = 4000; // in cycles, change according to your needs

    logic               stall;
    // pd broadcast from CDB
    logic   [5:0]       pd_0_s,pd_1_s,pd_2_s,pd_3_s;
    logic   [31:0]      pd_0_v,pd_1_v,pd_2_v,pd_3_v;
    // take input from the ID RE stage
    res_station_t       issue_execute_input;

    // four functional unit outputs 
    funct_unit_out_t    alu_unit_out;
    funct_unit_out_t    cmp_unit_out;
    funct_unit_out_t    mult_unit_out;
    funct_unit_out_t    div_unit_out; 


    Issue_Execute dut(.*);
    task set_CDB_signals(
        input   logic   [5:0]   in_pd_0_s,
        input   logic   [31:0]  in_pd_0_v,
        input   logic   [5:0]   in_pd_1_s,
        input   logic   [31:0]  in_pd_1_v,
        input   logic   [5:0]   in_pd_2_s,
        input   logic   [31:0]  in_pd_2_v,
        input   logic   [5:0]   in_pd_3_s,
        input   logic   [31:0]  in_pd_3_v
    );

        pd_0_s = in_pd_0_s;
        pd_0_v = in_pd_0_v;
        pd_1_s = in_pd_1_s;
        pd_1_v = in_pd_1_v;
        pd_2_s = in_pd_2_s;
        pd_2_v = in_pd_2_v;
        pd_3_s = in_pd_3_s;
        pd_3_v = in_pd_3_v;
    
    endtask

    task set_input(
        input   logic           valid,
        input   logic           ps1_valid,
        input   logic   [5:0]   ps1_idx,
        input   logic           ps2_valid,
        input   logic   [5:0]   ps2_idx,
        input   logic   [5:0]   pd_idx,
        input   logic   [4:0]   rd_idx,
        input   logic   [3:0]   rob_idx,
        input   logic   [31:0]  inst,
        input   logic   [31:0]  pc
    );

        issue_execute_input.valid        <= valid;
        issue_execute_input.ps1_valid    <= ps1_valid;
        issue_execute_input.ps1_idx      <= ps1_idx;
        issue_execute_input.ps2_valid    <= ps2_valid;
        issue_execute_input.ps2_idx      <= ps2_idx;
        issue_execute_input.pd_idx       <= pd_idx;
        issue_execute_input.rd_idx       <= rd_idx;
        issue_execute_input.rob_idx      <= rob_idx;
        issue_execute_input.inst         <= inst;
        issue_execute_input.pc           <= pc;

    endtask

    task set_ctrl_block(
        input   logic           use_imm,
        input   logic           use_pc,
        input   logic           is_br,
        input   logic   [31:0]  imm,
        input   logic   [2:0]   funct3,
        input   logic   [1:0]   func_unit
    );

        issue_execute_input.ctrl_block.use_imm   <= use_imm;
        issue_execute_input.ctrl_block.use_pc    <= use_pc;
        issue_execute_input.ctrl_block.is_br     <= is_br;
        issue_execute_input.ctrl_block.imm       <= imm;
        issue_execute_input.ctrl_block.funct3    <= funct3;
        issue_execute_input.ctrl_block.func_unit <= func_unit;

    endtask;


    task res_station_test();
        stall = 1'b0;
        // first write
        set_input('1, '1, 6'h0, '1, 6'h1, 6'h2, 5'h3, 4'h0, '1, 32'h1eceb000);
        set_ctrl_block('0, '0, '0, '0, '0, '0); // add inst
        set_CDB_signals(6'h1, 32'h1eceb000, 6'h2, 32'h1eceb000, 6'h3, 32'h1eceb000, 6'h4, 32'h1eceb000);
        @(posedge clk);
        // first write
        set_input('1, '1, 6'h1, '1, 6'h1, 6'h2, 5'h3, 4'h0, '1, 32'h1eceb000);
        set_ctrl_block('0, '0, '0, '0, '0, 2'h1); // add inst
        @(posedge clk);
        // first write
        set_input('1, '1, 6'h2, '1, 6'h1, 6'h2, 5'h3, 4'h0, '1, 32'h1eceb000);
        set_ctrl_block('0, '0, '0, '0, '0, 2'h2); // add inst
        @(posedge clk);
        // first write
        set_input('1, '1, 6'h3, '1, 6'h1, 6'h2, 5'h3, 4'h0, '1, 32'h1eceb000);
        set_ctrl_block('0, '0, '0, '0, '0, 2'h3); // add inst
        @(posedge clk);

        set_input('1, '1, 6'h4, '1, 6'h1, 6'h2, 5'h3, 4'h0, '1, 32'h1eceb000);
        set_ctrl_block('0, '0, '0, '0, '0, '0); // add inst
        @(posedge clk);
        // first write
        set_input('1, '1, 6'h5, '1, 6'h1, 6'h2, 5'h3, 4'h0, '1, 32'h1eceb000);
        set_ctrl_block('0, '0, '0, '0, '0, 2'h1); // add inst
        @(posedge clk);
        // first write
        set_input('1, '1, 6'h6, '1, 6'h1, 6'h2, 5'h3, 4'h0, '1, 32'h1eceb000);
        set_ctrl_block('0, '0, '0, '0, '0, 2'h2); // add inst
        @(posedge clk);
        // first write
        set_input('1, '1, 6'h7, '1, 6'h1, 6'h2, 5'h3, 4'h0, '1, 32'h1eceb000);
        set_ctrl_block('0, '0, '0, '0, '0, 2'h3); // add inst
        @(posedge clk);

        #30ns;  
    endtask

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;

        // basic res station test
        res_station_test();

        $finish;
    end

    // assign rs1_s = out.ps1_idx;
    // assign rs2_s = out.ps2_idx;

    always @(posedge clk) begin
        
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $finish;
        end
        
        timeout <= timeout - 1;
    end

endmodule
