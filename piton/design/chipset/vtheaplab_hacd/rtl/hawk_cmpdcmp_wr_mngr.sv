`include "hacd_define.vh"
import hacd_pkg::*;
module hawk_cmpdcmp_wr_mngr(
    input clk_i,
    input rst_ni,

    output hacd_pkg::axi_wr_reqpkt_t int_wr_reqpkt,
    input hacd_pkg::axi_wr_rdypkt_t wr_rdypkt,
    //from compressor
    input cmpdcmp_trigger,
    input zspg_migrate,
    input hacd_pkg::iWayORcPagePkt_t iWayORcPagePkt,
    input hacd_pkg::zsPageMigratePkt_t zspg_mig_pkt,
    output cmpdcmp_done,
    output compact_done
);
//int axi_engine
logic sent;
logic send;
logic int_ready;
hacd_pkg::axi_wr_pld_t int_axi_req;
//
logic [6:0] n_burst_cnt,p_burst_cnt;
logic [2:0] n_state,p_state;
localparam IDLE		  ='d0,
	   CPAGE_TRNSFR   ='d1,
	   DCPAGE_TRNSFR  ='d2,
	   ZS_PAGE_UPDATE ='d3,
	   ZSPG_MIGRATE   ='d4,
	   ZSPG_MIGRATE_MD_UPDATE ='d5,
	   DONE		  ='d6;

function axi_wr_pld_t get_zspg_axi_wrpkt;
	input iWayORcPagePkt_t zs_pkt;
	get_zspg_axi_wrpkt.addr={{16{1'b0}},zs_pkt.iWay_ptr};
	get_zspg_axi_wrpkt.data={{16{1'b0}},zs_pkt.zsPgMd,zs_pkt.nxtWay_ptr,zs_pkt.iWay_ptr}; //MD is 50 bytes=50*8=400bit + 2 ptr = 12 bytes = 96 bits -> 496 bits fits in same cacheline
	get_zspg_axi_wrpkt.strb={{2{1'b0}},{62{1'b1}}}; 
endfunction

always@* begin
	n_state=p_state;
	send=1'b0;
	n_burst_cnt=p_burst_cnt;	
	case(p_state)
		IDLE: begin
			if(cmpdcmp_trigger) begin
				if(iWayORcPagePkt.comp_decomp) begin
					n_state=CPAGE_TRNSFR;
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
					n_state=ZSPG_MIGRATE_MD_UPDATE;
				    end	
			end
		end
		CPAGE_TRNSFR:begin
				if(int_ready) begin
					//Send dummy compressed data for now
			    		int_axi_req.addr=iWayORcPagePkt.cPage_byteStart;
					int_axi_req.data={32{16'h1234}};
					int_axi_req.strb={64{1'b1}};
					send=1'b1;
				end
				if(sent) begin
					n_state=ZS_PAGE_UPDATE;
				end
		end
		DCPAGE_TRNSFR:begin
				//Send dummy compressed data for now
				if(int_ready && (p_burst_cnt < 'd64)) begin
				   if(p_burst_cnt == 'd0) begin					
			    	   	int_axi_req.addr=iWayORcPagePkt.cPage_byteStart; //the same address will act as start of freeway for decompressed data
				   	n_burst_cnt = p_burst_cnt + 'd1;
				   end else begin
				   	int_axi_req.addr=int_wr_reqpkt.addr+'d64;
				   	n_burst_cnt = p_burst_cnt + 'd1;
				   end
				   int_axi_req.data={32{16'hF0F0}};
				   int_axi_req.strb={64{1'b1}};
				   send=1'b1;
				end
				if (p_burst_cnt[6]==1'b1 && sent) begin
				      n_state=ZS_PAGE_UPDATE;
				end
		end
		ZS_PAGE_UPDATE: begin
				if(int_ready) begin
			    		int_axi_req=get_zspg_axi_wrpkt(iWayORcPagePkt);
					send=1'b1;
				end
				if(sent) begin
					n_state=DONE;
				end
		end
		ZSPG_MIGRATE:begin
				if(int_ready) begin
					//Send dummy compressed data for now
			    		int_axi_req.addr=zspg_mig_pkt.dst_cpage_ptr;
					int_axi_req.data={32{16'h1234}}; //Here, We shoudl actually pop from read side fifo for compressed size; just writing known comp data for now
					int_axi_req.strb={64{1'b1}};
					send=1'b1;
				end
				if(sent) begin
					n_state=DONE;
				end
		end
		ZSPG_MIGRATE_MD_UPDATE:begin
				if(int_ready) begin
					//Send dummy compressed data for now
			    		int_axi_req.addr=zspg_mig_pkt.src_cpage_ptr;
					int_axi_req.data[(50*8-1)+2*48:2*48]=zspg_mig_pkt.md;
					int_axi_req.strb={64{1'b0}};
					int_axi_req.strb[61:12]={50{1'b1}}; //50bytes of metadata leaving 12 bytes for pointers at LSB.
					send=1'b1;
				end
				if(sent) begin
					n_state=DONE;
				end
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

hawk_axiwr u_hawk_axiwr(.*);
endmodule

