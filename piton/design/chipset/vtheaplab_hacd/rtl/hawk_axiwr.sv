
`include "hacd_define.vh"
import hacd_pkg::*;
module hawk_axiwr (
  	input wire clk_i,
  	input wire rst_ni,
	input logic send,
	input logic aw_only,
	input hacd_pkg::axi_wr_pld_t int_axi_req,
  	output hacd_pkg::axi_wr_reqpkt_t int_wr_reqpkt,
  	input hacd_pkg::axi_wr_rdypkt_t wr_rdypkt,
	output logic int_ready,
	output logic sent
);

logic [1:0] n_state,p_state;
hacd_pkg::axi_wr_pld_t p_axireq,n_axireq;
hacd_pkg::axi_wr_reqpkt_t n_wr_reqpkt,p_wr_reqpkt;
localparam IDLE	='d0,
	   CMND ='d1,
	   DATA ='d2,
	   DONE ='d3;
	   
always@* begin
	n_wr_reqpkt='d0;
	n_wr_reqpkt.addr=p_wr_reqpkt.addr;
	n_wr_reqpkt.awvalid = int_wr_reqpkt.awvalid && !wr_rdypkt.awready;
	n_state=p_state;
	case(p_state)
		IDLE: begin
			if(send) begin
				n_state=CMND;
			end
		end
		CMND: begin
			  if(/*wr_rdypkt.awready &&*/ !int_wr_reqpkt.awvalid) begin
				n_wr_reqpkt.addr=int_axi_req.addr;
				n_wr_reqpkt.awvalid=1'b1;
			  end
			  if (int_wr_reqpkt.awvalid && wr_rdypkt.awready)  begin
				if(aw_only) begin
				    n_state=DONE;
				end else begin
				    n_state=DATA;
				end
			  end
		end
		DATA:begin
			  if(wr_rdypkt.wready && !int_wr_reqpkt.wvalid) begin
				n_wr_reqpkt.data=int_axi_req.data;
				n_wr_reqpkt.strb=int_axi_req.strb;
				n_wr_reqpkt.wvalid=1'b1;
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
		p_wr_reqpkt <='d0;
	end
	else begin
 		p_state <= n_state;	
		p_wr_reqpkt <=n_wr_reqpkt;
	end
end
assign sent = p_state == DONE;
assign int_ready = p_state == IDLE;
assign int_wr_reqpkt = p_wr_reqpkt;

endmodule
