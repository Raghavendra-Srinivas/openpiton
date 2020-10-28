module decompressor #(parameter FIFO_PTR_WIDTH=6)  (
    input clk_i,
    input rst_ni,

    input decomp_start,
    input logic [13:0] comp_size,

    output logic [FIFO_PTR_WIDTH-1:0] rdfifo_rdptr,
    output logic ld_rdfifo_rdptr,

    input rdfifo_empty,
    output logic rd_req,
    input [`HACD_AXI4_DATA_WIDTH-1:0] rd_data,
    input [1:0] rd_rresp,
    input rd_valid,

    input wrfifo_full,
    output logic wr_req,
    output logic [`HACD_AXI4_DATA_WIDTH-1:0] wr_data,

    output logic decomp_done,

    //Debug
    output hacd_pkg::debug_decompressor debug_decomp
);


huffmanDecompressorCacheLineWrapper decomp(
	.clock(clk_i),
	.reset(!rst_ni),
	.io_start(comp_start),
	.io_readPointer(rdfifo_rdptr),
	.io_loadReadPointer(ld_rd_fifo_rdptr),
	.io_readFifoEmpty(rdfifo_empty),
	.io_readReady(rd_req),
	.io_readData(rd_data),
	.io_readValid(rd_valid),
	.io_writeFifoFull(wrfifo_full),
	.io_writeRequest(wr_req),
	.io_writedata(wr_data),
	.io_done(comp_done)
);

//Debug
assign debug_decomp.cacheline_cnt=0;
assign debug_decomp.wr_data=0;
assign debug_decomp.wr_req=0;
assign debug_decomp.zero_chunk_vec= 0;
assign debug_decomp.chunk_exp_done=0;
assign debug_decomp.decomp_state=0;
assign debug_decomp.ila_trigger=0;

endmodule

