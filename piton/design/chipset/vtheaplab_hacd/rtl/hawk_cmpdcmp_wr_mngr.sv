`include "hacd_define.vh"
import hacd_pkg::*;
module hawk_cmpdcmp_wr_mngr(
    input clk_i,
    input rst_ni,

    output hacd_pkg::axi_wr_reqpkt_t int_wr_reqpkt,
    input hacd_pkg::axi_wr_rdypkt_t wr_rdypkt,
    //from compressor
    input cmpdcmp_trigger,
    input hacd_pkg::iWayORcPagePkt_t iWayORcPagePkt,
    output cmpdcmp_done
);
//int axi_engine
logic sent;
logic send;
logic int_ready;
hacd_pkg::axi_wr_pld_t int_axi_req;
//
logic [2:0] n_state,p_state;
localparam IDLE	='d0,
	   ZS_PAGE_UPDATE ='d1,
	   CPAGE_TRNSFR ='d2,
	   DONE ='d3;

function axi_wr_pld_t get_zspg_axi_wrpkt;
	input iWayORcPagePkt_t zs_pkt;
	get_zspg_axi_wrpkt.addr={{16{1'b0}},zs_pkt.iWay_ptr};
	get_zspg_axi_wrpkt.data={{16{1'b0}},zs_pkt.iWay_ptr,zs_pkt.nxtWay_ptr,zs_pkt.zsPgMd}; //MD is 50 bytes=50*8=400bit + 2 ptr = 12 bytes = 96 bits -> 496 bits fits in same cacheline
	get_zspg_axi_wrpkt.strb={{2{1'b0}},{62{1'b1}}}; 
endfunction

always@* begin
	n_state=p_state;
	send=1'b0;
	case(p_state)
		IDLE: begin
			if(cmpdcmp_trigger) begin
				n_state=ZS_PAGE_UPDATE;
			end
		end
		ZS_PAGE_UPDATE: begin
			    	int_axi_req=get_zspg_axi_wrpkt(iWayORcPagePkt);
				send=int_ready;
				if(sent) begin
				   n_state=CPAGE_TRNSFR;
				end
		end
		CPAGE_TRNSFR:begin
				//Send dummy compressed data for now
			    	int_axi_req.addr=iWayORcPagePkt.cPage_byteStart;
				int_axi_req.data={32{16'h1234}};
				int_axi_req.strb={64{1'b1}};
				send=int_ready;
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
	end
	else begin
 		p_state <= n_state;	
	end
end
assign cmpdcmp_done = p_state == DONE;

hawk_axiwr u_hawk_axiwr(.*);
endmodule

