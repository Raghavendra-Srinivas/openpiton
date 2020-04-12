`include "hacd_define.vh"
import hacd_pkg::*;
import hawk_rd_pkg::*;
`define FSM_WID_DCMP_MNGR 4
module hawk_decomp_mngr (
    input clk_i,
    input rst_ni,

    input decomp_trigger,
    input [`HACD_AXI4_ADDR_WIDTH-1:0] decomp_cPage_byteStart, 
    input [`HACD_AXI4_ADDR_WIDTH-1:0] decomp_freeWay, 
    input hacd_pkg::hawk_tol_ht_t tol_HT,
    input logic [clogb2(ATT_ENTRY_MAX)-1:0] p_attEntryId,
    input pgwr_mngr_ready,
    input tbl_update_done,

    //handshake with PWM
    input zspg_updated,	
    output logic decomp_rdm_reset,

    output logic decomp_start,
    input wire decomp_done,
    output hacd_pkg::iWayORcPagePkt_t dc_iWayORcPagePkt,
  
    //from AXI FIFO
    input wire rdfifo_full,
    input wire rdfifo_empty,

    //AXI inputs  
    input hacd_pkg::axi_rd_rdypkt_t rd_rdypkt,
    input hacd_pkg::axi_rd_resppkt_t rd_resppkt,
     
    //previous AXI commands
    input hacd_pkg::axi_rd_pld_t p_axireq,
    input logic [`HACD_AXI4_DATA_WIDTH-1:0] p_rdata,
    input logic p_req_arvalid,

    output hacd_pkg::axi_rd_pld_t n_decomp_axireq,
    output logic n_decomp_rready,
    output logic n_decomp_req_arvalid,
    output logic [`HACD_AXI4_DATA_WIDTH-1:0] n_decomp_rdata,
    output hacd_pkg::tol_updpkt_t n_decomp_tol_updpkt,
    output logic decomp_mngr_done
);

logic [13:0] comp_size;
wire arready;
wire arvalid,rvalid,rlast;
assign arready = rd_rdypkt.arready; 
assign arvalid=p_req_arvalid;

logic [`HACD_AXI4_RESP_WIDTH-1:0] rresp;
logic [`HACD_AXI4_DATA_WIDTH-1:0] rdata;
assign rvalid = rd_resppkt.rvalid;
assign rlast = rd_resppkt.rlast;
assign rdata = rd_resppkt.rdata;
assign rresp =  rd_resppkt.rresp;

