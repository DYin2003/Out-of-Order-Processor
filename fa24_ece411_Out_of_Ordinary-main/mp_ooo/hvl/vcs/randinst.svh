// This class generates random valid RISC-V instructions to test your
// RISC-V cores.

class RandInst;
    // You will increment this number as you generate more random instruction
    // types. Once finished, NUM_TYPES should be 9, for each opcode type in
    // rv32i_opcode.
    localparam NUM_TYPES = 9; 

    // Note that the `instr_t` type is from ../pkg/types.sv, there are TODOs
    // you must complete there to fully define `instr_t`.
    rand instr_t instr;
    rand bit [NUM_TYPES-1:0] instr_type; 
    rand bit [2:0] funct3_replacement;
    // rand bit [6:0] funct7_replacement;

    // Make sure we have an even distribution of instruction types.
    constraint solve_order_c { solve instr_type before instr; }

    // Hint/TODO: you will need another solve_order constraint for funct3
    // to get 100% coverage with 500 calls to .randomize().
    //? don't really understand this: if we have a different seed, is it 
    //? possible that it will end up with less coverage?
    constraint solve_order_funct3_c { solve funct3_replacement before instr; }
    // constraint solve_order_funct7_c { solve funct7_replacement before funct3_replacement; }

    // "replace" funct3
    constraint apply_order_funct3_c { instr.i_type.funct3 == funct3_replacement; }
    // constraint apply_order_funct7_c { instr.r_type.funct7 == funct7_replacement; }

    // no load or store: don't want to generate any load/store bc it raise a trap mismatch
    // I can just hard constraint source reg to be x0 instead of not testing anything
    constraint remove_load_store_c { (instr.i_type.opcode inside {op_b_imm, op_b_reg, op_b_lui}); } //op_b_auipc

    // Pick one of the instruction types.
    constraint instr_type_c {
        $countones(instr_type) == 1; // Ensures one-hot.
    }

    // Constraints for actually generating instructions, given the type.
    // Again, see the instruction set listings to see the valid set of
    // instructions, and constrain to meet it. Refer to ../pkg/types.sv
    // to see the typedef enums.

    constraint instr_c {
        // Reg-imm instructions
        instr_type[0] -> {
            instr.i_type.opcode == op_b_imm; // I type

            //* logical right shift, funct7 can either be base or variant
            // Implies syntax: if funct3 is arith_f3_sr, 
            // then funct7 must be one of two possibilities.
            instr.i_type.funct3 == arith_f3_sr -> {
                // Use r_type here to be able to constrain funct7.
                instr.r_type.funct7 inside {base, variant};
            }

            //* logical left shift, funct7 can only be base
            // This if syntax is equivalent to the implies syntax above
            // but also supports an else { ... } clause.
            if (instr.i_type.funct3 == arith_f3_sll) {
                instr.r_type.funct7 == base;
            }
        }

        // Reg-reg instructions
        instr_type[1] -> {
            // /TODO: Fill this out!
            instr.r_type.opcode == op_b_reg; // R type

            //* ADD or SUB or SR, when funct3 is 3'b000 or 3'b101 
            //* funct 7 can be base or variant 
            instr.r_type.funct3 inside {arith_f3_add, arith_f3_sr} -> {
                instr.r_type.funct7 inside {base, variant, mult_div};
            }

            //* for SLL (001), SLT (010), SLTU (011), XOR (100), OR (110), or
            //* AND (111): funct7 can only be base 
            instr.r_type.funct3 inside {arith_f3_sll, arith_f3_slt, 
            arith_f3_sltu, arith_f3_xor, arith_f3_or, arith_f3_and} -> {
                instr.r_type.funct7 inside {base, mult_div};
            }
        
        }

        // Store instructions -- these are easy to constrain!
        instr_type[2] -> {
            instr.s_type.opcode == op_b_store;
            instr.s_type.funct3 inside {store_f3_sb, store_f3_sh, store_f3_sw};
            instr.s_type.rs1 == 5'b00000;

            // constraint memory boundary
            instr.i_type.funct3 == store_f3_sw -> {
                instr.s_type.imm_s_bot[1:0] == 2'b00;
            }

            instr.i_type.funct3 == store_f3_sh -> {
                instr.s_type.imm_s_bot[0] == 1'b0;
            }  
        }

        // Load instructions
        instr_type[3] -> {
            instr.i_type.opcode == op_b_load; // I type
            instr.i_type.funct3 inside {load_f3_lb, load_f3_lh, load_f3_lw, load_f3_lbu, load_f3_lhu};
            instr.i_type.rs1 == 5'b00000;

            // constraint memory boundary
            instr.i_type.funct3 == load_f3_lw -> {
                instr.i_type.i_imm[1:0] == 2'b00;
            }

            instr.i_type.funct3 inside {load_f3_lh, load_f3_lhu} -> {
                instr.i_type.i_imm[0] == 1'b0;
            }            
        }

        // /TODO: Do all 9 types!
        //! not really sure how the opcode should be indexed

        // Branch instructions
        instr_type[4] -> {
            instr.b_type.opcode == op_b_br; // B type
            // constraint funct3
            instr.b_type.funct3 inside {branch_f3_beq, branch_f3_bne, branch_f3_blt,
                                        branch_f3_bge, branch_f3_bltu, branch_f3_bgeu};
        }    

        // JALR instructions
        instr_type[5] -> {
            instr.i_type.opcode == op_b_jalr; // I type
            // constraint funct3
            instr.i_type.funct3 == 3'b000; // should only be 3'b000
        } 

        // JAL instructions
        instr_type[6] -> {
            instr.j_type.opcode == op_b_jal; // I type
        }

        // AUIPC instructions
        instr_type[7] -> {
            instr.j_type.opcode == op_b_auipc; // U type
        }  

        // LUI instructions
        instr_type[8] -> {
            instr.j_type.opcode == op_b_lui; // U type
        }  
    }

    `include "../../hvl/vcs/instr_cg.svh"

    // Constructor, make sure we construct the covergroup.
    function new();
        instr_cg = new();
    endfunction : new

    // Whenever randomize() is called, sample the covergroup. This assumes
    // that every time you generate a random instruction, you send it into
    // the CPU.
    function void post_randomize();
        instr_cg.sample(this.instr);
    endfunction : post_randomize

    // A nice part of writing constraints is that we get constraint checking
    // for free -- this function will check if a bit vector is a valid RISC-V
    // instruction (assuming you have written all the relevant constraints).
    function bit verify_valid_instr(instr_t inp);
        bit valid = 1'b0;
        this.instr = inp;
        for (int i = 0; i < NUM_TYPES; ++i) begin
            this.instr_type = 1 << i;
            if (this.randomize(null)) begin
                valid = 1'b1;
                break;
            end
        end
        return valid;
    endfunction : verify_valid_instr

endclass : RandInst
