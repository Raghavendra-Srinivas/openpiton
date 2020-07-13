
`include "hacd_define.vh"
import hacd_pkg::*;
module hawk_cmpdcmp_wr_mngr(
    input clk_i,
    input rst_ni,

    //FIFO
    input wire wrfifo_empty,
    input hacd_pkg::axi_wr_reqpkt_t wr_reqpkt,
    output hacd_pkg::axi_wr_reqpkt_t int_wr_reqpkt,
    input hacd_pkg::axi_wr_rdypkt_t wr_rdypkt,
    //from compressor
    input cmpdcmp_trigger,
    input zspg_migrate,
    input hacd_pkg::iWayORcPagePkt_t iWayORcPagePkt,
    input hacd_pkg::zsPageMigratePkt_t zspg_mig_pkt,
    output cmpdcmp_done,
    output compact_done,

    //Debug
    output hacd_pkg::debug_pgwr_cmpdcmp_mngr debug_cmpdcmp_mngr 
);

localparam IDLE		  		='d0,
	   CPAGE_TRNSFR   		='d1,
	   DUMMY_CPAGE_DATA 		='d2,
	   DCPAGE_TRNSFR  		='d3,
	   DUMMY_DCPAGE_DATA 		='d4,
	   ZS_PAGE_UPDATE_ADDR  	='d5,
	   ZS_PAGE_UPDATE_DATA  	='d6,
	   ZSPG_MIGRATE   		='d7,
	   ZSPG_MIGRATE_MD_UPDATE_ADDR  ='d8,
	   ZSPG_MIGRATE_MD_UPDATE_DATA  ='d9,
	   DONE		  		='d10;


function axi_wr_pld_t get_zspg_axi_wrpkt;
	input iWayORcPagePkt_t zs_pkt;
	get_zspg_axi_wrpkt.addr={{16{1'b0}},zs_pkt.iWay_ptr};
	get_zspg_axi_wrpkt.data={{16{1'b0}},zs_pkt.zsPgMd,zs_pkt.nxtWay_ptr,zs_pkt.iWay_ptr}; //MD is 50 bytes=50*8=400bit + 2 ptr = 12 bytes = 96 bits -> 496 bits fits in same cacheline
	get_zspg_axi_wrpkt.strb={{2{1'b0}},{62{1'b1}}}; 
endfunction

logic [6:0] n_burst_cnt,p_burst_cnt;
logic [3:0] n_state,p_state;
hacd_pkg::axi_wr_pld_t zspg_axi_wrpkt;

always@* begin
	n_state=p_state;
	n_burst_cnt=p_burst_cnt;
	//axi
	int_wr_reqpkt=wr_reqpkt;
	int_wr_reqpkt.awvalid=wr_reqpkt.awvalid && !wr_rdypkt.awready;
	int_wr_reqpkt.wvalid=1'b0;

	case(p_state)
		IDLE: begin
			if(cmpdcmp_trigger) begin
				if(iWayORcPagePkt.comp_decomp) begin
					n_state=CPAGE_TRNSFR;
					n_burst_cnt = 'd0; //(iWayORcPagePkt.cpage_size/64) ; //compressed size in bytes divided by cache line size in bytes gives # of cache line to tranfer // for now I supprot only cache alinged layout//'d0;
				end
				else begin
					n_state=DCPAGE_TRNSFR;
					n_burst_cnt = 'd0;
				end
			end
			else if (zspg_migrate) begin
				    if(zspg_mig_pkt.migrate) begin
					n_state=ZSPG_MIGRATE;
				    end
				    else if(zspg_mig_pkt.zspg_update) begin
					n_state=ZSPG_MIGRATE_MD_UPDATE_ADDR;
				    end	
			end
		end
		CPAGE_TRNSFR:begin
				//Alternative to burst count is Tranfer till Wr-Fifo gets empty
			 	if(/*awready &&*/ !wr_reqpkt.awvalid) begin
			 	       `ifdef HAWK_NAIVE_COMPRESSION
			 	         	if(p_burst_cnt<'d17/*!wrfifo_empty*/) begin
			 	         	 	if(p_burst_cnt == 'd0) begin					
			 	   	  	 		int_wr_reqpkt.addr=iWayORcPagePkt.cPage_byteStart; //the same address will act as start of freeway for decompressed data
			 	         	 	end else begin
			 	         	 		int_wr_reqpkt.addr=wr_reqpkt.addr+'d64;
			 	         	 	end
			 	         	 		n_burst_cnt = p_burst_cnt + 'd1;
			 	       			int_wr_reqpkt.awvalid=1'b1;
			 	         	end
			 	         	else begin
			 	         	            n_state=ZS_PAGE_UPDATE_ADDR;
			 	         	end 
			 	       `else
			 	       	//Send dummy compressed data for now
			 	   		int_wr_reqpkt.addr=iWayORcPagePkt.cPage_byteStart;
			 	       		int_wr_reqpkt.awvalid=1'b1;
			 	         	n_state=DUMMY_CPAGE_DATA;
			 	       `endif
			 	end
		end
		DUMMY_CPAGE_DATA:begin
			  if(wr_rdypkt.wready && !wr_reqpkt.wvalid) begin //data has been already set, in prev state, just assert wvalid
					int_wr_reqpkt.data={32{16'h1234}};
					int_wr_reqpkt.strb={64{1'b1}};
			 	       	int_wr_reqpkt.wvalid=1'b1;
					n_state=ZS_PAGE_UPDATE_ADDR;
			  end
		end
		DCPAGE_TRNSFR:begin
				//Send dummy compressed data for now
				if(!wr_reqpkt.awvalid && !wrfifo_empty && (p_burst_cnt < 'd64)) begin
				   if(p_burst_cnt == 'd0) begin					
			    	   	int_wr_reqpkt.addr=iWayORcPagePkt.cPage_byteStart; //the same address will act as start of freeway for decompressed data
				   	n_burst_cnt = p_burst_cnt + 'd1;
				   end else begin
				   	int_wr_reqpkt.addr=wr_reqpkt.addr+'d64;
				   	n_burst_cnt = p_burst_cnt + 'd1;
				   end
				end
				if (p_burst_cnt[6]==1'b1 && wr_reqpkt.awvalid && wr_rdypkt.awready) begin
				      n_state=ZS_PAGE_UPDATE_ADDR;
				end
		end
		DUMMY_DCPAGE_DATA:begin
			  if(wr_rdypkt.wready && !wr_reqpkt.wvalid) begin 
				   	int_wr_reqpkt.data={32{16'hF0F0}};
					int_wr_reqpkt.strb={64{1'b1}};
			 	       	int_wr_reqpkt.wvalid=1'b1;
					n_state=DUMMY_DCPAGE_DATA;
			  end
		end
	   	ZS_PAGE_UPDATE_ADDR:begin
			 	if(/*awready &&*/ !wr_reqpkt.awvalid) begin
					int_wr_reqpkt.addr={{16{1'b0}},iWayORcPagePkt.iWay_ptr};
			 	       	int_wr_reqpkt.awvalid=1'b1;
				end
				if (wr_reqpkt.awvalid && wr_rdypkt.awready) begin
					n_state=ZS_PAGE_UPDATE_DATA;
				end
		end
	   	ZS_PAGE_UPDATE_DATA:begin
			  if(wr_rdypkt.wready && !wr_reqpkt.wvalid) begin 
					int_wr_reqpkt.data={{16{1'b0}},iWayORcPagePkt.zsPgMd,iWayORcPagePkt.nxtWay_ptr,iWayORcPagePkt.iWay_ptr};
					//MD is 50 bytes=50*8=400bit + 2 ptr = 12 bytes = 96 bits -> 496 bits fits in same cacheline
					int_wr_reqpkt.strb={{2{1'b0}},{62{1'b1}}};
			 	       	int_wr_reqpkt.wvalid=1'b1;
					n_state=DONE;
			  end
		end
	   	ZSPG_MIGRATE:begin //placeholder
				n_state=IDLE;
		end
	   	ZSPG_MIGRATE_MD_UPDATE_ADDR:begin //placeholder
				n_state=IDLE;
		end
	   	ZSPG_MIGRATE_MD_UPDATE_DATA:begin //placeholder
				n_state=IDLE;
		end
		DONE:begin
				n_state=IDLE;
		end
endcase
end

always @(posedge clk_i or negedge rst_ni)
begin
	if(!rst_ni) begin
		p_state <= IDLE;
		p_burst_cnt <= 'd0;
	end
	else begin
 		p_state <= n_state;	
		p_burst_cnt <= n_burst_cnt;
	end
end
assign cmpdcmp_done = p_state == DONE;

assign debug_cmpdcmp_mngr.cPage_byteStart=iWayORcPagePkt.cPage_byteStart;
assign debug_cmpdcmp_mngr.cmpdcmp_mngr_state=p_state;

endmodule

