module hawk_comdecomp (
    output logic [13:0] comp_size,
    input logic comp_start,
    output comp_done,

    output wire rdfifo_rdptr_rst, //this would reset read pointer to zero
    input wire  rdfifo_empty,
    input wire  rdfifo_full
);
 assign comp_size = 128;
 assign comp_done = comp_start;


endmodule
