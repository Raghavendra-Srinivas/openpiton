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
    input logic migrate_start,
    output wire migrate_done,

    output wire incompressible,
    //output wire rdfifo_rdptr_rst, //this would reset read pointer to zero
    input wire  rdfifo_empty,
    input wire  wrfifo_full,
    output wire compdecomp_rready,

    input [`HACD_AXI4_DATA_WIDTH-1:0] rd_data,
    input [1:0] rd_rresp,
    input rd_valid,
    output [`FIFO_PTR_WIDTH-1:0] compdecomp_rdfifo_rdptr,
    output logic compdecomp_ld_rdfifo_rdptr,
    

    output compdecomp_wr_req,
    output [`HACD_AXI4_STRB_WIDTH -1:0] compdecomp_wr_strb,
    output [`HACD_AXI4_DATA_WIDTH-1:0] compdecomp_wr_data,

    //Debug
    output hacd_pkg::debug_compressor debug_comp,
    output hacd_pkg::debug_decompressor debug_decomp,
    output hacd_pkg::debug_migrator debug_migrate

);

`ifndef HAWK_NAIVE_COMPRESSION
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
logic [`FIFO_PTR_WIDTH-1:0] comp_rdfifo_rdptr,decomp_rdfifo_rdptr,migrate_rdfifo_rdptr;
logic comp_ld_rdfifo_rdptr,decomp_ld_rdfifo_rdptr,migrate_ld_rdfifo_rdptr;
logic comp_rd_req,decomp_rd_req,migrate_rd_req;
logic comp_wr_req,decomp_wr_req,migrate_wr_req;
logic [`HACD_AXI4_DATA_WIDTH-1:0] comp_wr_data,decomp_wr_data,migrate_wr_data;
logic [`HACD_AXI4_STRB_WIDTH -1:0] comp_wr_strb,decomp_wr_strb,migrate_wr_strb;

/*
assign compdecomp_rready = decomp_start ? decomp_rd_req : comp_rd_req;
assign compdecomp_ld_rdfifo_rdptr = decomp_start ? decomp_ld_rdfifo_rdptr : comp_ld_rdfifo_rdptr;
assign compdecomp_rdfifo_rdptr = decomp_start ? decomp_rdfifo_rdptr : comp_rdfifo_rdptr;

assign compdecomp_wr_req = decomp_start ? decomp_wr_req : comp_wr_req;
assign compdecomp_wr_strb = decomp_start ? decomp_wr_strb : comp_wr_strb;
assign compdecomp_wr_data = decomp_start ? decomp_wr_data : comp_wr_data;
*/

assign compdecomp_rready =  decomp_rd_req | comp_rd_req | migrate_rd_req;
assign compdecomp_ld_rdfifo_rdptr =  decomp_ld_rdfifo_rdptr | comp_ld_rdfifo_rdptr | migrate_ld_rdfifo_rdptr ;
assign compdecomp_rdfifo_rdptr =  decomp_start ? decomp_rdfifo_rdptr :
				    comp_start ?   comp_rdfifo_rdptr : migrate_rdfifo_rdptr;

assign compdecomp_wr_req =  decomp_wr_req | comp_wr_req | migrate_wr_req;
assign compdecomp_wr_strb =  decomp_wr_strb; // | comp_wr_strb ;
assign compdecomp_wr_data =  decomp_start ? decomp_wr_data :
			       comp_start ? comp_wr_data : migrate_wr_data;

assign comp_wr_strb = {`HACD_AXI4_STRB_WIDTH{1'b1}}; //not supporting air tight packign righ tnow..so, packign is at cacheline granularity

 	//Naive Compression Unit
 	compressor u_compressor (
 	   .clk_i,
 	   .rst_ni,

 	   .comp_start,
 	   .comp_size,

 	   .rdfifo_rdptr(comp_rdfifo_rdptr),
	   .ld_rdfifo_rdptr(comp_ld_rdfifo_rdptr),
 	   .rdfifo_empty,

 	   .rd_req(comp_rd_req),
 	   .rd_data,
	   .rd_rresp,
 	   .rd_valid,

 	   .wrfifo_full,
 	   .wr_req(comp_wr_req),
 	   .wr_data(comp_wr_data),
	
	   .incompressible,
 	   .comp_done,
	   
	   .debug_comp
 	);

assign decomp_wr_strb = {`HACD_AXI4_STRB_WIDTH{1'b1}}; //not supporting air tight packign righ tnow..so, packign is at cacheline granularity
 	//Naive Decompression Unit
 	decompressor u_decompressor (
 	   .clk_i,
 	   .rst_ni,

 	   .decomp_start,
 	   .comp_size,

 	   .rdfifo_rdptr(decomp_rdfifo_rdptr),
	   .ld_rdfifo_rdptr(decomp_ld_rdfifo_rdptr),
 	   .rdfifo_empty,

 	   .rd_req(decomp_rd_req),
 	   .rd_data,
	   .rd_rresp,
 	   .rd_valid,

 	   .wrfifo_full,
 	   .wr_req(decomp_wr_req),
 	   .wr_data(decomp_wr_data),
	
 	   .decomp_done,

	   .debug_decomp
 	);

assign migrate_wr_strb = {`HACD_AXI4_STRB_WIDTH{1'b1}}; //not supporting air tight packign righ tnow..so, packign is at cacheline granularity
 	//Naive Decompression Unit
 	migrator u_migrator (
 	   .clk_i,
 	   .rst_ni,

 	   .migrate_start,
 	   .comp_size,

 	   .rdfifo_rdptr(migrate_rdfifo_rdptr),
	   .ld_rdfifo_rdptr(migrate_ld_rdfifo_rdptr),
 	   .rdfifo_empty,

 	   .rd_req(migrate_rd_req),
 	   .rd_data,
	   .rd_rresp,
 	   .rd_valid,

 	   .wrfifo_full,
 	   .wr_req(migrate_wr_req),
 	   .wr_data(migrate_wr_data),
	
 	   .migrate_done,

	   .debug_migrate
 	);


`endif
 
endmodule
