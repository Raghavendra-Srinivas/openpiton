`include "hacd_define.vh"
import hacd_pkg::*;
module hawk_comdecomp (
    input clk_i,
    input rst_ni,
    output logic [13:0] comp_size,
    input logic comp_start,
    output wire comp_done,
    input logic decomp_start,
    output wire decomp_done,

    output wire incompressible,
    //output wire rdfifo_rdptr_rst, //this would reset read pointer to zero
    input wire  rdfifo_empty,
    input wire  wrfifo_full,
    output wire compdecomp_rready,

    input [`HACD_AXI4_DATA_WIDTH-1:0] rd_data,
    input [1:0] rd_rresp,
    input rd_valid,
    output [`FIFO_PTR_WIDTH-1:0] rdfifo_rdptr,
    output logic ld_rdfifo_rdptr,
    

    output wr_req,
    output [`HACD_AXI4_STRB_WIDTH -1:0] wr_strb,
    output [`HACD_AXI4_DATA_WIDTH-1:0] wr_data

);

`ifndef NAIVE_COMPRESSION
 	assign comp_size = 14'd64;
 	assign compdecomp_rready = !rdfifo_empty;
 	assign comp_done = comp_start && rdfifo_empty;

	assign incompressible = 1'b0;

 	assign decomp_done = decomp_start && rdfifo_empty;
	assign rdfifo_rdptr = 'd0;
	
	assign wr_req  = 1'b0;
	assign wr_strb = 'd0;
	assign wr_data = 'd0;
	

`else
wire rd_req;

assign compdecomp_rready = rd_req; //||
assign wr_strb = {`HACD_AXI4_STRB_WIDTH{1'b1}}; //not supporting air tight packign righ tnow..so, packign is at cacheline granularity
 	//Naive Compression Unit
 	compressor u_compressor (
 	   .clk_i,
 	   .rst_ni,

 	   .comp_start,
 	   .comp_size,

 	   .rdfifo_rdptr,
	   .ld_rdfifo_rdptr,
 	   .rdfifo_empty,

 	   .rd_req,
 	   .rd_data,
	   .rd_rresp,
 	   .rd_valid,

 	   .fifo_full(wrfifo_full),
 	   .wr_req,
 	   .wr_data,
	
	   .incompressible,
 	   .comp_done

 	);

 	//Naive Decompression Unit


`endif
 
endmodule
