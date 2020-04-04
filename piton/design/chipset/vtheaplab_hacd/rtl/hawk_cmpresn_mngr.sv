`include "hacd_define.vh"
import hacd_pkg::*;
import hawk_rd_pkg::*;
`define FSM_WID_CMP_MNGR 4
module hawk_cmpresn_mngr (
    input clk_i,
    input rst_ni,

    input cmpresn_trigger,
    input hacd_pkg::hawk_tol_ht_t tol_HT,
    input logic [clogb2(ATT_ENTRY_MAX)-1:0] p_attEntryId,
    input pgwr_mngr_ready,

    //handshake with PWM
    input zspg_updated,	

    //from compressor
    input logic [13:0] comp_size,
    output logic comp_start,
    input comp_done,
    output hacd_pkg::iWayORcPagePkt_t iWayORcPagePkt,
  
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

    output hacd_pkg::axi_rd_pld_t n_comp_axireq,
    output logic n_comp_rready,
    output logic n_comp_req_arvalid,
    output logic [`HACD_AXI4_DATA_WIDTH-1:0] n_comp_rdata,
    output hacd_pkg::tol_updpkt_t n_comp_tol_updpkt,
    output logic cmpresn_done,
    output logic [`HACD_AXI4_ADDR_WIDTH-1:12] cmpresn_freeWay	
);

