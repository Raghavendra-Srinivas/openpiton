
module migrator #(parameter FIFO_PTR_WIDTH=6)  (
    input clk_i,
    input rst_ni,

    input migrate_start,
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

    output logic migrate_done,

    //Debug
    output hacd_pkg::debug_migrator debug_migrate
);

localparam [2:0] IDLE=0,
		 FIFO_TRNSFR=1,
		 DONE=2,
		 BUS_ERROR=3;

logic [2:0] n_state,p_state;
logic [6:0] n_cacheline_cnt,cacheline_cnt;
logic n_rd_req;
logic n_migrate_done;
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
	n_migrate_done = 1'b0;
	n_ld_rdfifo_rdptr = 1'b0;

	case(p_state) 
	  	IDLE: begin
			if(migrate_start && !rdfifo_empty) begin
				n_state = FIFO_TRNSFR;
 	             		n_cacheline_cnt = 'd0;
			end
		end
	 	FIFO_TRNSFR: begin
	 	   	  n_rd_req=!rdfifo_empty && !wrfifo_full && send_rd_req; //issue read only if read fifo non-empty and write fifo is not full
	 	          if (cacheline_cnt == 'd17) begin
	 	       		n_state=DONE;
	 	          end
	 	          else if(cacheline_cnt < 'd17 && rd_valid && send_rd_req) begin
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
	 	          if(migrate_start) begin //keep comp_done asserted till start goes low
	 	          	n_migrate_done = 1'b1;
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
		
		rd_req<=1'b0;

		wr_data<='d0;
		wr_req<=1'b0;
	
		migrate_done<=1'b0;
	end
	else begin
		p_state<=n_state;
		cacheline_cnt<=n_cacheline_cnt;
	
		rdfifo_rdptr<=n_rdfifo_rdptr;
		ld_rdfifo_rdptr<=n_ld_rdfifo_rdptr;
		
		rd_req<=n_rd_req;

		//Write	
		wr_data<=n_wr_data;
		wr_req<=n_wr_req;

		migrate_done <= n_migrate_done;
	end
end

//Debug
assign debug_migrate.cacheline_cnt=cacheline_cnt;
assign debug_migrate.wr_data=wr_data;
assign debug_migrate.wr_req=wr_req;
assign debug_migrate.migrate_state=p_state;

endmodule

