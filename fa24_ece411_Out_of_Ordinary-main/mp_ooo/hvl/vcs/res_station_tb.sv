// import "DPI-C" function string getenv(input string env_name);

module res_station_tb;

    timeunit 1ps;
    timeprecision 1ps;

    // int clock_half_period_ps = getenv("ECE411_CLOCK_PERIOD_PS").atoi() / 2;
    import CDB_types::*;
    import rv32i_types::*;

    bit clk;
    always #(2ns) clk = ~clk;

    bit rst;

    int timeout = 4000; // in cycles, change according to your needs

    // res_station logic
    logic           write;
    logic           ready;
    logic   [5:0]   pd;
    logic           full;
    logic           out_valid;
    res_station_t   in;
    res_station_t   out;

    // reg_file logic
    logic           regf_we;
    logic   [5:0]   rs1_s, rs2_s, rd_s;
    logic   [31:0]  rs1_v, rs2_v, rd_v;

    // alu logic
    logic           CDB_busy;
    logic           output_valid;
    funct_unit_out_t    alu_out;       



    res_station  #( .DEPTH(4)) dut (.*);
    phys_reg_file   phys_reg_file (.*);
    ALU ALU (
        .*,
        .input_valid (out_valid),
        .a (rs1_v),
        .b (rs2_v),
        .res_station_out (out)

    );


    task set_input_w_ctrl_block(
        input   logic           valid,
        input   logic           ps1_valid,
        input   logic   [5:0]   ps1_idx,
        input   logic           ps2_valid,
        input   logic   [5:0]   ps2_idx,
        input   logic   [5:0]   pd_idx,
        input   logic   [4:0]   rd_idx,
        input   logic   [3:0]   rob_idx,
        input   logic   [31:0]  inst,
        input   logic   [31:0]  pc,
        // CDB logic

        input   logic           use_imm,
        input   logic           use_pc,
        input   logic   [31:0]  imm,
        input   logic   [2:0]   funct3,
        input   logic   [1:0]   func_unit

    );

        in.valid        <= valid;
        in.ps1_valid    <= ps1_valid;
        in.ps1_idx      <= ps1_idx;
        in.ps2_valid    <= ps2_valid;
        in.ps2_idx      <= ps2_idx;
        in.pd_idx       <= pd_idx;
        in.rd_idx       <= rd_idx;
        in.rob_idx      <= rob_idx;
        in.inst         <= inst;
        in.pc           <= pc;

        // ctrl_block stuff
        in.ctrl_block.use_imm   <= use_imm;
        in.ctrl_block.use_pc    <= use_pc;
        in.ctrl_block.imm       <= imm;
        in.ctrl_block.funct3    <= funct3;
        in.ctrl_block.func_unit <= func_unit;

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
        // input   ctrl_block_t    ctrl_block; 
    );

        in.valid        <= valid;
        in.ps1_valid    <= ps1_valid;
        in.ps1_idx      <= ps1_idx;
        in.ps2_valid    <= ps2_valid;
        in.ps2_idx      <= ps2_idx;
        in.pd_idx       <= pd_idx;
        in.rd_idx       <= rd_idx;
        in.rob_idx      <= rob_idx;
        in.inst         <= inst;
        in.pc           <= pc;

    endtask

    task set_register(
        logic   [5:0]   in_rd_s,
        logic   [31:0]  in_rd_v
    );

        regf_we <= '1;
        rd_s <= in_rd_s;
        rd_v <= in_rd_v;
    endtask

    task set_write_CDB_Busy_pd(
        input   logic           in_write,
        input   logic           in_CDB_Busy,
        input   logic   [5:0]   in_pd
    );

        write <= in_write;
        CDB_busy <= in_CDB_Busy;
        pd <= in_pd;;

    endtask

    task res_station_test();
        @(posedge clk);

        // first write test: should only write first entry
        set_input('1, '1, 6'h0, '1, 6'h1, 6'h2, 5'h3, 4'h0, '1, 32'h1eceb000);
        set_write_CDB_Busy_pd('1,'0,'0);
        @(posedge clk);
        set_write_CDB_Busy_pd('0,'0,'0);
        @(posedge clk);

        // write second entry
        set_input('1, '0, 6'h1, '1, 6'h2, 6'h3, 5'h4, 4'h0, '1, 32'h1eceb004);
        set_write_CDB_Busy_pd('1,'0,'0);
        @(posedge clk);
        set_write_CDB_Busy_pd('0,'0,'0);
        @(posedge clk);

        // this should pop the first entry
        set_write_CDB_Busy_pd('0,'1,'0);
        @(posedge clk);
        set_write_CDB_Busy_pd('0,'0,'0);
        @(posedge clk);

        // write third entry
        set_input('1, '1, 6'h5, '1, 6'h6, 6'h7, 5'h8, 4'h9, '1, 32'h1eceb008);
        set_write_CDB_Busy_pd('1,'0,'0);
        @(posedge clk);
        set_write_CDB_Busy_pd('0,'0,'0);
        @(posedge clk);

        // this should skip the second and pop the third entry
        set_write_CDB_Busy_pd('0,'1,'0);
        @(posedge clk);
        set_write_CDB_Busy_pd('0,'0,'0);
        @(posedge clk);

        // write fourth entry
        set_input('1, '1, 6'ha, '1, 6'hb, 6'hc, 5'hd, 4'he, '1, 32'h1eceb008);
        set_write_CDB_Busy_pd('1,'0,'0);
        @(posedge clk);
        set_write_CDB_Busy_pd('0,'0,'0);
        @(posedge clk);

        // broadcast to make all register in second entry valid
        set_write_CDB_Busy_pd('0,'0, 6'h1);
        @(posedge clk);
        set_write_CDB_Busy_pd('0,'0,'0);
        @(posedge clk);

        // this should pop the second and move head to fourth entry (3)
        set_write_CDB_Busy_pd('0,'1,'0);
        @(posedge clk);
        set_write_CDB_Busy_pd('0,'0,'0);
        @(posedge clk);

        // this should pop the fourth entry and make the res station empty
        set_write_CDB_Busy_pd('0,'1,'0);
        @(posedge clk);
        set_write_CDB_Busy_pd('0,'0,'0);
        @(posedge clk);

        #30ns;  
    endtask

    task ALU_test();
        
        // set default write/CDB/PD
        set_write_CDB_Busy_pd('0,'0,'0);
        @(posedge clk);
        // write 0x12345678 into r1
        set_register(6'h1, 32'h12345678);

        // first write test: should only write first entry
        set_input_w_ctrl_block('1, '1, 6'h0, '1, 6'h1, 6'h2, 5'h3, 4'h0, '1, 32'h1eceb000, 
                                '0, '0, '0, '0, '0); // add r3, r0, r1
        set_write_CDB_Busy_pd('1,'0,'0);
        @(posedge clk);
        set_write_CDB_Busy_pd('0,'1,'0);
        @(posedge clk);

        // write second entry
        set_input_w_ctrl_block('1, '1, 6'h0, '1, 6'h1, 6'h2, 5'h3, 4'h0, '1, 32'h1eceb000, 
                                '0, '0, '0, '0, '0); // add r3, r0, r1
        set_write_CDB_Busy_pd('1,'1,'0);
        @(posedge clk);
        set_write_CDB_Busy_pd('0,'1,'0);
        @(posedge clk);

        // write 0x12345678 into r2
        set_register(6'h2, 32'h87654321);
        // write third entry but mark CBD busy
        set_input_w_ctrl_block('1, '0, 6'h1, '1, 6'h2, 6'h3, 5'h4, 4'h0, '1, 32'h1eceb004,
                                '0, '0, '0, '0, '0); // add r4, r1, r2
        set_write_CDB_Busy_pd('1,'1,'0);
        @(posedge clk);
        // broadcast a 1 to make the second entry in res station ready
        set_write_CDB_Busy_pd('0,'1, 6'h1); 
        @(posedge clk);
        set_write_CDB_Busy_pd('0,'0,'0);
        @(posedge clk);

        // // this should pop the first entry
        // set_write_CDB_Busy_pd('0,'1,'0);
        // @(posedge clk);
        // set_write_CDB_Busy_pd('0,'0,'0);
        // @(posedge clk);

        // // write third entry
        // set_input('1, '1, 6'h5, '1, 6'h6, 6'h7, 5'h8, 4'h9, '1, 32'h1eceb008);
        // set_write_CDB_Busy_pd('1,'0,'0);
        // @(posedge clk);
        // set_write_CDB_Busy_pd('0,'0,'0);
        // @(posedge clk);

        // // this should skip the second and pop the third entry
        // set_write_CDB_Busy_pd('0,'1,'0);
        // @(posedge clk);
        // set_write_CDB_Busy_pd('0,'0,'0);
        // @(posedge clk);

        // // write fourth entry
        // set_input('1, '1, 6'ha, '1, 6'hb, 6'hc, 5'hd, 4'he, '1, 32'h1eceb008);
        // set_write_CDB_Busy_pd('1,'0,'0);
        // @(posedge clk);
        // set_write_CDB_Busy_pd('0,'0,'0);
        // @(posedge clk);

        // // broadcast to make all register in second entry valid
        // set_write_CDB_Busy_pd('0,'0, 6'h1);
        // @(posedge clk);
        // set_write_CDB_Busy_pd('0,'0,'0);
        // @(posedge clk);

        // // this should pop the second and move head to fourth entry (3)
        // set_write_CDB_Busy_pd('0,'1,'0);
        // @(posedge clk);
        // set_write_CDB_Busy_pd('0,'0,'0);
        // @(posedge clk);

        // // this should pop the fourth entry and make the res station empty
        // set_write_CDB_Busy_pd('0,'1,'0);
        // @(posedge clk);
        // set_write_CDB_Busy_pd('0,'0,'0);
        // @(posedge clk);

        #30ns;  
    endtask

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        write = 1'b0;
        pd = '0;
        repeat (2) @(posedge clk);
        rst <= 1'b0;

        // basic res station test
        // res_station_test();

        // res station + alu test
        ALU_test();
        $finish;
    end

    assign rs1_s = out.ps1_idx;
    assign rs2_s = out.ps2_idx;

    always @(posedge clk) begin
        
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $finish;
        end
        
        timeout <= timeout - 1;
    end

endmodule
