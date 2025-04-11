module IF
import CDB_types::*;
import rv32i_types::*;
(
    input   logic   clk,
    input   logic   rst,

    input cmp_to_IF cmp_in,

    // detect jalr instruction
    input   logic               jalr_stall_latched,jalr_stall,
    // input   logic  flush,
    input   logic   [31:0]      pc_out,//pc_target
    output  logic   [31:0]      bmem_addr,
    output  logic               bmem_read,
    output  logic               bmem_write,
    // input   logic               bmem_ready,
    input   logic   [31:0]      bmem_raddr,
    input   logic   [63:0]      bmem_rdata,
    input   logic               bmem_rvalid,
    output  logic   [63:0]      dc_to_bmem_rdata,
    // input   logic               rob_full,
    //stall 
    output  logic               IF_stall, 
    input   logic               RE_stall,DE_stall,
    // output  logic               IF_stall,
    input  logic               flush,

    output  IF_ID_reg_t         IF_ID_reg,

    // LSQ stuff
    input   cache_interface_t   lsq_output_to_cache,
    output  logic               d_cache_resp,
    output  logic   [31:0]      d_cache_data

);
    logic [31:0] pc_pred_next, pc_rd;
    logic [31:0] pc_next_inq, pc_next_deq;
    logic    [31:0]     pc_next_latch;
    IF_ID_reg_t         IF_ID_reg_next;
    logic               dc_dfp_resp;
    logic   [255:0]     dc_dfp_rdata;
    logic   [255:0]     dc_dfp_wdata;

    logic               ic_dfp_resp;
    logic   [255:0]     ic_dfp_rdata;

    logic               bram_dfp_resp;
    logic   [63:0]     bram_dfp_rdata;
    logic   [31:0]      cache_output;
    // logic for instruction_q
    logic               enq, deq;
    logic   [95:0]      ins_qin;
    logic   [95:0]      ins_qout;
    logic               full,empty;
    logic   [31:0]      pc, pc_next;
    logic   [31:0]      inst;
    // logic for i_cache
    logic               i_cache_resp;
    logic               i_cache_read;
    logic   [31:0]      i_cache_addr;
    logic   [31:0]      raddr;
    logic   [31:0]      requested_addr;
    logic   [31:0]      i_cache_requested_addr;

    //logic for d_cache
    logic               d_cache_read;
    logic               d_cache_write;
    logic   [31:0]      d_cache_raddr;
    logic   [31:0]      d_cache_requested_addr;


    logic [1:0]hold_on_flush;

    logic       DE_stall_latched;

    always_ff @(posedge clk) begin
        if (rst) begin
            hold_on_flush <= 2'b0;
            // reset everything
            pc <= 32'h1eceb000;
        end
        else if(flush) begin
            hold_on_flush <= 2'b10;
            pc <= pc_out;
        end
        else if (hold_on_flush ==  2'b10  && i_cache_resp ) begin //
            hold_on_flush <= 2'b01;
            pc <= pc;
        end
        else if(hold_on_flush != '0 && i_cache_resp) begin
            hold_on_flush <= 2'b00;
            // pc <= pc + 'd4;
        end
         
        else begin
            // only increment pc when i_cache responses
            if ((hold_on_flush=='0) && i_cache_resp && !full && !jalr_stall_latched) begin
                // pc <= pc + 'd4;
                pc <= pc_pred_next;
            end
        end
    end
    //immediate fetch next addr 
    assign i_cache_addr =  ((hold_on_flush == '0) && i_cache_resp && !full)? pc_pred_next:pc;
    assign enq = (hold_on_flush == '0) && !full  && i_cache_resp && !jalr_stall_latched;    
    assign deq = !empty &&(!(RE_stall||DE_stall)) && !jalr_stall_latched ;    //TODO dequeue request from Decode Stage 
    assign ins_qin = {pc,inst,pc_pred_next};
    assign raddr = bmem_raddr; 
    
    assign IF_stall = empty ;

    assign dc_to_bmem_rdata = bram_dfp_rdata;

    //##########propagating IF_ID register########
    always_comb begin
        IF_ID_reg_next  = ins_qout;
    end


    always_ff@(posedge clk) begin
        if(rst || flush) begin
            IF_ID_reg <= '0;
        end
        else if (RE_stall||DE_stall) begin
            IF_ID_reg <= IF_ID_reg;
        end
        else if( IF_stall || jalr_stall_latched ||jalr_stall ) begin
            IF_ID_reg <= '0;
        end
        else begin
            IF_ID_reg <= IF_ID_reg_next;
        end
        DE_stall_latched <= DE_stall;
    end

    //-----------------------------------
    // ON FLUSH-> hold pc value 
    // always_ff @(posedge clk) begin
    //     if (rst) begin
    //         pc_next <= '0;
    //     end else begin
    //         if (flush) begin
    //             pc_next <= pc;
    //         end else begin
    //             pc_next <= pc + 'd4;
    //         end
    //     end
    // end
    
    localparam PREDICT_DEPTH = 32;
    localparam IDX = $clog2(PREDICT_DEPTH) -1;

    logic [$clog2(PREDICT_DEPTH)-1:0] wr_addr, rd_addr;
    

    logic [1:0] rd_cnt;
    assign rd_addr = i_cache_addr[IDX+2:2];
    assign wr_addr = cmp_in.pc[IDX+2:2];
   
    always_comb begin
        pc_pred_next= pc + 4;
        if(inst[6:0] == op_b_br) begin
            unique case (rd_cnt)
                ST,WT: pc_pred_next = pc_rd;
                SN,WN: pc_pred_next = pc + 4;
                default:pc_pred_next= pc + 4;
            endcase
        end
        else if (inst[6:0] == op_b_jal) begin
            pc_pred_next = pc + {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
        end
    end

    predictor_reg_file #(.DEPTH(PREDICT_DEPTH)) TARGET_PC(
        .we(cmp_in.we), //write back from CMP
        .data_in(pc_out), 
        .wr_addr(wr_addr), 

        .rd_addr(rd_addr),
        .data_out(pc_rd),
        .*
    );
    counter_reg_file #(.DEPTH(PREDICT_DEPTH)) PATTERN(
        .we(cmp_in.we), //write back from CMP
        .taken(cmp_in.taken), 
        .wr_addr(wr_addr), 

        .rd_addr(rd_addr),
        .data_out(rd_cnt),
        .*
    );

    //########Instantiate instruction fifo, cache, cache adapter
    fifo #()instruction_queue(
            .clk            (clk),
            .rst            (rst),
            .flush          (flush),
            .enq            (enq),
            .deq            (deq),
            .din            (ins_qin),
            .dout           (ins_qout),
            .empty          (empty),
            .full           (full) 
        );
    
    // cacheline adapter module
    cacheline_adapter cacheline_adapter(
        .*, // clk, rst, bmem_addr, bmem_read

        // inputs
        .rdata          (bmem_rdata),
        .rvalid         (bmem_rvalid),
        .dc_rdata       (dc_dfp_wdata),
        .dc_read        (d_cache_read),
        .dc_write       (d_cache_write),
        .d_cache_requested_addr (d_cache_requested_addr),
        .ic_read        (i_cache_read),
        .i_cache_requested_addr (i_cache_requested_addr),
        // output
        .ic_dfp_rdata      (ic_dfp_rdata),
        .ic_dfp_resp       (ic_dfp_resp),
        .dc_dfp_rdata      (dc_dfp_rdata),
        .dc_dfp_resp       (dc_dfp_resp),
        .bram_dfp_rdata    (bram_dfp_rdata),
        .bmem_addr         (bmem_addr),
        .bmem_read         (bmem_read),
        .bmem_write        (bmem_write) 

    );
    
    // initialize cache - set to all zero for now to see if it synthesizes
    cache i_cache(
        .clk            (clk),
        .rst            (rst),

        // cpu side signals, ufp -> goes to queue
        .ufp_addr       (i_cache_addr),
        .ufp_rmask      ('1),
        .ufp_wmask      ('0),
        .ufp_rdata      (inst),
        .ufp_wdata      ('0),
        .ufp_resp       (i_cache_resp),

        // memory side signals, dfp -> goes to bmem
        .dfp_addr       (i_cache_requested_addr),
        .dfp_read       (i_cache_read),
        .dfp_write      (),
        .dfp_rdata      (ic_dfp_rdata),
        .dfp_wdata      (),
        .dfp_resp       (ic_dfp_resp)
    );

    cache d_cache(
        .clk            (clk),
        .rst            (rst),

        // cpu side signals, ufp -> goes to queue
        .ufp_addr       (lsq_output_to_cache.ufp_addr),
        .ufp_rmask      (lsq_output_to_cache.ufp_rmask),
        .ufp_wmask      (lsq_output_to_cache.ufp_wmask),
        .ufp_rdata      (d_cache_data),
        .ufp_wdata      (lsq_output_to_cache.ufp_wdata),
        .ufp_resp       (d_cache_resp),

        // memory side signals, dfp -> goes to bmem
        .dfp_addr       (d_cache_requested_addr),
        .dfp_read       (d_cache_read),
        .dfp_write      (d_cache_write),
        .dfp_rdata      (dc_dfp_rdata),
        .dfp_wdata      (dc_dfp_wdata),
        .dfp_resp       (dc_dfp_resp)
    );
endmodule

