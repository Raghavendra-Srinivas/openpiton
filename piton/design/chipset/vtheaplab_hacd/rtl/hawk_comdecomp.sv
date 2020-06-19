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

`ifdef NAIVE_COMPRESSION
    ,
    output [FIFO_PTR_WIDTH-1:0] comp_fifo_ptr
`endif

);

`ifndef NAIVE_COMPRESSION
 	assign comp_size = 14'd64;
 	assign compdecomp_rready = !rdfifo_empty;
 	assign comp_done = comp_start && rdfifo_empty;

 	assign decomp_done = decomp_start && rdfifo_empty;

`else
 	//Naive Compression Unit
 	compressor u_compressor (
 	   .clk_i,
 	   .rst_ni,

 	   .comp_start,
 	   .comp_size,

 	   .fifo_ptr,

 	   .fifo_empty,
 	   .rd_req,
 	   .rd_data,
 	   .rd_valid,

 	   .fifo_full,
 	   .wr_req,
 	   .wr_data,

 	   .comp_done

 	);

 	//Naive Decompression Unit


`endif
 
endmodule
