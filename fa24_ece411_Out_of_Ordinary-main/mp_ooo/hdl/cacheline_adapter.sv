module cacheline_adapter
import CDB_types::*;
(
    input   logic   clk,
    input   logic   rst,
    
    // input   logic   [31:0]  raddr,
    //From BRAM
    input   logic   [63:0]  rdata,
    input   logic           rvalid,
    //FROM DCACHE
    input   logic   [255:0] dc_rdata,
    input   logic           dc_read,
    input   logic           dc_write,
    input   logic   [31:0]  d_cache_requested_addr,
    //FROM ICACHE
    input   logic           ic_read,
    input   logic   [31:0]  i_cache_requested_addr,
    // input   logic           ready,
    //TO DESIRED MEM UNIT
    // output  logic           dfp_resp,
    //TO ICACHE
    output  logic   [255:0] ic_dfp_rdata,
    output  logic           ic_dfp_resp,
    //FROM BRAM TO DCACHE
    output  logic   [255:0] dc_dfp_rdata,
    output  logic           dc_dfp_resp,
    
    //FROM DCACHE TO BRAM
    output  logic   [63:0]  bram_dfp_rdata,
    output  logic   [31:0]  bmem_addr,
    output  logic           bmem_read,
    output  logic           bmem_write

);

    // localparam BURST_NUMBER = 4;
    // localparam BURST_SIZE = 64;

    logic   [255:0]     cache_adapter_data;
    logic   [255:0]     next_line_data;
    logic   [63:0]      ram_adapter_data;
    logic   [31:0]      next_line_addr;
    logic               next_line_ready;

    logic               icache_read;
    logic               dcache_read;
    logic               dcache_write;
    
    logic   [1:0]       action_handled; //'10' for bmem to icache handled,'11' for bmem to dcache handled, '01' for dcache to bmem handled
    logic               occupied;
    int unsigned        counter;
    // int unsigned        cache_to_ram_counter;
    always_comb begin
        icache_read = ic_read;
        dcache_read = dc_read;
        dcache_write = dc_write;
    end

   
    enum int unsigned {
        idle,
        iread,
        iprefetch,
        iprefetch_ready,
        dread,
        dwrite
    }   state, next_state;

    // state machine logic
    always_comb begin
        bmem_addr ='0;
        bmem_read = '0;
        bmem_write = '0;
        // set defaults
        next_state = state;
        ic_dfp_resp = '0;
        dc_dfp_resp = '0;
        ic_dfp_rdata = '0;
        dc_dfp_rdata = '0;
        bram_dfp_rdata = '0;
        // bram_dfp_rdata = dc_rdata[counter * BURST_SIZE +: BURST_SIZE];

        case (state)
            idle: begin
                // process read or write request
                if (dc_write) begin
                    next_state = dwrite;
                end
                else if(dc_read) begin
                    next_state = dread; 
                    bmem_addr=d_cache_requested_addr;
                    bmem_read = '1;
                end  
                else if(ic_read) begin
                    if(next_line_addr == i_cache_requested_addr && next_line_ready) begin  //hit nextline we can continue reading 
                        next_state = iprefetch_ready;
                        bmem_addr = next_line_addr +32;
                        bmem_read = '1;
                    end
                    else begin
                        next_state = iread; 
                        bmem_addr = i_cache_requested_addr;
                        bmem_read = '1;
                    end     
                end
                else next_state = idle;
            end
            iread: begin                    //directly go to next state 
                if(counter == 4) begin
                    ic_dfp_resp = 1'b1;
                    ic_dfp_rdata = cache_adapter_data;
                    if(dc_write) begin
                        next_state = dwrite;
                    end
                    else if(dc_read) begin
                        next_state = dread;
                        bmem_addr=d_cache_requested_addr;
                        bmem_read = '1;
                    end
                    else begin
                        next_state = iprefetch;
                        bmem_addr = next_line_addr;
                        bmem_read = '1;
                    end
                end
                else begin 
                    bmem_addr = i_cache_requested_addr;
                    bmem_read = '0;
                    bmem_write= '0;
                end
            end
            iprefetch: begin
                if(counter == 4) begin
                    if(dc_write) begin
                        next_state = dwrite;
                    end
                    else if(dc_read) begin
                        next_state = dread;
                        bmem_addr=d_cache_requested_addr;
                        bmem_read = '1;
                    end
                    else if(ic_read) begin
                        if(next_line_addr == i_cache_requested_addr && next_line_ready) begin  //hit nextline we can continue reading 
                            next_state = iprefetch_ready;
                            bmem_addr = next_line_addr +32;
                            bmem_read = '1;
                        end
                        else begin
                            bmem_addr = i_cache_requested_addr;
                            bmem_read = '1;
                            next_state = iread;
                        end
                    end
                    else begin
                        next_state = idle;
                    end
                end 
                else begin
                    bmem_addr = next_line_addr; 
                    bmem_read = '0;
                    bmem_write= '0;
                end
            end
            
            iprefetch_ready: begin
                ic_dfp_resp = 1'b1;
                ic_dfp_rdata = next_line_data;
                next_state = iprefetch;
                bmem_addr = next_line_addr; 
                bmem_read = '0;
                bmem_write= '0;
            end

            dread: begin
                if(counter == 4) begin
                    next_state = idle;
                    dc_dfp_resp = 1'b1;
                    dc_dfp_rdata = cache_adapter_data;
                    
                    
                     if(ic_read) begin
                    if(next_line_addr == i_cache_requested_addr && next_line_ready) begin  //hit nextline we can continue reading 
                        next_state = iprefetch_ready;
                        bmem_addr = next_line_addr +32;
                        bmem_read = '1;
                    end
                    else begin
                        next_state = iread; 
                        bmem_addr = i_cache_requested_addr;
                        bmem_read = '1;
                    end     
                end
                end 
                else begin
                    bmem_addr = d_cache_requested_addr;
                    bmem_read = '0;
                    bmem_write= '0;
                end
            end
            dwrite :begin
                bmem_addr = d_cache_requested_addr;
                bram_dfp_rdata = dc_rdata[counter * BURST_SIZE +: BURST_SIZE];
                if(counter == 3) begin
                    next_state = idle;
                    dc_dfp_resp = 1'b1;
                    bmem_write= '1;
                    
                   
                     
                    
                end 
                else begin
                    bmem_read = '0;
                    bmem_write= '1;
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= idle;  
            counter <= '0; 
            next_line_addr <= 32'h1eceb020;
            next_line_ready <= '0;
        end 
        else begin
            state <= next_state;
            if(ic_read && ! dc_write && !dc_read && next_line_ready)begin
                next_line_addr <= i_cache_requested_addr + 32;
                next_line_ready <= '0;
            end
            if ((counter == 3 && state == dwrite )  || (counter==4)) begin
                counter <= '0;
                if(state == iprefetch) begin
                   next_line_ready <= '1;
                end
            end
            if (state == dwrite) begin
                counter <= counter + 1'b1;
            end

            if ((state == iread) || (state == dread) || state==iprefetch) begin

                // start composing data only when counter <=3
                if (counter <= 3 && state == iprefetch) begin
                    next_line_data[counter * BURST_SIZE +: BURST_SIZE] <= rdata;
                end
                else begin
                    cache_adapter_data[counter * BURST_SIZE +: BURST_SIZE] <= rdata;
                end
                if (rvalid)
                    counter <= counter + 1'b1;
            end

            
        end
    end


endmodule

