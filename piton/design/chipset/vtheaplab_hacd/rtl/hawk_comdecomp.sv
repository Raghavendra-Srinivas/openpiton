module hawk_comdecomp (
  	input clk_i,
     input rst_ni,
    output logic [13:0] comp_size,
    input logic comp_start,
    output wire comp_done,
    input logic decomp_start,
    output wire decomp_done,

    //output wire rdfifo_rdptr_rst, //this would reset read pointer to zero
    input wire  rdfifo_empty,
    input wire  rdfifo_full,
    output wire compdecomp_rready
);
 assign comp_size = 14'd64;
 assign compdecomp_rready = !rdfifo_empty;
 assign comp_done = comp_start && rdfifo_empty;

 assign decomp_done = decomp_start && rdfifo_empty;

endmodule
