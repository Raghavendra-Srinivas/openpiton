//Description:
// Supports multiple modes , controlled by hawk control unit
//
`include "hacd_define.vh"
import hacd_pkg::*;
`define FSM_WID_PGRD 4
module hawk_pgrd_mngr (

  input clk_i,
  input rst_ni,

  input hacd_pkg::att_lkup_reqpkt_t lkup_reqpkt,

 //with PWM
  input pgwr_mngr_ready,

  input hacd_pkg::hawk_tol_ht_t tol_HT,

  //AXI packets
  input hacd_pkg::axi_rd_rdypkt_t rd_rdypkt,
  output hacd_pkg::axi_rd_reqpkt_t rd_reqpkt,
  input hacd_pkg::axi_rd_resppkt_t rd_resppkt,

  output hacd_pkg::trnsl_reqpkt_t trnsl_reqpkt,
  output hacd_pkg::tol_updpkt_t tol_updpkt,
  output pgrd_mngr_ready
);


  wire [clogb2(LST_ENTRY_MAX)-1:0] freeLstHead;	
  wire [clogb2(LST_ENTRY_MAX)-1:0] freeLstTail;
	
  assign freeLstHead=tol_HT.freeListHead;
  assign freeLstTail=tol_HT.freeListTail;

//fsm variables  
logic p_req_arvalid,n_req_arvalid,p_rready,n_rready;
logic [`HACD_AXI4_DATA_WIDTH-1:0] p_rdata,n_rdata;
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
	   ALLOCATE_PPA 	='d7,
	   TBL_UPDATE		='d8,
	   UNCOMPRESS		='d9,
	   BUS_ERROR		='d10;

//helper functions
function axi_rd_pld_t get_axi_rd_pkt;
	input [clogb2(LST_ENTRY_MAX)-1:0] freeLstHead;
	input state_t p_state;
	input [clogb2(ATT_ENTRY_MAX)-1:0] attEntryId;
	integer i;
        AttEntry att_entry;
	ListEntry lst_entry;

	if      (p_state == LOOKUP_ATT) begin
		   //(hppa-HPPA_BASE_ADDR) isn ATT entry ID
		   //It is hppa adderss minus hppa_base gives AttEntryID. divide by (>>3) as 8 entries can fit in one cache,
		   //we get incremnt of 1 for every 8 incrments of hppa.
		   //and we need to multiply that quantity by 64(<<6) (as cacheline
		   //size is 64bytes
		 get_axi_rd_pkt.addr = HAWK_ATT_START + ((attEntryId >> 3) << 6);//map hppa to att cache line address
        end
	else if (p_state == POP_FREE_LST ) begin
		 //generate address which does pop from free list referenced
		 //from free list head
		 get_axi_rd_pkt.addr = HAWK_LIST_START + (((freeLstHead-1) >> 2) << 6);
	end
	//handle other modes later
endfunction

//function  decode_AttEntry
function trnsl_reqpkt_t decode_AttEntry;
	input logic [47:0] hppa;
 	input logic [`HACD_AXI4_DATA_WIDTH-1:0] rdata;
	integer i;
        AttEntry att_entry[8];
	
	for(i=0;i<8;i++) begin
		att_entry[i]=rdata[64*i+:64];
	end
	//find which entry in cacheline and mask
	case(hppa[2:0])
	 3'b000: begin decode_AttEntry.ppa=att_entry[0].way[49:2];decode_AttEntry.sts=att_entry[0].sts;end
	 3'b001: begin decode_AttEntry.ppa=att_entry[1].way[49:2];decode_AttEntry.sts=att_entry[1].sts;end
	 3'b010: begin decode_AttEntry.ppa=att_entry[2].way[49:2];decode_AttEntry.sts=att_entry[2].sts;end
	 3'b011: begin decode_AttEntry.ppa=att_entry[3].way[49:2];decode_AttEntry.sts=att_entry[3].sts;end
	 3'b100: begin decode_AttEntry.ppa=att_entry[4].way[49:2];decode_AttEntry.sts=att_entry[4].sts;end
	 3'b101: begin decode_AttEntry.ppa=att_entry[5].way[49:2];decode_AttEntry.sts=att_entry[5].sts;end
	 3'b110: begin decode_AttEntry.ppa=att_entry[6].way[49:2];decode_AttEntry.sts=att_entry[6].sts;end
	 3'b111: begin decode_AttEntry.ppa=att_entry[7].way[49:2];decode_AttEntry.sts=att_entry[7].sts;end
	endcase	