logic [`HACD_AXI4_DATA_WIDTH-1:0] n_rdata;
typedef logic [`FSM_WID_DCMP_MNGR-1:0] state_t;
`undef FSM_WID_DCMP_MNGR
state_t n_state,p_state;
localparam IDLE			     ='d0,
	   REQ_IWAY_PTR	     	     ='d1,
	   FETCH_IWAY_PTR	     ='d2,	
	   RESET_FIFO_PTRS	     ='d3,
	   WAIT_RESET		     ='d4,
	   BURST_READ_START	     ='d5,
	   BURST_READ		     ='d6,
	   DECOMP_WAIT		     ='d7, //This should wait for decompressed page (4KB) to be written to memory
	   //UPDATE_ZSMD		     ='d10,
	   DONE			     ='d8,
	   DECOMP_MNGR_ERROR	     ='d9,
	   BUS_ERROR		     ='d10;

logic [7:0] size_idx;

ListEntry p_listEntry,n_listEntry;
logic [5:0] n_burst_cnt,p_burst_cnt;
logic n_decomp_start;
ZsPg_Md_t ZsPg_Md;
iWayORcPagePkt_t n_iWayORcPagePkt;
integer i;
logic n_decomp_mngr_done;
logic n_decomp_rdm_reset;
always@* begin
//default
	n_state=p_state;	       //be in same state unless fsm decides to jump
	n_decomp_axireq.addr= p_axireq.addr;
	n_decomp_axireq.arlen = 8'd0; //by default, one beat
	n_decomp_req_arvalid = 1'b0; 	       //fsm decides when to send packet
        n_decomp_rready=1'b1;     
	n_decomp_rdata=p_rdata;
	n_decomp_tol_updpkt.tbl_update=1'b0;
	n_decomp_start=decomp_start; //1'b0;
	n_decomp_mngr_done=1'b0;
	n_iWayORcPagePkt=dc_iWayORcPagePkt;
	n_iWayORcPagePkt.comp_decomp=1'b0;
	//n_iWayORcPagePkt.update=1'b0;
	n_burst_cnt=p_burst_cnt;	
	n_decomp_rdm_reset=1'b0;

	case(p_state)
		IDLE: begin
			if(decomp_trigger && !decomp_mngr_done) begin
				n_state=REQ_IWAY_PTR;
			end
		end
		REQ_IWAY_PTR:begin
			if(arready && !arvalid) begin
			    n_decomp_axireq.addr = {decomp_cPage_byteStart [`HACD_AXI4_ADDR_WIDTH-1:12],12'b0};
			    n_decomp_req_arvalid = 1'b1;
			    n_state = FETCH_IWAY_PTR;
			end
		end
		FETCH_IWAY_PTR:begin
			if(rvalid && rlast) begin 
			      if(rresp =='d0) begin
			           n_decomp_rdata= rdata; 
				   if(n_decomp_rdata[47:0] == p_axireq.addr[47:0]) begin //If Iam  the iWay, pick the csize
				      n_iWayORcPagePkt=setCpageBusy_ZsPageiWay(n_decomp_rdata,decomp_cPage_byteStart);
				      //n_burst_cnt=(get_cpage_size(n_decomp_rdata[7+2*48:2*48]) >> 6) + 1;
				      n_burst_cnt=(n_iWayORcPagePkt.cpage_size >> 6) + 1;
			              n_state = RESET_FIFO_PTRS;
				   end
				   else begin
					if(arready && !arvalid) begin
					    n_decomp_axireq.addr = {16'b0,n_decomp_rdata[47:0]};
					    n_decomp_req_arvalid = 1'b1;
					    n_state = FETCH_IWAY_PTR;
					end
				   end
			      end
			      else n_state = BUS_ERROR;
			end
		end
		RESET_FIFO_PTRS:begin
			   n_decomp_rdm_reset = 1'b1; //Later connect this to WRITE FIFO as well. 
			   n_state=WAIT_RESET;
		end
		WAIT_RESET: begin
			   n_decomp_rdm_reset = 1'b0;
			   n_state=BURST_READ_START;
		end
		BURST_READ_START: begin
        		n_decomp_rready=1'b0;     
			if(arready && !arvalid && p_burst_cnt > 'd0 && rdfifo_empty) begin
			        n_decomp_axireq.addr = decomp_cPage_byteStart; 
				n_decomp_axireq.arlen = 8'd0; 
			        n_decomp_req_arvalid = 1'b1;
				n_burst_cnt = p_burst_cnt - 'd1;
				n_state=BURST_READ;
			end
		end
		BURST_READ: begin
        		n_decomp_rready=1'b0;     
			if(arready && !arvalid && (p_burst_cnt > 'd0) && !rdfifo_full) begin
			        n_decomp_axireq.addr = p_axireq.addr + 64'd64; //16beats per burst, each beat is 64 bytes part(cacheline) 
				n_decomp_axireq.arlen = 8'd0; 
			        n_decomp_req_arvalid = 1'b1;
				n_burst_cnt = p_burst_cnt-'d1;
			end 
			else if(p_burst_cnt=='d0) begin
				n_decomp_start=1'b1;  
				n_iWayORcPagePkt.cPage_byteStart=decomp_freeWay[47:0];
				n_iWayORcPagePkt.update=1'b1;
				n_state=DECOMP_WAIT;
			end
		end
		DECOMP_WAIT: begin
			        if (zspg_updated) begin //this makes sure, decomprssed page has been written 	
				   n_iWayORcPagePkt.update=1'b0;
			           n_state= DONE;
				end
				//if(decomp_done) begin
				//	n_state = DONE;//UPDATE_ZSMD;
				//end
		end
		//UPDATE_ZSMD: begin
		//		n_iWayORcPagePkt.update=1'b1;
		//end
		DONE: begin
					n_decomp_mngr_done=1'b1;
					n_state = IDLE; //we are done  
		end
		DECOMP_MNGR_ERROR: begin
			   n_state = DECOMP_MNGR_ERROR;
		end
		BUS_ERROR: begin
			   //assert trigger, connect it to spare LED.
			   //Stay here forever unless, user resets
			   n_state = BUS_ERROR;
		end
	endcase
end
//state register/output flops
always @(posedge clk_i or negedge rst_ni)
begin
	if(!rst_ni) begin
		p_state <= IDLE;
		p_listEntry <= 'd0;
		p_burst_cnt <= 'd0;
		decomp_start <=1'b0;
		dc_iWayORcPagePkt<='d0;
		decomp_mngr_done<=1'b0;
		decomp_rdm_reset<=1'b0;
	end
	else begin
 		p_state <= n_state;	
		p_listEntry <= n_listEntry;
		p_burst_cnt <= n_burst_cnt;
		decomp_start<=n_decomp_start;
		dc_iWayORcPagePkt<=n_iWayORcPagePkt;
		decomp_mngr_done<=n_decomp_mngr_done;
		decomp_rdm_reset<=n_decomp_rdm_reset;
	end
end

endmodule
