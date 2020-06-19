module compressor #(parameter FIFO_PTR_WIDTH=6)  (
    input clk_i,
    input rst_ni,

    input comp_start,
    output logic [13:0] comp_size,

    output [FIFO_PTR_WIDTH-1:0] fifo_ptr,

    input fifo_empty,
    output rd_req,
    input [`HACD_AXI4_DATA_WIDTH-1:0] rd_data,
    input rd_valid,

    input fifo_full,
    output wr_req,
    output [`HACD_AXI4_DATA_WIDTH-1:0] wr_data,

    output comp_done
);

// Zero chunk metadata
// 4 chunks , each of 16 cache lines
logic [3:0] zero_chunk_vec;
logic [3:0] zero_chunk_vec_nxt;

logic [6:0] n_zero_cline_cntr_curr,zero_cline_cntr_curr;
logic [6:0] zero_cline_cntr_prev;

logic [2:0] zero_chunk_cnt;
wire compress;
assign zero_chunk_cnt = zero_chunk_vec[0] + zero_chunk_vec[1] + zero_chunk_vec[2] + zero_chunk_vec[3];
assign compress = zero_chunk_cnt >= 3;

//Read Logic
//Read Entire Page and Check if it's compresssible

localparam [2:0] IDLE=0,
		 COMP_CHECK1=1,
		 COMP_CHECK2=2,
		 COMPRESS=3,
		 LOAD_FIFO_RDPTR=4,
		 FIFO_READ_TRNSFR=5,
		 DONE=6;

logic [2:0] n_state,p_state;
logic [6:0] n_cacheline_cnt,cacheline_cnt;
logic n_rd_req;
logic n_incompressible; 
logic n_comp_done;

always@(*) begin
	n_state = p_state;
	n_rd_req=1'b0;
	n_cacheline_cnt='d0; //cacheline_cnt;
	n_zero_cline_cntr_curr=zero_cline_cntr_curr;
	n_incompressible=1'b0;
	n_comp_done = 1'b0;
	case(p_state) 
	  	IDLE: begin
			if(comp_start && !fifo_empty) begin
				n_state<=COMP_CHECK1;
			end
		end
	  COMP_CHECK1: begin
			n_rd_req=!fifo_empty;
			if (cacheline_cnt == 'd64) begin
				n_state=COMP_CHECK2;
			end
			else if(cacheline_cnt < 'd64 && rd_valid) begin
			   	n_cacheline_cnt=cacheline_cnt+'d1;
				 if(rd_data =='d0) begin
					n_zero_cline_cntr_curr = zero_cline_cntr_curr + 'd1;
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
			if(!fifo_full) begin
	 		   n_state=LOAD_FIFO_RDPTR;
			   n_wrd_ata = {zero_chunk_vec,'d0};
			   n_wr_req = 1'b1;
			end
	 	end
	 LOAD_FIFO_RDPTR:begin
		//if(!zero_chunk_vec[0]) begin
	 	//   n_fifo_ptr = 0;
		//end else if (!zero_chunk_vec[1]) begin
	 	//   n_fifo_ptr = 'd15;
		//end
		   n_fifo_ptr = (!zero_chunk_vec[0]) ? 'd0  : 
			     (!zero_chunk_vec[1]) ? 'd15 :	
			     (!zero_chunk_vec[2]) ? 'd31 :	
			     (!zero_chunk_vec[3]) ? 'd47 ;	
	
		   n_ld_fifo_ptr = 1'b1;
	 	   n_state=FIFO_READ_TRNSFR;
		   n_cacheline_cnt = 'd0;
	 end
	 FIFO_READ_TRNSFR: begin
		   rd_req=!fifo_empty;
		   if (cacheline_cnt == 'd16) begin
			n_state=DONE;
		   end
		   else if(cacheline_cnt < 'd64 && rd_valid) begin
		      	n_cacheline_cnt = cacheline_cnt+'d1;
		   	n_wr_data = rd_data;
			n_wr_req  = 1'b1;
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

	endcase
	end
end

always @(posedge clk_i or negedge rst_ni)
begin
	if(!rst_ni) begin
		p_state<=IDLE;
		cacheline_cnt<='d0;
		incompressible<=1'b0;
		zero_cline_cntr_curr<='d0;

		wr_data='d0;
		wr_req=1'b0;
	
		comp_done<=1'b0;
	end
	else begin
		p_state<=n_state;
		cacheline_cnt<=n_cacheline_cnt;
		incompressible<=n_incompressible;
		zero_cline_cntr_curr=n_zero_cline_cntr_curr;
	
		fifo_ptr<=n_fifo_ptr;
		//Write	
		wr_data<=n_wr_data;
		wr_req<=n_wr_req;

		comp_done <= n_comp_done;
	end
end


always @(posedge clk_i or negedge rst_ni) begin
	if(!rst_ni) begin
		cacheline_cnt<='d0;
		zero_cline_cntr_curr <= 'd0;
		zero_cline_cntr_prev <= 'd0;
	end else begin
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


assign comp_size = 'd1088;


endmodule

