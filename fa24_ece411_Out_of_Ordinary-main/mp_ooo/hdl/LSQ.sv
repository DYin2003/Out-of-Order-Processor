module LSQ
import CDB_types::*;
import rv32i_types::*;
(
    input   logic                           rst,    
    input   logic                           clk,
    input   logic                           flush,
    input   logic                           ufp_resp,
    input   logic   [$clog2(ROB_DEPTH)-1:0] rob_head,
    input   logic   [31:0]                  ufp_rdata,
    input   funct_unit_out_t                in,

    input logic up,
    input   logic [$clog2(LOAD_QUEUE_DEPTH) :0] recover_load_tail, 
    output  logic [$clog2(LOAD_QUEUE_DEPTH) :0] snap_load_tail,
    input   logic [$clog2(STORE_QUEUE_DEPTH):0] recover_store_tail,
    output  logic [$clog2(STORE_QUEUE_DEPTH):0] snap_store_tail,
    input  logic  [$clog2(EBR_NUM)-1:0] recover_idx,
    input  logic  [$clog2(ROB_DEPTH):0] depen_rob, 

    input   dependency_t             depen,
    input  logic    load_queue_enq,
    input  logic    store_queue_enq,

    output  logic                           load_queue_full,
    output  logic                           store_queue_full,
    output  cache_interface_t               output_to_cache,
    output  CDB_t                           output_to_CDB
   
         
);
    logic           load_ufp_resp, store_ufp_resp;
    logic           request;
    logic           store_committed;
    logic           load_full, store_full;
    logic           load_enqueue, store_enqueue;
    logic           we_load,we_store;
    logic           wrap_around;
    logic           sent_output, flush_latched;

    logic   [$clog2(STORE_QUEUE_DEPTH):0] st_cnt;
    CDB_t               load_cdb_out, store_cdb_out;
    cache_interface_t   load_cache_out, store_cache_out;

    enum int unsigned {
        idle,
        read,
        write
    }   state, next_state;
    
    // TODO: easy way to set full, check back later
    // assign full = load_full | store_full;
    assign load_queue_full = load_full;
    assign store_queue_full = store_full;

    always_ff @(posedge clk) begin 
        // reset logic
        if(rst | flush) begin
            state <= idle;
        end else begin
            state <= next_state;

        end
        
    end

    assign  request = (output_to_cache.ufp_rmask != '0 )| (output_to_cache.ufp_wmask != '0);

    // arbiter for input
    always_comb begin : input_arbiter
        // arbiter for input
        // set default
        load_enqueue = load_queue_enq;
        store_enqueue = store_queue_enq;
        we_load = '0;
        we_store = '0;
        // set enqueue logic based on opcode and full status
        if (in.out_valid) begin
            if ((in.inst[6:0] == op_b_load))
                we_load = 1'b1;
            if ((in.inst[6:0] == op_b_store))
                we_store = 1'b1;
        end

        
    end

    // output arbiter
    always_comb begin
        // arbiter for cache: this probably need a state machine
        // set default  
        next_state = state;
        output_to_cache = '0;
        load_ufp_resp = 1'b0;
        store_ufp_resp = 1'b0;
        store_committed = 1'b0;
        output_to_CDB = '0;


        case (state)
            idle: begin
                // if there is a store request, output it
                if (store_cache_out.ufp_wmask != '0) begin
                    output_to_cache = store_cache_out;
                    next_state = write;
                end else

                // if there is a load request, output it and go to read
                if (load_cache_out.ufp_rmask != '0) begin
                    output_to_cache = load_cache_out;
                    next_state = read;
                end
            end

            read: begin
                // keep outputting the load request until ufp_resp is out_valid
                output_to_cache = load_cache_out;

                // if got ufp_resp, go back to idle and set load_ufp_resp
                // jump directly to write if there is a store request
                if (ufp_resp) begin
                    if (store_cache_out.ufp_wmask != '0) begin
                        next_state = write;
                        output_to_cache = store_cache_out;
                    end else
                    if (load_cache_out.ufp_rmask != '0) begin
                        output_to_cache = load_cache_out;
                        next_state = read;
                    end else
                        next_state = idle;

                    load_ufp_resp = 1'b1;
                end
            end

            write: begin
                // keep outputting the store request until ufp_resp is out_valid
                output_to_cache = store_cache_out;

                // if got ufp_resp, go back to idle and set store_ufp_resp
                // can't mark store committed here or load queue won't pick
                // up the most up to date store queue size
                // jump directly to write if there is a store request
                if (ufp_resp) begin
                    if (store_cache_out.ufp_wmask != '0) begin
                        next_state = write;
                        output_to_cache = store_cache_out;
                    end else
                    if (load_cache_out.ufp_rmask != '0) begin
                        output_to_cache = load_cache_out;
                        next_state = read;
                    end else
                        next_state = idle;
                        
                    store_ufp_resp = 1'b1;
                end
            end
        endcase

        // the current design shouldn't have two CDB request at the same time
        // TODO: fix this later
        
        if (store_cdb_out != '0) begin
            output_to_CDB = store_cdb_out;
            store_committed = 1'b1;
        end 
        else if (load_cdb_out != '0)
            output_to_CDB = load_cdb_out;
    end

    // instantiate load queue and store queue
    load_queue load_queue(
        // input
        .*,
        .rst                (rst),
        .clk                (clk),
        .flush              (flush),
        .enqueue            (load_enqueue),
        .request            (request),
        .ufp_resp           (load_ufp_resp),
        .ufp_rdata          (ufp_rdata),
        .store_committed    (store_committed),
        .in                 (in),
        .st_cnt             (st_cnt),

        // output
        .full               (load_full),
        .output_to_cache    (load_cache_out),
        .output_to_CDB      (load_cdb_out),
        .we                 (we_load)

    );

    store_queue store_queue(
        // input
        .*,
        .rst                (rst),
        .clk                (clk),
        .flush              (flush),
        .enqueue            (store_enqueue),
        .request            (request),
        .ufp_resp           (store_ufp_resp),
        .rob_head           (rob_head),
        .in                 (in),

        // output
        .st_cnt             (st_cnt),
        .full               (store_full),
        .output_to_cache    (store_cache_out),
        .output_to_CDB      (store_cdb_out),
        .we                 (we_store)
    );



endmodule : LSQ