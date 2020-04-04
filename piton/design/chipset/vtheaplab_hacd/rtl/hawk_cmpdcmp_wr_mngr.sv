`include "hacd_define.vh"
import hacd_pkg::*;
module hawk_cmpdcmp_wr_mngr(
    input clk_i,
    input rst_ni,

    output hacd_pkg::axi_wr_reqpkt_t int_wr_reqpkt,
    //from compressor
    input cmpdcmp_trigger,
    input hacd_pkg::iWayORcPagePkt_t iWayORcPagePkt,
    output zspg_updated
);
//int axi_engine
logic sent;
logic send;
logic int_ready;
hacd_pkg::axi_wr_pld_t int_axi_req;
//
logic [2:0] n_state,p_state;
localparam IDLE	='d0,
	   CMND ='d1,
	   DATA ='d2,
	   DONE ='d3;

always@* begin
	n_state=p_state;
	case(p_state)
		IDLE: begin
			if(send) begin
				n_state=CMND;
			end
		end
		ZS_PAGE_UPDATE: begin
			    	int_axi_req=get_zspg_axi_wrpkt(iWayORcPagePkt);
				send=int_ready;
				if(sent) begin
				   n_state=IDLE;
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
		p_wr_reqpkt <='d0;
	end
	else begin
 		p_state <= n_state;	
		p_wr_reqpkt <=n_wr_reqpkt;
	end
end
assign zspg_updated = p_state == DONE;

hawk_axiwr u_hawk_axiwr(.*);
endmodule

