import hacd_pkg::*;

module compressor #(parameter FIFO_PTR_WIDTH=6)  (
    input clk_i,
    input rst_ni,

    input comp_start,
    output logic [13:0] comp_size,

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

    output logic incompressible,
    output logic comp_done,

    //Debug
    output hacd_pkg::debug_compressor debug_comp
);

// Zero chunk metadata
// 4 chunks , each of 16 cache lines
logic [3:0] zero_chunk_vec;

logic [6:0] n_zero_cline_cntr_curr,zero_cline_cntr_curr;
logic [6:0] zero_cline_cntr_prev;

logic [2:0] zero_chunk_cnt;
wire compress;
assign zero_chunk_cnt = zero_chunk_vec[0] + zero_chunk_vec[1] + zero_chunk_vec[2] + zero_chunk_vec[3];
//assign compress = zero_cline_cntr_curr =='h3F;  
assign compress = zero_chunk_cnt >= 3;
//assign compress = zero_chunk_cnt == 3;  //This needs exactly any 3 chunks to be zero, so all 4 chunks as zero would go as in-compressible page

localparam [2:0] IDLE=0,
		 COMP_CHECK1=1,
		 COMP_CHECK2=2,
		 COMPRESS=3,
		 LOAD_FIFO_RDPTR=4,
		 FIFO_READ_TRNSFR=5,
		 DONE=6,
		 BUS_ERROR=7;

