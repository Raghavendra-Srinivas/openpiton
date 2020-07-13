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

    output logic decomp_done
);


logic [3:0] zero_chunk_vec,n_zero_chunk_vec;
logic [3:0] chunk_exp_done,n_chunk_exp_done;

localparam [2:0] IDLE=0,
		 METADATA=1,
		 EXPAND=2,
		 FILL_ZEROS=3,
		 LD_FIFO_RDPTR=4,
		 FIFO_READ_TRNSFR=5,
		 DONE=6,
		 BUS_ERROR=7;

logic [2:0] n_state,p_state;
logic [6:0] n_cacheline_cnt,cacheline_cnt;
logic n_rd_req;
logic n_decomp_done;
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
	n_wr_req=1'b0;
	n_wr_data='d0;
	n_cacheline_cnt=cacheline_cnt; //'d0; 
	n_decomp_done = 1'b0;
	n_ld_rdfifo_rdptr = 1'b0;
	n_chunk_exp_done = chunk_exp_done;

	case(p_state) 
	  	IDLE: begin
			if(decomp_start && !rdfifo_empty) begin
				n_state<=METADATA;
			end
		end
		METADATA: begin
			//Read fist line : contains Metadata
			n_rd_req=!rdfifo_empty && send_rd_req; //&& !rd_req;
			if(rd_valid && send_rd_req) begin 
			      if (rd_rresp=='d0) begin
			            n_zero_chunk_vec = rd_data[3:0];
	 	  	       	n_state = EXPAND;
			      end
			      else begin
			            n_state= BUS_ERROR;
			      end
			end
		end
		EXPAND:begin
			n_cacheline_cnt = 'd0;
			if(&chunk_exp_done) begin
				  n_state= DONE;
			end
			else begin
			   if(!chunk_exp_done[0]) begin
			       if  (zero_chunk_vec[0]) begin
				   n_state= FILL_ZEROS;
			       end else begin
				   n_state= LD_FIFO_RDPTR;
			       end
			   end
			   else if(!chunk_exp_done[1]) begin
			       if  (zero_chunk_vec[1]) begin
				   n_state= FILL_ZEROS;
			       end else begin
				   n_state= LD_FIFO_RDPTR;
			       end
			   end	
			   else if(!chunk_exp_done[2]) begin
			       if  (zero_chunk_vec[2]) begin
				   n_state= FILL_ZEROS;
			       end else begin
				   n_state= LD_FIFO_RDPTR;
			       end
			   end	
			   else if(!chunk_exp_done[3]) begin
			       if  (zero_chunk_vec[3]) begin
				   n_state= FILL_ZEROS;
			       end else begin
				   n_state= LD_FIFO_RDPTR;
			       end
			   end	
			end
		end
		FILL_ZEROS:begin
		   if (cacheline_cnt == 'd16) begin
			   if	       (!chunk_exp_done[0]) begin
				         n_chunk_exp_done[0]= 1'b1;
			   end else if (!chunk_exp_done[1]) begin 
				         n_chunk_exp_done[1]= 1'b1;
			   end else if (!chunk_exp_done[2]) begin 
				         n_chunk_exp_done[2]= 1'b1;
			   end else if (!chunk_exp_done[3]) begin 
				         n_chunk_exp_done[3]= 1'b1;
			   end  
	 	       	n_state=EXPAND;
		   end
		   else if(cacheline_cnt < 'd16 && !wrfifo_full) begin
		      	n_cacheline_cnt = cacheline_cnt+'d1;
			n_wr_data = 'd0;
			n_wr_req  = 1'b1;
		   end
		end
		LD_FIFO_RDPTR: begin
		   	n_ld_rdfifo_rdptr = 1'b1; 
			n_rdfifo_rdptr = 'd1;
			if (!rd_valid) begin
				n_state=FIFO_READ_TRNSFR;
			end
		end
	 	FIFO_READ_TRNSFR: begin
	 	   	  n_rd_req=!rdfifo_empty && !wrfifo_full && send_rd_req; //issue read only if read fifo non-empty and write fifo is not full
	 	          if (cacheline_cnt == 'd16) begin
			   		if	    (!chunk_exp_done[0]) begin
			   		              n_chunk_exp_done[0]= 1'b1;
			   		end else if (!chunk_exp_done[1]) begin 
			   		              n_chunk_exp_done[1]= 1'b1;
			   		end else if (!chunk_exp_done[2]) begin 
			   		              n_chunk_exp_done[2]= 1'b1;
			   		end else if (!chunk_exp_done[3]) begin 
			   		              n_chunk_exp_done[3]= 1'b1;
			   		end  
	 	       		n_state=EXPAND;
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
	 	          if(decomp_start) begin //keep comp_done asserted till start goes low
	 	          	n_decomp_done = 1'b1;
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

		rdfifo_rdptr<='d0;
		ld_rdfifo_rdptr<=1'b0;
		
		chunk_exp_done<='d0;
		zero_chunk_vec <= 'd0;

		rd_req<=1'b0;

		wr_data='d0;
		wr_req=1'b0;
	
		decomp_done<=1'b0;
	end
	else begin
		p_state<=n_state;
		cacheline_cnt<=n_cacheline_cnt;
	
		rdfifo_rdptr<=n_rdfifo_rdptr;
		ld_rdfifo_rdptr<=n_ld_rdfifo_rdptr;
		
		chunk_exp_done<=n_chunk_exp_done;
		zero_chunk_vec <= n_zero_chunk_vec;
		
		rd_req<=n_rd_req;

		//Write	
		wr_data<=n_wr_data;
		wr_req<=n_wr_req;

		decomp_done <= n_decomp_done;
	end
end
endmodule

