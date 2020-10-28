import hacd_pkg::*;

module compressor #(parameter FIFO_PTR_WIDTH=6)  (
	// The clock is active-high.
    input clk_i,
	// The reset is active-low.
    input rst_ni,

	// This tells the compressor when to start working
    input comp_start,
	// This tells the size of the compressed data. It is currently tied to 1088, the size of the metadata in a cache line, followed by the 1024 uncompressed
	// bytes.
    output logic [13:0] comp_size,

	// The readfifo read pointer tells which of the 64-byte lines of the data to access.
    output logic [FIFO_PTR_WIDTH-1:0] rdfifo_rdptr,
	// This lad readfifo read pointer bit tells the readfifo when to accept an address and get the data from that address.
    output logic ld_rdfifo_rdptr,

	// This tells whether or not the read fifo is empty.
    input rdfifo_empty,
	// This tells when to clear the current read because it has been read.
    output logic rd_req,
	// This data in cacheline is 64 bytes.
    input [`HACD_AXI4_DATA_WIDTH-1:0] rd_data,
	// When this is 0 and rd_valid is True, the rd_data cacheline is valid. Otherwise, 
    input [1:0] rd_rresp,
	// This is set to True when the fifo read data is 
    input rd_valid,

	// This lets the hardware know whether the write fifo can take any write data
    input wrfifo_full,
	// Tell the write fifo to write data
    output logic wr_req,
	// The cacheline output data is also 64 bytes.
    output logic [`HACD_AXI4_DATA_WIDTH-1:0] wr_data,

	// The compressor sets this flag bit if the input data cannot be compressed.
    output logic incompressible,
	// The compressor sets this flag bit when it is done compressing.
    output logic comp_done,

    //Debug
    output hacd_pkg::debug_compressor debug_comp
);

huffmanCompressorCacheLineWrapper comp(
	.clock(clk_i),
	.reset(!rst_ni),
	.io_start(comp_start),
	.io_compressedSize(comp_size),
	.io_readPointer(rdfifo_rdptr),
	.io_loadReadPointer(ld_rd_fifo_rdptr),
	.io_readFifoEmpty(rdfifo_empty),
	.io_readReady(rd_req),
	.io_readData(rd_data),
	.io_readValid(rd_valid),
	.io_writeFifoFull(wrfifo_full),
	.io_writeRequest(wr_req),
	.io_writedata(wr_data),
	.io_incompressible(incompressible),
	.io_done(comp_done)
);


//Debug
assign debug_comp.cacheline_cnt= 0;
assign debug_comp.zero_cline_cntr_curr= 0;
assign debug_comp.zero_chunk_vec= 0;
assign debug_comp.rd_data= 0;
assign debug_comp.rd_valid= 0;
assign debug_comp.comp_state = 0;

endmodule

