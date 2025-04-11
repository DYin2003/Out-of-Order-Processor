/*
    UVM env class, source: Youtube, siemens UVM basic - UVM "Hello World":
    https://www.youtube.com/watch?v=jK9Olt4pyKA&list=PLWPf2kTT1_Z20pIAfQJ2gyNXLCLM1kUPB&index=2
*/
import uvm_pkg::*;
class my_env extends uvm_env;
    // needs this whenever declaring a component
    `uvm_component_utils(my_env)

    // constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    // instantiate component here like agents, scoreboards, 
    // garbage collectors, etc
    function void build_phase(uvm_phase phase);
        
    endfunction: build_phase

    // only task based phase
    task run_phase(uvm_phase phase);

        phase.raise_objection(this);
        #10;
        phase.drop_objection(this);
        // only ends when all objection gets dropped

    endtask: run_phase

endclass: my_env