endfunction 

function tol_updpkt_t get_Tolpkt;
	input [clogb2(LST_ENTRY_MAX)-1:0] freeLstHead;
	input [clogb2(ATT_ENTRY_MAX)-1:0] attEntryId;
 	input logic [`HACD_AXI4_DATA_WIDTH-1:0] rdata;
	input state_t p_state;
	ListEntry list_entry;

	if(p_state == ALLOCATE_PPA) begin 
		//allocate_ppa: we have picked entry from freelist and moving it to uncompressed list
		 get_Tolpkt.attEntryId=attEntryId;
		 get_Tolpkt.tolEntryId=freeLstHead;
		 get_Tolpkt.src_list=FREE;
		 get_Tolpkt.dst_list=UNCOMP;
		 //one block contains 4 lsit entries, we need to pcik the one
		 //pointed by freeLstHead
		 case(freeLstHead[1:0])
			2'b00:	list_entry = rdata[127:0];
			2'b01:	list_entry = rdata[255:128];
			2'b10:	list_entry = rdata[383:256];
			2'b11:	list_entry = rdata[511:384];
		 endcase
		 get_Tolpkt.lstEntry=list_entry;
	
	end
	//handle other table update later

endfunction

wire arready,rready;
wire arvalid,rvalid,rlast;
assign arready = rd_rdypkt.arready; 

logic [`HACD_AXI4_RESP_WIDTH-1:0] rresp;
logic [`HACD_AXI4_DATA_WIDTH-1:0] rdata;
assign rvalid = rd_resppkt.rvalid;
assign rlast = rd_resppkt.rlast;
assign rdata = rd_resppkt.rdata;
assign rresp =  rd_resppkt.rresp;

axi_rd_pld_t p_axireq,n_axireq;
trnsl_reqpkt_t n_trnsl_reqpkt,p_trnsl_reqpkt;
logic [clogb2(ATT_ENTRY_MAX)-1:0] n_attEntryId,p_attEntryId;
tol_updpkt_t n_tol_updpkt,p_tol_updpkt;

//logic to handle different modes
always@* begin
//default
	n_state=p_state;	       //be in same state unless fsm decides to jump
	n_axireq= p_axireq;
	n_req_arvalid = 1'b0; 	       //fsm decides when to send packet
        n_rready=1'b1;   //no reason why we block read, as we are sure to issue arvlaid only when we need  
	n_rdata=p_rdata;
	n_trnsl_reqpkt='d0;
	case(p_state)
		IDLE: begin
			//Put into target operating mode, along with
			//initial values on required variables as
			//needed
			if      (lkup_reqpkt.lookup && !p_trnsl_reqpkt.allow_access) begin 
				//For ATT lookup, we need to have attEntryId to
				n_attEntryId=lkup_reqpkt.hppa-HPPA_BASE_ADDR;
				n_state=LOOKUP_ATT;
			end
			//handle other modes below

		end
		LOOKUP_ATT:begin
			  if(arready && !arvalid) begin
				     n_axireq = get_axi_rd_pkt(freeLstHead,p_state,p_attEntryId); //, first arguemnt is not useful, for this state
				     n_req_arvalid = 1'b1;
				     n_state = WAIT_ATT_ENTRY;
			  end 
		end
		WAIT_ATT_ENTRY: begin //we can have multiple beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(rvalid && rlast) begin //rlast is expected as we have only one beat//added assertion for this
				if(rresp =='d0) begin
				     n_rdata=rdata; 
				     n_state = DECODE_ATT_ENTRY;
				end
				else n_state = BUS_ERROR;
			  end
		end
		DECODE_ATT_ENTRY:begin
			   n_trnsl_reqpkt=decode_AttEntry(lkup_reqpkt.hppa,p_rdata);
			   if     (n_trnsl_reqpkt.sts==STS_UNCOMP || n_trnsl_reqpkt.sts==STS_INCOMP) begin
					n_state = IDLE; // att_hit: nothing to do 
					n_trnsl_reqpkt.allow_access=1'b1;
			   end
			   else if(n_trnsl_reqpkt.sts==STS_COMP) begin
					n_state = UNCOMPRESS; //not handling for now
			   end
			   else begin //DALLOC: if it powerup, everything is deallcoated, and if deallocated proactively, it means , freelist has been updated with that ppa.
			  	n_state = POP_FREE_LST; 
			   end
	        end
		POP_FREE_LST: begin 
			  if(freeLstHead!=freeLstTail) begin 
			             n_axireq=get_axi_rd_pkt(freeLstHead,p_state,freeLstHead);		
				     n_req_arvalid = 1'b1;
				     n_state = WAIT_LST_ENTRY;
			  end
			  else begin
				    //Add here to look for victim of
				    //uncompressed list , moving to idle for
				    //now
				    n_state = IDLE; //not handling for now
			  end
		end
		WAIT_LST_ENTRY: begin //we can have multiple beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(rvalid && rlast) begin //rlast is expected as we have only one beat//added assertion for this
				     n_rdata=rdata; 
				     n_state = ALLOCATE_PPA;
			  end
		end

		ALLOCATE_PPA: begin //this stae, we get ppa from freelist and also prepare att & tol updte packet taht is sent pgwr_manager
			  if(rvalid && rlast) begin //rlast is expected as we have only one beat//added assertion for this 
				     n_tol_updpkt=get_Tolpkt(freeLstHead,p_attEntryId,p_rdata,p_state); //freelisthead tells, which tol entry we need
			   	     if(pgwr_mngr_ready) begin
				     	n_tol_updpkt.tbl_update=1'b1;
				     	n_state = IDLE;
				     end
				     else n_state = TBL_UPDATE;	
			   end
		end
		TBL_UPDATE:begin
			   //we can deliver packet to PWM only if it's ready
			   if(pgwr_mngr_ready) begin
				     n_tol_updpkt.tbl_update=1'b1;
				     n_state = IDLE;
			   end
		end
		UNCOMPRESS: begin
			   n_state = UNCOMPRESS; //Trigger Burst mode engine //not handling this for phase1
		end
		//TBL_UPDATE_DONE:
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
		
		p_axireq.addr <= HAWK_ATT_START; 
		p_req_arvalid <= 1'b0;
		p_rready <= 1'b0;

		p_trnsl_reqpkt<='d0;
		p_tol_updpkt <='d0;
	end
	else begin
 		p_state <= n_state;	

		//Axi signals
		p_axireq.addr <= n_axireq.addr;
		p_req_arvalid <= n_req_arvalid ;
		p_rready <= n_rready;

		//Tranalstion Request : It can be att hit or tbl update
		p_trnsl_reqpkt<=n_trnsl_reqpkt;
		p_tol_updpkt <= n_tol_updpkt;
	end
end

//Output combo signals
assign rd_reqpkt.addr = p_axireq.addr;
assign rd_reqpkt.arvalid = p_req_arvalid;

assign rd_reqpkt.rready =p_rready;

assign trnsl_reqpkt=p_trnsl_reqpkt;
assign tol_updpkt=p_tol_updpkt;

wire bus_error;
assign bus_error = p_state == BUS_ERROR;

assign pgrd_mngr_ready = p_state == IDLE;

`ifdef HAWK_SIMS
initial begin
 	if(bus_error) begin
		$display("Bus error observed on AXI read response at %0t",$time);
	end
end
`endif 



//Add State machine to handle burst mode of to read compressed page and fill AXI RD
//MASTER FIFO directly 

endmodule
