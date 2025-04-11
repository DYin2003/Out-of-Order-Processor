// got from mp_pipeline
module phys_reg_file 
import CDB_types::*;
#(
    // parameter NUM_REG = 64,
    // parameter P_REG_NUM = 64,
    // parameter CDB_NUM = 5 
)
(
    input   logic           clk,
    input   logic           rst,
    input   logic           cdb_we_array[CDB_NUM],

    input   logic   [31:0]  cdb_funct_out_array[CDB_NUM],
    input   logic   [$clog2(P_REG_NUM) -1:0]    cdb_pd_array[CDB_NUM],
    input   logic   [$clog2(P_REG_NUM) - 1:0]     rs1_s [CDB_NUM], 
    input   logic   [$clog2(P_REG_NUM) - 1:0]     rs2_s [CDB_NUM], 
    output  logic   [31:0]  rs1_v [CDB_NUM],
    output  logic   [31:0]  rs2_v [CDB_NUM]
);

    logic   [31:0]  data [P_REG_NUM];

    // sync reset
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < P_REG_NUM; i++) begin
                data[i] <= '0;
            end
        end else begin
            // if write enable, check all pd_s and see if they are not 0
            // if they are not 0, write them into data
            for (int unsigned i = 0; i < CDB_NUM; i++) begin

                if (cdb_pd_array[i] != '0 && cdb_we_array[i])
                    data[cdb_pd_array[i]] <= cdb_funct_out_array[i];


                // if (pd_0_s != '0 && regf_we_0)
                //     data[pd_0_s] <= pd_0_v;
                // if (pd_1_s != '0 && regf_we_1)
                //     data[pd_1_s] <= pd_1_v;
                // if (pd_2_s != '0 && regf_we_2)
                //     data[pd_2_s] <= pd_2_v;
                // if (pd_3_s != '0 && regf_we_3)
                //     data[pd_3_s] <= pd_3_v;
            end

            // read logic
            for (int unsigned i = 0; i < 5; i++) begin
                rs1_v[i] <= (rs1_s[i] != '0) ? data[rs1_s[i]] : '0;
                rs2_v[i] <= (rs2_s[i] != '0) ? data[rs2_s[i]] : '0;
            end
        end
    end


    //! I probably shouldn't do combinational read here because
    //! of the long critical path. Try sequential read instead
    // combinational read with transparency
    // always_comb begin
        
    //     // transparency: check each index one by one. 
    //     // If match, output corresponding input
    //     // do this to all four ports
    //     // don't forward if index is 0
    //     for (int unsigned i = 0; i < 4; i++) begin
    //         if ((rs1_s[i] != '0) && (rs1_s[i] == pd_0_s))
    //             rs1_v[i] = pd_0_v;
    //         else if ((rs1_s[i] != '0) && (rs1_s[i] == pd_1_s))
    //             rs1_v[i] = pd_1_v;
    //         else if ((rs1_s[i] != '0) && (rs1_s[i] == pd_2_s))
    //             rs1_v[i] = pd_2_v;
    //         else if ((rs1_s[i] != '0) && (rs1_s[i] == pd_3_s))
    //             rs1_v[i] = pd_3_v;
    //         else
    //             rs1_v[i] = (rs1_s[i] != '0) ? data[rs1_s[i]] : '0;

    //         if ((rs2_s[i] != '0) && (rs2_s[i] == pd_0_s))
    //             rs2_v[i] = pd_0_v;
    //         else if ((rs2_s[i] != '0) && (rs2_s[i] == pd_1_s))
    //             rs2_v[i] = pd_1_v;
    //         else if ((rs2_s[i] != '0) && (rs2_s[i] == pd_2_s))
    //             rs2_v[i] = pd_2_v;
    //         else if ((rs2_s[i] != '0) && (rs2_s[i] == pd_3_s))  
    //             rs2_v[i] = pd_3_v;
    //         else
    //             rs2_v[i] = (rs2_s[i] != '0) ? data[rs2_s[i]] : '0;
    //     end
    // end

endmodule : phys_reg_file

