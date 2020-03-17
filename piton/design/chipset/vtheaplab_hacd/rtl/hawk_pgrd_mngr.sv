//Description:
// Supports multiple modes , controlled by hawk control unit
//
`include "hacd_define.vh"
import hacd_pkg::*;
`define FSM_WID_PGRD 4
module hawk_pgrd_mngr (

  input clk_i,
  input rst_ni,

  input lookup_att,
  input [47:0] hppa_i,//this physical page address

  input [clogb2(LST_ENTRY_MAX)-1:0] freeLstHead,	
  input [clogb2(LST_ENTRY_MAX)-1:0] freeLstTail,	
  //AXI packets
  input hacd_pkg::axi_rd_rdypkt_t rd_rdypkt,
  output hacd_pkg::axi_rd_reqpkt_t rd_reqpkt,

  output lookup_att_done
);

//fsm variables  
logic p_req_arvalid,n_req_arvalid,p_rready,n_rready;
typedef logic [`FSM_WID_PGRD-1:0] state_t;
state_t n_state;
state_t p_state;
//states
localparam IDLE			='d0,
	   LOOKUP_ATT	  	='d1,
	   WAIT_ATT_ENTRY 	='d2,
	   CHECK_ATT_ENTRY 	='d3,
	   DECODE_ATT_ENTRY	='d4,
	   POP_FREE_LST 	='d5,
	   WAIT_LST_ENTRY	='d6,
	   ALLOCATE_PPA 	='d7;


//helper functions
function axi_rd_pld_t get_axi_rd_pkt;
	input [clogb2(LST_ENTRY_MAX)-1:0] freeLstHead;
	input state_t p_state;
	input [47:0] hppa;
	integer i;
        AttEntry att_entry;
	ListEntry lst_entry;

	if      (p_state == LOOKUP_ATT) begin
		   //It is hppa adderss minus hppa_base gives offset from
		   //zero. divide by (>>3) as 8 entries can fit in one cache,
		   //we get incremnt of 1 for every 8 incrments of hppa.
		   //and we need to multiply that quantity by 64(<<6) (as cacheline
		   //size is 64bytes
		 get_axi_rd_pkt.addr = HAWK_ATT_START + (((hppa-HPPA_BASE_ADDR) >> 3) << 6);//map hppa to att cache line address
        end
	else if (p_state == POP_FREE_LST ) begin
		 //generate address which does pop from free list referenced
		 //from free list head
		 get_axi_rd_pkt.addr = HAWK_LIST_START + (((freeLstHead-1) >> 2) << 6);
	end
	//handle other modes later
endfunction

//function  check_AttEntry

wire arready,rready;
wire arvalid,rvalid;
assign arready = rd_rdypkt.arready; 

assign rvalid = rd_resppkt.rvalid;
assign rdata = rd_resppkt.rdata;

axi_rd_pld_t p_axireq,n_axireq;
tblUpdt_reqpkt_t n_tbl_updt_reqpkt,p_tbl_updt_reqpkt;
//logic to handle different modes
always_comb begin
//default
	n_state=p_state;	       //be in same state unless fsm decides to jump
	n_axireq= p_axireq;
	n_req_arvalid = 1'b0; 	       //fsm decides when to send packet
        n_rready=1'b1;   //no reason why we block read, as we are sure to issue arvlaid only when we need  
	n_rdata=p_rdata;
	n_tbl_updt_reqpkt='d0;
	case(p_state)
		IDLE: begin
			//Put into target operating mode, along with
			//initial values on required variables as
			//needed
			if      (lookup_att) begin //wait in same state till table initialiation is done
				n_state=LOOKUP_ATT;
			end
			//handle other modes below

		end
		LOOKUP_ATT:begin
			  if(arready && !arvalid) begin
				  //handle ATT initialization 
				     n_axireq = get_axi_rd_pkt(p_state,hppa_i); //prepare next packet
				     n_req_arvalid = 1'b1;
				     n_state = WAIT_ATT_ENTRY;
			  end 
		end
		WAIT_ATT_ENTRY: begin //we can have multiple beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(rvalid && rlast) begin //rlast is expected as we have only one beat//added assertion for this
				     n_rdata=rdata; 
				     n_state = CHECK_ATT_ENTRY;
			  end
		end
		DECODE_ATT_ENTRY:begin
			  n_transltn_reqpkt=decode_AttEntry(hppa_i,p_rdata);
			  n_state = CHECK_ATT_ENTRY; 
	        end
		CHECK_ATT_ENTRY: begin  
			  if(p_transltn_reqpkt.att_hit) begin
				n_transltn_reqpkt.allow_cpu_access = 1'b1;
				//this should be assured by cu(control unit), we can let pgrd mngr handles this, 
				//but once we move to set-associative based internal cache, it makes cu handle cache access and halde this 
				if(cpu_active)
				   n_state = IDLE;	
			  end
			  else begin
				//lookup freelist
				n_state = POP_FREE_LIST;
			  end
		end	
		POP_FREE_LST: begin 
			  if(freeLstHead!=freeLstTail) begin 
			             n_axireq=get_axi_rd_pkt(p_state,freeLstHead);		
				     n_req_arvalid = 1'b1;
				     n_state = WAIT_LST_ENTRY;
			  end
			  else begin
				    //Add here to look for victim of
				    //uncompressed list , moving to idle for
				    //now
				    n_state = IDLE;
			  end
		WAIT_LST_ENTRY: begin //we can have multiple beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(rvalid && rlast) begin //rlast is expected as we have only one beat//added assertion for this
				     n_rdata=rdata; 
				     n_state = ALLOCATE_PPA;
			  end
		end
		ALLOCATE_PPA: begin
			  if(rvalid && rlast) begin //rlast is expected as we have only one beat//added assertion for this 
				     n_tbl_updt_reqpkt.ppa=get_ppa(freeLstHead,p_rdata);;
				     n_tbl_updt_reqpkt.update=1'b1;
				     n_state = IDLE;
			  end
		end
		TBL_UPDATE_DONE:

		default: n_state=IDLE;
	endcase
end


//state register/output flops
always @(posedge clk_i or negedge rst_ni)
begin
	if(!rst_ni) begin
		p_state <= IDLE;
		p_etry_cnt <= 'd0;
		
		p_axireq.addr <= HAWK_ATT_START; 
		p_axireq.data <= 'd0;
		p_axireq.strb <= 'd0;
		p_req_arvalid <= 1'b0;
		p_req_wvalid <= 1'b0;
		
		p_rready <= 1'b0;
	end
	else begin
 		p_state <= n_state;	
		p_etry_cnt <= n_etry_cnt;

		//Axi signals
		p_axireq.addr <= n_axireq.addr;
		p_axireq.data <= n_axireq.data;
		p_req_arvalid <= n_req_arvalid ;

		p_rready <= n_rready;
		
		//Table Update Request
		p_tbl_updt_reqpkt<=n_tbl_updt_reqpkt;
		//Tranalstion Request 
		p_transltn_reqpkt<=n_transltn_reqpkt;
	end
end

//done statuses
/*
//later useful to map it to status register if needed
always @(posedge clk_i or negedge rst_ni)
	if(!rst_ni) begin
	   allow_cpu_access<=1'b0;
  	end
	else begin 
	if(lookup_att)
	   p_transltn_reqpkt.allow_cpu_access<=1'b0;
	else if(n_tbl_updt_reqpkt.allow_cpu_access)
	   p_transltn_reqpkt<=n_transltn_reqpkt;
	end
*/
//Output combo signals
assign rd_reqpkt.addr = p_axireq.addr;
assign rd_reqpkt.data = p_axireq.data;
assign rd_reqpkt.arvalid = p_req_arvalid;

assign rd_rdypkt.rready =p_rready;
endmodule