logic [2:0] n_state,p_state;
logic [6:0] n_cacheline_cnt,cacheline_cnt;
logic n_rd_req;
logic n_incompressible; 
logic n_comp_done;
logic n_ld_rdfifo_rdptr;
logic [FIFO_PTR_WIDTH-1:0] n_rdfifo_rdptr;
logic [`HACD_AXI4_DATA_WIDTH-1:0] n_wr_data;
logic n_wr_req;

logic send_rd_req; 
always @(posedge clk_i or negedge rst_ni)
begin
	if(!rst_ni) begin
		send_rd_req <=1'b0;
	end
	else if(!rd_valid)begin
		send_rd_req <=1'b1;
	end
	else if(!rd_req)begin
		send_rd_req <=1'b0;
	end
end

always@(*) begin
	n_state = p_state;
	n_rd_req=1'b0;
	n_cacheline_cnt=cacheline_cnt; //'d0; //cacheline_cnt;
	n_zero_cline_cntr_curr=zero_cline_cntr_curr;
	n_incompressible=1'b0;
	n_comp_done = 1'b0;
	n_ld_rdfifo_rdptr = 1'b0;
	n_wr_req = 1'b0;

	case(p_state) 
	  	IDLE: begin
			if(comp_start && !rdfifo_empty) begin
				n_state<=COMP_CHECK1;
				n_zero_cline_cntr_curr = 'd0;
				n_cacheline_cnt='d0; 
			end
		end
	  COMP_CHECK1: begin
			n_rd_req=!rdfifo_empty && send_rd_req;
			if (cacheline_cnt == 'd64) begin
				n_state=COMP_CHECK2;
			end
			else if(cacheline_cnt < 'd64 && rd_valid && send_rd_req) begin
				if(rd_rresp=='d0) begin
			   		n_cacheline_cnt=cacheline_cnt+'d1;
				 	if(rd_data =='d0) begin
						n_zero_cline_cntr_curr = zero_cline_cntr_curr + 'd1;
				 	end	
				end else begin
					n_state=BUS_ERROR;
				end	
			end
		end
	  COMP_CHECK2: begin
			if(compress) begin
				n_state=COMPRESS;
			end else begin
				n_state=IDLE;
				n_incompressible=1'b1;
			end
		end
	 COMPRESS: begin //naive compression just send metadata in first cache line then , follwed by non-zero 16 cacheline chunk.
			//reset rd pointer only to rd_fifo
			if(!wrfifo_full) begin
	 		   n_state=LOAD_FIFO_RDPTR;
			   n_wr_data = {'d0,zero_chunk_vec};
			   n_wr_req = 1'b1;
			end
	 	end
	 LOAD_FIFO_RDPTR:begin
		//if(!zero_chunk_vec[0]) begin
	 	//   n_rdfifo_rdptr = 0;
		//end else if (!zero_chunk_vec[1]) begin
	 	//   n_rdfifo_rdptr = 'd15;
		//end
		   n_rdfifo_rdptr = (!zero_chunk_vec[0]) ? 'd0  : 
			            (!zero_chunk_vec[1]) ? 'd15 :	
			            (!zero_chunk_vec[2]) ? 'd31 :	
			            (!zero_chunk_vec[3]) ? 'd47 : 'd0;	
	
		   n_ld_rdfifo_rdptr = 1'b1; //~(&zero_chunk_vec); //at-least one bit is zero //this is taken care off in "compress" detectability
	 	   n_state=FIFO_READ_TRNSFR;
		   n_cacheline_cnt = 'd0;
	 end
	 FIFO_READ_TRNSFR: begin
	 	   n_rd_req=!rdfifo_empty && !wrfifo_full && send_rd_req; //issue read only if read fifo non-empty and write fifo is not full
		   if (cacheline_cnt == 'd16) begin
			n_state=DONE;
		   end
		   else if(cacheline_cnt < 'd16 && rd_valid && send_rd_req) begin
			if(rd_rresp=='d0) begin
		      		n_cacheline_cnt = cacheline_cnt+'d1;
		   		n_wr_data = rd_data;
				n_wr_req  = 1'b1;
			end else begin
				n_state=BUS_ERROR;
			end	
		   end		
	 end
	 DONE: begin
		   if(comp_start) begin //keep comp_done asserted till start goes low
		   	n_comp_done = 1'b1;
		   end
		   else begin
	   	   	n_state = IDLE;
		   end
	 end
	 BUS_ERROR: begin
			   //assert trigger, connect it to spare LED.
			   //Stay here forever unless, user resets
			   n_state = BUS_ERROR;
	 end

	endcase
end

always @(posedge clk_i or negedge rst_ni)
begin
	if(!rst_ni) begin
		p_state<=IDLE;
		cacheline_cnt<='d0;
		incompressible<=1'b0;
		zero_cline_cntr_curr<='d0;
		rd_req<=1'b0;

		rdfifo_rdptr<='d0;
		ld_rdfifo_rdptr<=1'b0;

		wr_data<='d0;
		wr_req<=1'b0;
	
		comp_done<=1'b0;
	end
	else begin
		p_state<=n_state;
		cacheline_cnt<=n_cacheline_cnt;
		incompressible<=n_incompressible;
		zero_cline_cntr_curr<=n_zero_cline_cntr_curr;
		rd_req<=n_rd_req;
	
		rdfifo_rdptr<=n_rdfifo_rdptr;
		ld_rdfifo_rdptr<=n_ld_rdfifo_rdptr;

		//Write	
		wr_data<=n_wr_data;
		wr_req<=n_wr_req;

		comp_done <= n_comp_done;
	end
end


always @(posedge clk_i or negedge rst_ni) begin
	if(!rst_ni) begin
		zero_chunk_vec[0]<= 'd0;
		zero_chunk_vec[1]<= 'd0;
		zero_chunk_vec[2]<= 'd0;
		zero_chunk_vec[3]<= 'd0;
		zero_cline_cntr_prev <= 'd0;
	end else begin
		
		if(p_state==IDLE) begin
			zero_chunk_vec[0]<= 'd0;
			zero_chunk_vec[1]<= 'd0;
			zero_chunk_vec[2]<= 'd0;
			zero_chunk_vec[3]<= 'd0;
			zero_cline_cntr_prev <= 'd0;
		end
		else if(p_state==COMP_CHECK1) begin
 			if(cacheline_cnt=='d16) begin
 			        zero_chunk_vec[0] <= ((zero_cline_cntr_curr - zero_cline_cntr_prev) == 'd16);	
				zero_cline_cntr_prev <= zero_cline_cntr_curr;		
 			end
 			else if (cacheline_cnt=='d32) begin
 			        zero_chunk_vec[1] <= ((zero_cline_cntr_curr - zero_cline_cntr_prev) == 'd16);	
				zero_cline_cntr_prev <= zero_cline_cntr_curr;		
 			end
 			else if (cacheline_cnt=='d48) begin
 			        zero_chunk_vec[2] <= ((zero_cline_cntr_curr - zero_cline_cntr_prev) == 'd16);	
				zero_cline_cntr_prev <= zero_cline_cntr_curr;		
 			end
 			else if (cacheline_cnt=='d64) begin
 			        zero_chunk_vec[3] <= ((zero_cline_cntr_curr - zero_cline_cntr_prev) == 'd16);	
				zero_cline_cntr_prev <= zero_cline_cntr_curr;		
 			end
		end
 	end	
end


assign comp_size = 'd1088;

//Debug
assign debug_comp.cacheline_cnt= cacheline_cnt;
assign debug_comp.zero_cline_cntr_curr= zero_cline_cntr_curr;
assign debug_comp.zero_chunk_vec= zero_chunk_vec;
assign debug_comp.rd_data= rd_data;
assign debug_comp.rd_valid= rd_valid;
assign debug_comp.comp_state = p_state;

endmodule

