/*
    UVM test class, source: Youtube, siemens UVM basic - UVM "Hello World":
    https://www.youtube.com/watch?v=jK9Olt4pyKA&list=PLWPf2kTT1_Z20pIAfQJ2gyNXLCLM1kUPB&index=2
*/
import uvm_pkg::*;
class my_test extends uvm_test;
    // needs this whenever declaring a component
    `uvm_component_utils(my_test)

    my_env my_env_h; // _h for handle

    // constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        // type_id::create() is a type-specific static method that returns 
        // an instant of of the desired type from the factory.
        // it uses the same arguments as the constructor (calls constructor)
        my_env_h = my_env::type_id::create("my_env_h", this);
    endfunction: build_phase

endclass: my_test