module cache 
import cache_reg::*;
(
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp
);


    // data array logic
    logic   [0:0]   data_array_wr[4]; //* 1 for read, 0 for write
    logic   [31:0]  data_array_wmask[4];
    logic   [255:0] data_array_in[4];
    logic   [255:0] data_array_out[4]; // four element to store outputs from 4 ways

    // tag array logic
    logic   [0:0]   tag_array_wr[4]; //* 1 for read, 0 for write
    logic   [23:0]  tag_array_in[4];
    logic   [23:0]  tag_array_out[4];

    // valid logic 
    logic   [0:0]   valid_array_wr[4]; //* 1 for read, 0 for write
    logic   [0:0]   valid_array_in[4];
    logic   [0:0]   valid_array_out[4];

    // plru logic
    logic           lru_array_wr;
    logic   [2:0]   lru_array_in, lru_array_out;
    logic   [1:0]   way_evict;
    int unsigned    way_hit, way_hit_latched;

    // hit/stall logic
    logic           hit;
    logic           stall;// write_stall, write_stall_latched;
    logic           dfp_resp_latched;    
    logic   [3:0]   wmask_latched;
    logic   [31:0]  data_latched, addr_latched;

    logic   [4:0]   offset, offset_latched;
    logic   [8:5]   set_idx;
    logic   [31:9]  tag;

    pipeline_reg_t  pipeline_reg, pipeline_reg_next;

    // state machine logic
    enum int unsigned {
        compare_tag,
        allocate,
        write_back
    }   state, state_next, state_prev;

    logic       counter, write_stall, chip_en, chip_en_latched;

    always_comb begin : first_stage

        // big mux controlled by stall
        // load new data
        pipeline_reg_next.ufp_addr = ufp_addr;
        pipeline_reg_next.ufp_rmask = ufp_rmask;
        pipeline_reg_next.ufp_wmask = ufp_wmask;
        pipeline_reg_next.ufp_wdata = ufp_wdata;

        if (stall | write_stall) begin

            // offset/set_idx/tag should come from reg
            offset  =   pipeline_reg.ufp_addr[4:0];
            set_idx =   pipeline_reg.ufp_addr[8:5];
            tag     =   pipeline_reg.ufp_addr[31:9];

        end else begin

            // if not stalling, use the data coming in
            offset  =   ufp_addr[4:0];
            set_idx =   ufp_addr[8:5];
            tag     =   ufp_addr[31:9];
        end
        
    end

  

    always_comb begin : second_stage

        //* ufp_resp logic ends

        //* plru logic

        // set default

        lru_array_wr = '1;
        lru_array_in = '0;
        way_evict = '0;

        // calculate way_evict
        // if first bit is zero, choose between A/B
        
        if (lru_array_out[0]) begin
            if (lru_array_out[1]) 
                way_evict = 2'b00; // A
            else
                way_evict = 2'b01; // B
            // else, choose between C/D
        end else begin
            if (lru_array_out[2]) 
                way_evict = 2'b10; // C
            else
                way_evict = 2'b11; // D
        end


        // update based on way hit when hit
        if (ufp_resp) begin
            lru_array_wr = 1'b0; // write to lru_array
            case (way_hit)
                'd0: begin    // hit A
                    lru_array_in[0] = 1'b0;
                    lru_array_in[1] = 1'b0;
                    lru_array_in[2] = lru_array_out[2];
                end

                'd1: begin    // hit B
                    lru_array_in[0] = 1'b0;
                    lru_array_in[1] = 1'b1;
                    lru_array_in[2] = lru_array_out[2];
                end

                'd2: begin    // hit C
                    lru_array_in[0] = 1'b1;
                    lru_array_in[1] = lru_array_out[1];
                    lru_array_in[2] = 1'b0;
                end

                'd3: begin    // hit D
                    lru_array_in[0] = 1'b1;
                    lru_array_in[1] = lru_array_out[1];
                    lru_array_in[2] = 1'b1;
                end

                default: begin
                    // should never happen
                end
            endcase
        end else begin
            lru_array_wr = 1'b1; // don't write to lru_array
            lru_array_in[0] = 1'b0;
            lru_array_in[1] = 1'b0;
            lru_array_in[2] = 1'b0;
        end
 
    end

    // state machine comb logic
    always_comb begin

        // set defaults
        state_next = state;

        // clear all arryas
        for (int i = 0; i < 4; i++) begin
            data_array_in[i]   = '0;
            tag_array_in[i]    = '0;
            valid_array_in[i]  = '0;

            data_array_wr[i]   = 1'b1;
            tag_array_wr[i]    = 1'b1;
            valid_array_wr[i]  = 1'b1;
            data_array_wmask[i] = '0;
        end

        dfp_addr = '0;
        dfp_read = 1'b0;
        dfp_write = 1'b0;

        ufp_rdata = 'x;
        dfp_wdata = '0;
        ufp_resp = '0;

        stall = 1'b1;
        write_stall = '0;
        chip_en = 1'b0;

        // check hit
        // check hit through valid and tag (four ways)
        hit = 1'b0;
        way_hit = '0;
        if (!chip_en_latched && ((pipeline_reg.ufp_rmask != '0) || (pipeline_reg.ufp_wmask != '0))) begin
            for (int unsigned i = 0; i < 4; i++) begin
                if (valid_array_out[i])
                    hit = (tag_array_out[i][22:0] == pipeline_reg.ufp_addr[31:9]);
                
                if (hit) begin
                    way_hit = i;
                    break;
                end
            end
        end

        case (state)

            //* compare_tag: check hit, read/write, and dirty
            compare_tag: begin
                if ((pipeline_reg.ufp_rmask != '0) || (pipeline_reg.ufp_wmask != '0)) begin

                    if (hit) begin

                        // if read, mark ufp_resp ready and return data
                        if ((pipeline_reg.ufp_rmask != '0) && !counter) begin
                            ufp_resp = 1'b1;
                            stall = 1'b0;
                            // hit = 1'b0;

                            // return data
                            ufp_rdata = data_array_out[way_hit][8*pipeline_reg.ufp_addr[4:0] +: 32];
                        end 

                        // if write, change the next state to write stall
                        if (pipeline_reg.ufp_wmask != '0) begin
                            write_stall = 1'b1;
                            chip_en = 1'b1;
                            
                            // stall for an extra cycle
                            if ((counter != 1'b1)) begin
                                stall = 1'b0;
                                // hit = 1'b0;
                                ufp_resp = 1'b1;
                            end else begin
                                stall = 1'b1;
                                ufp_resp = 1'b0;
                            end

                            // initiate write
                            data_array_wr[way_hit] = 1'b0;
                            data_array_in[way_hit] = '0;
                            data_array_wmask[way_hit] = '0;

                            // shift mask based on offset
                            data_array_wmask[way_hit][pipeline_reg.ufp_addr[4:0] +: 4] = pipeline_reg.ufp_wmask;
                            data_array_in[way_hit][8*pipeline_reg.ufp_addr[4:0] +: 32] = pipeline_reg.ufp_wdata;

                            // write dirty bit
                            tag_array_in[way_hit] = {1'b1, pipeline_reg.ufp_addr[31:9]};
                            tag_array_wr[way_hit] = 1'b0;

                        end

                    // if not hit, check block dirty for bringing data into cache
                    end else begin
                        ufp_resp = 1'b0;
                        // check MSB of tag_array_out
                        if (!chip_en_latched) begin
                        if (!valid_array_out[way_evict]) begin

                            // if going to allocate, send the addr and read
                            state_next = allocate;
                            if (!counter) begin
                                dfp_addr[31:5] = pipeline_reg.ufp_addr[31:5];
                                dfp_read = 1'b1;
                            end
                        end else if (tag_array_out[way_evict][23]) begin

                            // if going to write_back, start requesting signals
                            state_next = write_back;
                            if (!counter) begin
                                dfp_addr[31:5] = {tag_array_out[way_evict][22:0], pipeline_reg.ufp_addr[8:5]};
                                dfp_write = 1'b1;
                                dfp_wdata = data_array_out[way_evict];
                            end
                        end else begin

                            // if going to allocate, send the addr and read
                            state_next = allocate;
                            if (!counter) begin
                                dfp_addr[31:5] = pipeline_reg.ufp_addr[31:5];
                                dfp_read = 1'b1;
                            end
                        end
                    end
                    end

                end 
                else begin
                    // if nothing is coming in, stall pipeline
                    stall = 1'b0;
                end

                // if (counter) begin
                //     // use latched value
                //     data_array_wmask[way_hit_latched][addr_latched[4:0] +: 4] = wmask_latched;
                //     data_array_in[way_hit_latched][8*addr_latched[4:0] +: 32] = data_latched;

                //     // write dirty bit
                //     tag_array_in[way_hit_latched] = {1'b1, addr_latched[31:9]};
                //     tag_array_wr[way_hit_latched] = 1'b0;
                // end
            end

            allocate: begin

                // issue write request
                dfp_addr[31:5] = pipeline_reg.ufp_addr[31:5];
                dfp_read = 1'b1;

                // because tag array is 24 bits and tag is 23, we need to extend it
                tag_array_in[way_evict] = {1'b0, pipeline_reg.ufp_addr[31:9]};

                // set valid
                valid_array_wr[way_evict]  = 1'b0;
                valid_array_in[way_evict] = 1'b1;
                data_array_wmask[way_evict] = '1;

                // should always stall in this case

                // if mem ready, write the actual data
                if (dfp_resp) begin
                    // control write data
                    data_array_wr[way_evict] = 1'b0;
                    tag_array_wr[way_evict] = 1'b0;
                    valid_array_wr[way_evict]  = 1'b0;
                    data_array_in[way_evict] = dfp_rdata;
                end else begin
                    // control write data
                    data_array_wr[way_evict] = 1'b1;
                    tag_array_wr[way_evict] = 1'b1;
                    valid_array_wr[way_evict]  = 1'b1;
                    data_array_in[way_evict] = '0;
                end

                // if we just came here from write back, the latched value
                // will always be 1
                if (dfp_resp_latched) begin
                    state_next = compare_tag;
                    dfp_read = 1'b0;
                end

            end

            // write_back: if the dirty bit is one, then we need to write back to mem
            write_back: begin

                // load dfp with correct data
                dfp_addr[31:5] = {tag_array_out[way_evict][22:0], pipeline_reg.ufp_addr[8:5]};
                dfp_write = 1'b1;
                dfp_wdata = data_array_out[way_evict];

                // overwrite clean bit
                tag_array_in[way_evict] = {1'b0, pipeline_reg.ufp_addr[31:9]};
                tag_array_wr[way_evict] = 1'b1;

                // return to allocate after getting a response
                if (dfp_resp)
                    state_next = allocate;

            end

            // empty default: should never happen
            default: begin

            end

        endcase
    end


    always_ff @(posedge clk) begin

        // reset everything
        if(rst) begin
            pipeline_reg <= '0;
            dfp_resp_latched <= 1'b0;
            wmask_latched <= '0;
            data_latched <= '0;
            state <= compare_tag;
            way_hit_latched <= '0;
            counter <= 1'b0;
            addr_latched <= '0;
            chip_en_latched <= 1'b0;

            // pipeline_reg_next <= '0;
        end else begin

            // move pipeline and stage
            if (!stall)
                pipeline_reg <= pipeline_reg_next;

            state <= state_next;
            state_prev <= state;
            // latch data
            way_hit_latched <= way_hit;
            wmask_latched <= pipeline_reg.ufp_wmask;
            data_latched <= pipeline_reg.ufp_wdata;
            addr_latched <= pipeline_reg.ufp_addr;

            if (chip_en_latched)
                chip_en_latched <= 1'b0;
            else if (chip_en)
                chip_en_latched <= 1'b1;

            if ((state == compare_tag) && (pipeline_reg.ufp_wmask != '0))
                counter <= counter + 1'b1;
            else
                counter <= 1'b0;

            // don't latch dfp_resp in write_back state or it will mess up the
            // transition away from allocate
            if (dfp_resp && (state != write_back))
                dfp_resp_latched <= 1'b1;
            if (ufp_resp)
                dfp_resp_latched <= 1'b0;

        end

        
        
    end

    // csb0 - active low chip select, set to 1 for always enable for now
    // ! commented out generation to start testing with direct mapped cache
    generate for (genvar i = 0; i < 4; i++) begin : arrays
        mp_cache_data_array data_array (
            .clk0       (clk),
            .csb0       (1'b0), 
            .web0       (data_array_wr[i]),
            .wmask0     (data_array_wmask[i]),
            .addr0      (set_idx),
            .din0       (data_array_in[i]),
            .dout0      (data_array_out[i])
        );
        mp_cache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (tag_array_wr[i]),
            .addr0      (set_idx),
            .din0       (tag_array_in[i]),
            .dout0      (tag_array_out[i])
        );
        valid_array valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (1'b0),
            .web0       (valid_array_wr[i]),
            .addr0      (set_idx),
            .din0       (valid_array_in[i]),
            .dout0      (valid_array_out[i])
        );
    end endgenerate

    lru_array lru_array (
        .clk0       (clk),
        .rst0       (rst),

        // port 0 for read port
        .csb0       (1'b0),
        .web0       (1'b1), // 1 means always reading
        .addr0      (set_idx),
        .din0       (3'b000),
        .dout0      (lru_array_out),

        // port 1 for write port
        .csb1       (1'b0),
        .web1       (lru_array_wr),
        .addr1      (pipeline_reg.ufp_addr[8:5]),
        .din1       (lru_array_in),
        // because this is a read channel, the output shouldn't
        // connect to anything (compiler shouldn't complain?)
        .dout1      ()  
    );


endmodule