logic [`HACD_AXI4_ADDR_WIDTH-1:12] n_cmpresn_freeWay;
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
typedef logic [`FSM_WID_CMP_MNGR-1:0] state_t;
`undef FSM_WID_CMP_MNGR
state_t n_state,p_state;
localparam IDLE			     ='d0,
	   PEEK_UCMP_HEAD	     ='d1,
	   WAIT_UCMP_TAIL	     ='d2,
	   DECODE_LST_ENTRY	     ='d3,
	   BURST_READ		     ='d4,
	   COMP_WAIT		     ='d5,
	   FETCH_ZSPAGE		     ='d6,
	   WAIT_ZSPAGE		     ='d7,	
	   PREP_ZSPAGE_MD	     ='d8,
	   UPDATE_ATT_POP_UCMP_TAIL  ='d9,
	   MIGRATE_TO_ZSPAGE	     ='d10,
	   DO_FINAL_TOL_UPDATE	     ='d11,
	   DONE			     ='d11,	
	   COMP_MNGR_ERROR	     ='d12,
	   BUS_ERROR		     ='d13;





logic [7:0] size_idx;

logic [47:0] UC_ifLst_iWay[IFLST_COUNT],n_UC_ifLst_iWay[IFLST_COUNT];
logic UC_ifLst_iWay_valid[IFLST_COUNT],n_UC_ifLst_iWay_valid[IFLST_COUNT];
logic [13:0] n_comp_size,p_comp_size;
ListEntry p_listEntry,n_listEntry;
logic [1:0] n_burst_cnt,p_burst_cnt;
logic n_comp_start;
ZsPg_Md_t ZsPg_Md;
iWayORcPagePkt_t n_iWayORcPagePkt;
integer i;
logic n_cmpresn_done;

always@* begin
//default
	n_state=p_state;	       //be in same state unless fsm decides to jump
	n_comp_axireq.addr= p_axireq.addr;
	n_comp_axireq.awlen = 'd0; //by default, one beat
	n_comp_req_arvalid = 1'b0; 	       //fsm decides when to send packet
        n_comp_rready=1'b1;   //no reason why we block read, as we are sure to issue arvlaid only when we need  
	n_comp_rdata=p_rdata;
	n_comp_tol_updpkt.tbl_update=1'b0;
	n_comp_start=1'b0;
	n_cmpresn_done=1'b0;
	n_iWayORcPagePkt=iWayORcPagePkt;
	n_iWayORcPagePkt.update=1'b0;

	case(p_state)
		IDLE: begin
			if(cmpresn_trigger && !cmpresn_done) begin
				n_state=PEEK_UCMP_HEAD;
			end
		end
		PEEK_UCMP_HEAD: begin
			if(arready && !arvalid) begin
			           n_comp_axireq = get_axi_rd_pkt(tol_HT.uncompListHead,p_attEntryId,AXI_RD_TOL); 
			           n_comp_req_arvalid = 1'b1;
			           n_state = WAIT_UCMP_TAIL;
			end 
		end
		WAIT_UCMP_TAIL: begin //we can have multiple beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(rvalid && rlast) begin //rlast is expected as we have only one beat//added assertion for this
				if(rresp =='d0) begin
				     n_comp_rdata= rdata;  
				     n_state = DECODE_LST_ENTRY;
				end
				else n_state = BUS_ERROR;
			  end
		end
		DECODE_LST_ENTRY: begin
			   n_listEntry=decode_LstEntry(tol_HT.uncompListHead,p_rdata);
			   //n_trnsl_reqpkt
			   n_state=BURST_READ;
			   n_burst_cnt='d0;	
			   	
		end
		BURST_READ:begin
			   //n_state	
			if(arready && !arvalid && p_burst_cnt=='d0 && rdfifo_empty) begin
			           n_comp_axireq.addr = (p_listEntry.way<<12);
				   n_comp_axireq.awlen = 'd4; //4 corresponds for 16 beats
			           n_comp_req_arvalid = 1'b1;
				   n_burst_cnt = 'd1;
			end
			else if(arready && !arvalid && (p_burst_cnt !=0) && !rdfifo_full && p_burst_cnt<4) begin
			           n_comp_axireq.addr = p_axireq.addr + 64'h40; 
				   n_comp_axireq.awlen = 'd4; //4 corresponds for 16 beats
			           n_comp_req_arvalid = 1'b1;
				   n_burst_cnt = p_burst_cnt+'d1;
			end 
			if(rdfifo_full) begin
				n_comp_start=1'b1;
				n_state=COMP_WAIT;
			end
		
		end
		COMP_WAIT:begin
			if(comp_done) begin
				//lookup IF list for corresponding size
				size_idx=get_idx(comp_size);
				if (UC_ifLst_iWay_valid[size_idx]) begin
					//get underconstruction iWay from
					//memory
			    		n_comp_axireq = UC_ifLst_iWay[size_idx]; 
					n_state=FETCH_ZSPAGE; 
				end else if(tol_HT.IfLstHead[size_idx]!=NULL) begin
					n_state=MIGRATE_TO_ZSPAGE; 
				end else begin
					//n_IfLst_Head[size_idx]=tol_HT.uncompListHead; this shudl happen during uncompression
					n_state=PREP_ZSPAGE_MD;
					//record this IWay in Under Construction table
					n_UC_ifLst_iWay[size_idx]=p_listEntry.way; 
					n_UC_ifLst_iWay_valid[size_idx]=1'b1;
				end
			end
		end
		FETCH_ZSPAGE:begin
			if(arready && !arvalid) begin
			    //n_comp_axireq = UC_ifLst_iWay[size_idx]; //moved to previous state
			    n_comp_req_arvalid = 1'b1;
			    n_state = WAIT_ZSPAGE;
			end
		end
		WAIT_ZSPAGE:begin
			if(rvalid && rlast) begin 
			      if(rresp =='d0) begin
			           //n_comp_rdata= rdata; 
				   n_iWayORcPagePkt=decode_ZsPageiWay(rdata);
			           n_state = MIGRATE_TO_ZSPAGE ;
			      end
			      else n_state = BUS_ERROR;
			end
		end
		PREP_ZSPAGE_MD:begin
			   	if(pgwr_mngr_ready) begin
					//ZSPage Identiy Metadata
					//defaults
					ZsPg_Md='d0;

					ZsPg_Md.size=comp_size;
					ZsPg_Md.way0=p_listEntry.way; //myself is way to store compressed page
					ZsPg_Md.way_vld[0]=1'b1;	
					ZsPg_Md.page0=p_listEntry.way+62; //myself is the page plus offset of metadata &  2 pointers
					ZsPg_Md.pg_vld[0]=1'b1;	
					//send this packet and way_addr pg write to write compressed page, 
					//send tol_update packet to PWM to update uncompressTail 
					//and push entry to compressed list
			        	//n_iWayORcPagePkt.iWayORcPage=IWAY;
					n_iWayORcPagePkt.cPage_byteStart=p_listEntry.way+ZS_MD_SIZE;
					n_iWayORcPagePkt.cpage_size=comp_size;
					//payload
					n_iWayORcPagePkt.iWay_ptr=p_listEntry.way;
					n_iWayORcPagePkt.nxtWay_ptr='d0; //this is valid once we add new ways
					n_iWayORcPagePkt.zsPgMd=ZsPg_Md;
					//we can send update only if comp_size plus
					//payload of zspg can fit in 4KB that is
					//comp_size+62 bytes
					if((comp_size+62) < 4096) begin
						n_iWayORcPagePkt.update=1'b1;
					
						n_comp_tol_updpkt.dst_list=IFL_SIZE1; //for ZS identiy way, we need to push on Identity Way
			        		n_state=UPDATE_ATT_POP_UCMP_TAIL;
					end
					else begin
			        		n_state=COMP_MNGR_ERROR;
					end
				end
		end
		UPDATE_ATT_POP_UCMP_TAIL:begin //wait till Zspage is written
				if(zspg_updated && pgwr_mngr_ready) begin //update ATT and TOL then 
					n_comp_tol_updpkt.attEntryId=tol_HT.uncompListHead;
					n_comp_tol_updpkt.tolEntryId=tol_HT.uncompListHead;
				  	n_comp_tol_updpkt.lstEntry=p_listEntry;
					n_comp_tol_updpkt.lstEntry.way=iWayORcPagePkt.cPage_byteStart;//now ATT way is byte address of compressed page
					n_comp_tol_updpkt.src_list=UNCOMP;
					n_comp_tol_updpkt.ifl_idx=get_idx(comp_size);
					//n_comp_tol_updpkt.dst_list= ; This
					//will be set by calling states
					n_comp_tol_updpkt.tbl_update=1'b1;
					//We have not created free way yet, pop uncompressed and keep compressing, till we find complete 4KB free way
					n_state= PEEK_UCMP_HEAD;
				end
		end
		MIGRATE_TO_ZSPAGE:begin 
			   	if(pgwr_mngr_ready) begin
				  	//Decide where we can migrate this
				  	//compressed page : It can have 3 cases. 
				  	//(1) new cpage can fit in within Iway/Child way : Check 4KB boundary cross
				  	//(2) can partially fit
				  	//(3) there is no single byte extra space in iWay
				  	// For (2) and (3) we, need to make present
				  	// list_entry way as nxtWay_ptr in Iway
				  	// 
			          	if((iWayORcPagePkt.cPage_byteStart+comp_size)< ({iWayORcPagePkt.cPage_byteStart[47:12],12'd0}+4096) ) begin
				  	      n_iWayORcPagePkt.update=1'b1;
				  	      n_state = DO_FINAL_TOL_UPDATE;
				  	end
				  	else begin
				  	      n_iWayORcPagePkt.nxtWay_ptr=p_listEntry.way;
				  	      n_iWayORcPagePkt.update=1'b1;

				  	      //Update ATT and TOL
					      n_comp_tol_updpkt.dst_list=NULLIFY; //for ZS identiy way, we need to push on Identity Way
			        	      n_state=UPDATE_ATT_POP_UCMP_TAIL;
				  	end
				end
		end
		DO_FINAL_TOL_UPDATE:begin
			   	if(zspg_updated && pgwr_mngr_ready) begin//zspg_updated is level signal till next reqeust
					n_comp_tol_updpkt.attEntryId=tol_HT.uncompListHead;
					n_comp_tol_updpkt.tolEntryId=tol_HT.uncompListHead;
				  	n_comp_tol_updpkt.lstEntry=p_listEntry;
					n_comp_tol_updpkt.lstEntry.way=p_listEntry.way;//now ATT way if freeway
					n_comp_tol_updpkt.src_list=UNCOMP;
					n_comp_tol_updpkt.dst_list=UNCOMP; //I got freeway, list entry remain in same staet
					n_comp_tol_updpkt.ifl_idx=get_idx(comp_size);
					n_comp_tol_updpkt.tbl_update=1'b1;		
					n_state = DONE; 
				end
		end
		DONE: begin
				if(zspg_updated) begin   
					n_cmpresn_done=1'b1;
					n_cmpresn_freeWay=p_listEntry.way;
					n_state = IDLE; //we are done  
				end
		end
		COMP_MNGR_ERROR: begin
			   n_state = COMP_MNGR_ERROR;
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
		p_burst_cnt <= 1'b0;
		comp_start <=1'b0;
		iWayORcPagePkt<='d0;
		cmpresn_done<=1'b0;
	        cmpresn_freeWay<='d0;
	end
	else begin
 		p_state <= n_state;	
		p_listEntry <= n_listEntry;
		p_burst_cnt <= n_burst_cnt;
		comp_start<=n_comp_start;
		iWayORcPagePkt<=n_iWayORcPagePkt;
		cmpresn_done<=n_cmpresn_done;
	        cmpresn_freeWay<=n_cmpresn_freeWay;
	end
end



//logic [clogb2(LST_ENTRY_MAX)-1:0] IfLst_Tail[1];


//Under Construction Tables
genvar fl;
generate
for(fl=0;fl<IFLST_COUNT;fl=fl+1) begin : ifLST_IWAY
	always @(posedge clk_i or negedge rst_ni) begin
		if(!rst_ni) begin
			UC_ifLst_iWay[fl]<='d0; //0 corresponds for NULL
		end else begin
			UC_ifLst_iWay[fl]<=n_UC_ifLst_iWay[fl];
			UC_ifLst_iWay_valid[fl]<=n_UC_ifLst_iWay_valid[fl];
		end
	end
end : ifLST_IWAY
endgenerate

endmodule
