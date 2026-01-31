
interface jtag_interface();

logic tdo;
logic tck;
logic tms;
logic trstn;
logic tdi;

modport driver (   input tdo,
                output tck,
                output tms,
                output trstn,
                output tdi
);

modport tap (  output tdo,
                input tck,
                input tms,
                input trstn,
                input tdi
 );

endinterface
