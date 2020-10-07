`include "hacd_define.vh"
import hacd_pkg::*;
import hawk_rd_pkg::*;
`define FSM_WID_CMP_MNGR 5
module hawk_cmpresn_mngr (
    input clk_i,
    input rst_ni,

    input cmpresn_trigger,
    input hacd_pkg::hawk_tol_ht_t tol_HT,
    input logic [clogb2(ATT_ENTRY_MAX)-1:0] p_attEntryId,
    input pgwr_mngr_ready,
    input tbl_update_done,

    input zeroBlkWr,
    //handshake with PWM
    input zspg_updated,	
    output logic comp_rdm_reset,

    //from compressor
    input logic [13:0] comp_size,
    output logic comp_start,
    input wire comp_done,
    input wire incompressible,

    output hacd_pkg::iWayORcPagePkt_t c_iWayORcPagePkt,
  
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
    output logic [`HACD_AXI4_ADDR_WIDTH-1:12] cmpresn_freeWay,

    output hacd_pkg::debug_pgrd_cmp_mngr debug_cmp_mngr	
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
logic n_rdfifo_wrptr_rst,n_rdfifo_rdptr_rst;

logic [`HACD_AXI4_DATA_WIDTH-1:0] n_rdata;
typedef logic [`FSM_WID_CMP_MNGR-1:0] state_t;
`undef FSM_WID_CMP_MNGR
state_t n_state,p_state;
localparam IDLE			     ='d0,
	   PEEK_UCMP_HEAD	     ='d1,
	   WAIT_UCMP_HEAD	     ='d2,
	   DECODE_LST_ENTRY	     ='d3,
	   RESET_FIFO_PTRS	     ='d4,
	   WAIT_RESET		     ='d5,
	   BURST_READ		     ='d6,
	   COMP_WAIT		     ='d7,
	   POP_UCMP_PUSH_INCOMP	     ='d8,
	   COMP_DONE		     ='d9,
	   FETCH_ZSPAGE		     ='d10,
	   WAIT_ZSPAGE		     ='d11,	
	   DECODE_ZSPGE_IWAY	     ='d12,
	   PREP_ZSPAGE_MD	     ='d13,
	   UPDATE_ATT_POP_UCMP_HEAD  ='d14,
	   MIGRATE_TO_ZSPAGE	     ='d15,
	   POP_IFL		     ='d16,	
	   FREEWAY_OR_CONTINUE	     ='d17,
	   TOL_UPDATE_FREEWAY_ENTRY  ='d18,
	   ATT_UPDATE_FREEWAY_ENTRY  ='d19,
	   DONE			     ='d20,	
	   COMP_MNGR_ERROR	     ='d21,
	   BUS_ERROR		     ='d22,
	   PLACE_HOLDER		     ='d23;

logic [7:0] size_idx;

logic [31:0] zsPgCnt,n_zsPgCnt;

logic [47:0] UC_ifLst_iWay[IFLST_COUNT],n_UC_ifLst_iWay[IFLST_COUNT];
logic UC_ifLst_iWay_valid[IFLST_COUNT],n_UC_ifLst_iWay_valid[IFLST_COUNT];
logic [13:0] n_comp_size,p_comp_size;
ListEntry p_listEntry,n_listEntry;
logic [5:0] n_burst_cnt,p_burst_cnt;
logic n_comp_start;
ZsPg_Md_t ZsPg_Md;
iWayORcPagePkt_t n_iWayORcPagePkt;
integer i;
logic n_cmpresn_done;
logic n_comp_rdm_reset;
always@* begin
//default
	n_state=p_state;	       //be in same state unless fsm decides to jump
	n_comp_axireq.addr= p_axireq.addr;
	n_comp_axireq.arlen = 8'd0; //by default, one beat
	n_comp_req_arvalid = 1'b0; 	       //fsm decides when to send packet
        n_comp_rready=1'b1;     
	n_comp_rdata=p_rdata;
	n_comp_tol_updpkt='d0; //.tbl_update=1'b0;
	n_comp_tol_updpkt.TOL_UPDATE_ONLY='d0;
	n_comp_start=comp_start; //1'b0;
	n_cmpresn_done=1'b0;
	n_iWayORcPagePkt=c_iWayORcPagePkt;
	n_iWayORcPagePkt.comp_decomp=1'b1;
	//n_iWayORcPagePkt.update=1'b0;
	n_burst_cnt=p_burst_cnt;	
	n_rdfifo_rdptr_rst=1'b0;
	n_rdfifo_wrptr_rst=1'b0;
	n_UC_ifLst_iWay=UC_ifLst_iWay;
	n_UC_ifLst_iWay_valid=UC_ifLst_iWay_valid;
	n_comp_rdm_reset=1'b0;
	//lookup IF list for corresponding size
	size_idx=get_idx(comp_size);
	n_zsPgCnt=zsPgCnt;
	
	
	n_cmpresn_freeWay=cmpresn_freeWay;

	case(p_state)
		IDLE: begin
			if(cmpresn_trigger && !cmpresn_done) begin
				n_state=PEEK_UCMP_HEAD;
			end
		end
		PEEK_UCMP_HEAD: begin //TODO: UCOMP List Null case is not handled here
			if(arready && !arvalid) begin
			           n_comp_axireq = get_axi_rd_pkt(tol_HT.uncompListHead,p_attEntryId,AXI_RD_TOL); 
			           n_comp_req_arvalid = 1'b1;
			           n_state = WAIT_UCMP_HEAD;
			end 
		end
		WAIT_UCMP_HEAD: begin //we can have multiple beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
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
			   n_state=RESET_FIFO_PTRS;
			   n_burst_cnt='d0;	
			   	
		end
		RESET_FIFO_PTRS:begin
			   //n_rdfifo_rdptr_rst=1'b1;
			   //n_rdfifo_wrptr_rst=1'b1;
			   n_comp_rdm_reset = 1'b1;
			   n_state=WAIT_RESET;
		end
		WAIT_RESET: begin
			   n_comp_rdm_reset = 1'b0;
			   n_state=BURST_READ;
		end
		BURST_READ:begin
        		n_comp_rready=1'b0;     
			   //n_state	
			if(arready && !arvalid && p_burst_cnt=='d0 && rdfifo_empty) begin
			           n_comp_axireq.addr = (p_listEntry.way<<12);
				   n_comp_axireq.arlen = 8'd0; //8'd15; //15 corresponds for 16 beats //fix memory model later to support burst
			           n_comp_req_arvalid = 1'b1;
				   n_burst_cnt = 'd1;
			end
			//else if(arready && !arvalid && (p_burst_cnt !=0) && !rdfifo_full && p_burst_cnt<4) begin
			else if(arready && !arvalid && (p_burst_cnt !=0) && !rdfifo_full && p_burst_cnt<64) begin
			           //n_comp_axireq.addr = p_axireq.addr + (p_burst_cnt << 4)<<6; //16beats per burst, each beat is 64 bytes part(cacheline) 
			           n_comp_axireq.addr = p_axireq.addr + 64'd64; //16beats per burst, each beat is 64 bytes part(cacheline) 
				   n_comp_axireq.arlen = 8'd0; //8'd15; //15 corresponds for 16 beats
			           n_comp_req_arvalid = 1'b1;
				   n_burst_cnt = p_burst_cnt+'d1;
			end 
			if(rdfifo_full) begin
				n_comp_start=1'b1;
				n_state=COMP_WAIT;
			end
		
		end
		COMP_WAIT:begin
			if (incompressible) begin
			   n_comp_rdm_reset = 1'b1; //chk
			   n_state=POP_UCMP_PUSH_INCOMP;
			   n_comp_start=1'b0;
		  	end
			else if(comp_done) begin
			   n_comp_rdm_reset = 1'b1; //chk
			   n_state=COMP_DONE;
			   n_comp_start=1'b0;
			end
		end
		POP_UCMP_PUSH_INCOMP: begin //coding in progress for this state
				if( pgwr_mngr_ready) begin //update ATT and TOL then 
					n_comp_tol_updpkt.attEntryId=p_listEntry.attEntryId;//tol_HT.uncompListHead;
					n_comp_tol_updpkt.tolEntryId=tol_HT.uncompListHead;
				  	n_comp_tol_updpkt.lstEntry=p_listEntry;
					n_comp_tol_updpkt.lstEntry.way=p_listEntry.way;
				  	n_comp_tol_updpkt.lstEntry.attEntryId=p_listEntry.attEntryId;
					n_comp_tol_updpkt.src_list=UNCOMP;
					n_comp_tol_updpkt.dst_list= INCOMP;
					n_comp_tol_updpkt.tbl_update=1'b1;
			
				`ifdef HAWK_SIMS
					$display("attEntryId=%d,tolEntryId=%d, list entry attID=%d",p_listEntry.attEntryId,tol_HT.uncompListHead,p_listEntry.attEntryId);
				`endif
				end
			        if(tbl_update_done) begin
						n_state= PEEK_UCMP_HEAD;
				`ifdef HAWK_SIMS
					$display("After table update uncomp list head =%d",tol_HT.uncompListHead);
				`endif
				end
		end
		COMP_DONE:begin
        		   //n_comp_rready=1'b0;     
			   //n_comp_rdm_reset = 1'b0;
				//n_comp_start=1'b0;
				if (UC_ifLst_iWay_valid[size_idx]) begin
					//get underconstruction iWay from
					//memory
			    		n_comp_axireq.addr = UC_ifLst_iWay[size_idx]; 
					n_state=FETCH_ZSPAGE; 
				end else if(tol_HT.IfLstHead[size_idx]!=NULL) begin
					n_state= IDLE;//Not handling for now :->Here, first we need fetch head of Ilist to get ptr to Zspage, then fetch Zspage. MIGRATE_TO_ZSPAGE; 
				end else begin
					n_state=PREP_ZSPAGE_MD;
					//record this IWay in Under Construction table
					n_UC_ifLst_iWay[size_idx]=(p_listEntry.way<<12); 
					n_UC_ifLst_iWay_valid[size_idx]=1'b1;
				end
			end
		FETCH_ZSPAGE:begin
			if(arready && !arvalid) begin
			    //n_comp_axireq.addr = UC_ifLst_iWay[size_idx]; 
			    n_comp_req_arvalid = 1'b1;
			    n_state = WAIT_ZSPAGE;
			end
		end
		WAIT_ZSPAGE:begin
			if(rvalid && rlast) begin 
			      if(rresp =='d0) begin
			           n_comp_rdata= rdata; 
			           n_state =DECODE_ZSPGE_IWAY  ;
			      end
			      else n_state = BUS_ERROR;
			end
		end
		DECODE_ZSPGE_IWAY: begin
			   n_iWayORcPagePkt=getFreeCpage_ZsPageiWay(p_rdata,p_listEntry.attEntryId);
			   n_state=MIGRATE_TO_ZSPAGE;
		end
		PREP_ZSPAGE_MD:begin
			   	if(pgwr_mngr_ready) begin
					//ZSPage Identiy Metadata
					//defaults
					ZsPg_Md='d0;

					ZsPg_Md.size=get_idx(comp_size);
					ZsPg_Md.way0=p_listEntry.way; //myself is way to store compressed page
					ZsPg_Md.way_vld[0]=1'b1;	
					//ZsPg_Md.page0=(p_listEntry.way<<12)+ZS_OFFSET; //myself is the page plus offset of metadata &  2 pointers
					ZsPg_Md.page0=p_listEntry.attEntryId; //NEW_UPDATE_RAGHAV
					ZsPg_Md.pg_vld[0]=1'b1;	
					//send this packet and way_addr pg write to write compressed page, 
					//send tol_update packet to PWM to update uncompressTail 
					//and push entry to compressed list
					n_iWayORcPagePkt.cPage_byteStart=(p_listEntry.way<<12)+ZS_OFFSET;
					n_iWayORcPagePkt.cpage_size=comp_size;
					//payload
					n_iWayORcPagePkt.iWay_ptr=(p_listEntry.way<<12);
					n_iWayORcPagePkt.nxtWay_ptr='d0; //this is valid once we add new ways
					n_iWayORcPagePkt.zsPgMd=ZsPg_Md;
					//we can send update only if comp_size plus
					//payload of zspg can fit in 4KB that is
					//comp_size+ZS_OFFSET bytes
					if((comp_size+ZS_OFFSET) < 4096) begin
						n_iWayORcPagePkt.update=1'b1;
						n_comp_tol_updpkt.dst_list=NULLIFY; //PREP state cannot be full Zspage //IFL_SIZE1; //for ZS identiy way, we need to push on Identity Way
					end
					else begin
			        		n_state=COMP_MNGR_ERROR;
					end
					
					//If we have page in
					//underconstruction, no need to put in IFL

					
				`ifdef HAWK_SIMS
					$display("NAIVE_DEBUG:Traferring comp page on to cPage_byteStart=%x",n_iWayORcPagePkt.cPage_byteStart);
				`endif
				end
			        if (zspg_updated) begin	
					n_iWayORcPagePkt.update=1'b0;
					n_zsPgCnt = zsPgCnt + 'd1; //just for debug//analysis
			        	n_state=UPDATE_ATT_POP_UCMP_HEAD;
				end
		end
		UPDATE_ATT_POP_UCMP_HEAD:begin //wait till Zspage is written
				if( pgwr_mngr_ready) begin //update ATT and TOL then 
					n_comp_tol_updpkt.attEntryId=p_listEntry.attEntryId;//tol_HT.uncompListHead;
					n_comp_tol_updpkt.tolEntryId=tol_HT.uncompListHead;
				  	n_comp_tol_updpkt.lstEntry=p_listEntry;
					n_comp_tol_updpkt.lstEntry.way=c_iWayORcPagePkt.cPage_byteStart;//now ATT way is byte address of compressed page
				  	n_comp_tol_updpkt.lstEntry.attEntryId='d0; //p_attEntryId;
					n_comp_tol_updpkt.src_list=UNCOMP;
					n_comp_tol_updpkt.ifl_idx=get_idx(comp_size);
					//n_comp_tol_updpkt.dst_list= ; dst list will be set by calling states
					n_comp_tol_updpkt.tbl_update=1'b1;
				end
			        if(tbl_update_done) begin
					//We have not created free way yet, pop uncompressed and keep compressing, till we find complete 4KB free way
					//if(p_comp_tol_updpkt.dst_list == UNCOMP) begin// it means, it was freeway, else it would had been NULLIFY if IFL*
					//	n_state= ATT_UPDATE_FREEWAY_ENTRY; //we are done here, 
					//end else begin
						n_state= PEEK_UCMP_HEAD;
					//end
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
			          	//if((c_iWayORcPagePkt.cPage_byteStart+comp_size)< (c_iWayORcPagePkt.iWay_ptr+4096) ) begin
			          	if (!c_iWayORcPagePkt.zspage_full) begin
				  	      n_iWayORcPagePkt.update=1'b1;
				  	end
				  	else begin
						
				  	      n_iWayORcPagePkt.nxtWay_ptr='d0; //p_listEntry.way<<12;
				  	      n_iWayORcPagePkt.update=1'b0; //no need to update metadata if page does not fit.

					      //With naive compression,I remove under cnstruction page if thre is no enough space to hold a completed compressed page, so new Zs page will be
					      //created ->It won't be air tight layout for bring-up
						n_state=PREP_ZSPAGE_MD;
						//record this IWay in Under Construction table
						n_UC_ifLst_iWay[size_idx]=(p_listEntry.way<<12); 
						n_UC_ifLst_iWay_valid[size_idx]=1'b1;
				  	end
				end
				if(zspg_updated) begin
				  	      n_iWayORcPagePkt.update=1'b0;
 						      //Here we need to check
						      //if maximum  pages are
						      //exhausted after
						      //inserting this
						      //compressed page, then pull
						      //zspage Iway from IFL
						      //so as to create new Zspage in next iteration
						      //Chaging approach: While compression we						      //will have//underconstution page,
						      //if not, we check IFL
						      //to pick which sohuld
						      //have been decompress
						      //manager
						      //if(c_iWayORcPagePkt.pp_ifl) begin
						        //n_state = POP_IFL;
						      //end else begin
							n_state = FREEWAY_OR_CONTINUE;
						      //end
				end
			end
		POP_IFL:begin
			   	if(pgwr_mngr_ready) begin //we push this zspage wich was nuliify entry to ifl head now
					//n_decomp_tol_updpkt.attEntryId=p_listEntry.attEntryId; //this is not rewuried for tol update only
					n_comp_tol_updpkt.tolEntryId=tol_HT.IfLstHead[size_idx]; //((c_iWayORcPagePkt.iWay_ptr-HAWK_PPA_START[47:0])>>12)+1;
				  	n_comp_tol_updpkt.lstEntry=p_listEntry;
				  	n_comp_tol_updpkt.lstEntry.attEntryId='d0; //p_attEntryId;
					//n_comp_tol_updpkt.lstEntry.way=c_iWayORcPagePkt.cPage_byteStart; //this is not rewuried for tol update only
					n_comp_tol_updpkt.TOL_UPDATE_ONLY='d1; 
					n_comp_tol_updpkt.src_list=IFL_SIZE1;
					n_comp_tol_updpkt.dst_list=IFL_DETACH; 
					n_comp_tol_updpkt.ifl_idx=get_idx(c_iWayORcPagePkt.cpage_size);
					n_comp_tol_updpkt.tbl_update=1'b1;		
				end
				if(tbl_update_done) begin
					n_state = FREEWAY_OR_CONTINUE;
					//under contrcution zspage is always
					//head,so invalid it after popping
					//head of ifl
					n_UC_ifLst_iWay[size_idx]='d0; 
					n_UC_ifLst_iWay_valid[size_idx]=1'b0;
				end			
		end
		FREEWAY_OR_CONTINUE: begin
			          	      if((c_iWayORcPagePkt.cPage_byteStart+comp_size)< ({c_iWayORcPagePkt.cPage_byteStart[47:12],12'd0}+4096) ) begin
					      	      //n_comp_tol_updpkt.dst_list=UNCOMP;  
			        	      	      //n_state=UPDATE_ATT_POP_UCMP_HEAD;
				  		      n_state = TOL_UPDATE_FREEWAY_ENTRY; //we are done
					      end else begin
				  	      	      	//Update ATT and TOL
					      	      	n_comp_tol_updpkt.dst_list=NULLIFY; //for nullify ATT still get compression status but entry in list will be dangled 
			        	      	      	n_state=UPDATE_ATT_POP_UCMP_HEAD;
					      end
		end
		TOL_UPDATE_FREEWAY_ENTRY:begin
			   	if(pgwr_mngr_ready) begin //we can make zspg_updated is level signal till next reqeust, but pgwr*ready is good enough
					n_comp_tol_updpkt.attEntryId=p_listEntry.attEntryId; //tol_HT.uncompListHead;
					n_comp_tol_updpkt.tolEntryId=tol_HT.uncompListHead;
				  	n_comp_tol_updpkt.lstEntry=p_listEntry;
				  	n_comp_tol_updpkt.lstEntry.attEntryId=p_attEntryId;
					n_comp_tol_updpkt.lstEntry.way=c_iWayORcPagePkt.cPage_byteStart; //p_listEntry.way;//now ATT way if freeway
					n_comp_tol_updpkt.src_list=UNCOMP;
					n_comp_tol_updpkt.dst_list=UNCOMP; //I got freeway, list entry remain in same staet
					n_comp_tol_updpkt.ifl_idx=get_idx(comp_size);
					n_comp_tol_updpkt.tbl_update=1'b1;		
				end
				if(tbl_update_done) begin
					n_state = ATT_UPDATE_FREEWAY_ENTRY; 
				end
		end
		ATT_UPDATE_FREEWAY_ENTRY:begin
			   	if(pgwr_mngr_ready) begin //we can make zspg_updated is level signal till next reqeust, but pgwr*ready is good enough
					n_comp_tol_updpkt.attEntryId=p_attEntryId;
					n_comp_tol_updpkt.lstEntry.way=p_listEntry.way;//now ATT way if freeway
					n_comp_tol_updpkt.ATT_UPDATE_ONLY=1'b1;
					n_comp_tol_updpkt.ATT_STS=STS_UNCOMP;
					if(zeroBlkWr) begin
					    n_comp_tol_updpkt.zpd_cnt='d1; //if the write upon decompression is zero, initialize it to 1
					end
					else begin
					    n_comp_tol_updpkt.zpd_cnt='d0; //else zero
					end
					n_comp_tol_updpkt.tbl_update=1'b1;		
				end
				if(tbl_update_done) begin   
					n_comp_tol_updpkt.ATT_UPDATE_ONLY=1'b0;
					n_state = DONE; 
				end
		end

		DONE: begin
					n_cmpresn_done=1'b1;
					n_cmpresn_freeWay=p_listEntry.way;
					n_state = IDLE; //we are done  
		end

		COMP_MNGR_ERROR: begin
			   n_state = COMP_MNGR_ERROR;
		end
		BUS_ERROR: begin
			   //assert trigger, connect it to spare LED.
			   //Stay here forever unless, user resets
			   n_state = BUS_ERROR;
		end
		PLACE_HOLDER : begin
			   n_state = PLACE_HOLDER;
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
		comp_start <=1'b0;
		c_iWayORcPagePkt<='d0;
		cmpresn_done<=1'b0;
	        cmpresn_freeWay<='d0;
		comp_rdm_reset<=1'b0;
		zsPgCnt<='d0;
	end
	else begin
 		p_state <= n_state;	
		p_listEntry <= n_listEntry;
		p_burst_cnt <= n_burst_cnt;
		comp_start<=n_comp_start;
		c_iWayORcPagePkt<=n_iWayORcPagePkt;
		cmpresn_done<=n_cmpresn_done;
	        cmpresn_freeWay<=n_cmpresn_freeWay;
		comp_rdm_reset<=n_comp_rdm_reset;
		zsPgCnt<=n_zsPgCnt;
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
			UC_ifLst_iWay_valid[fl]<=1'b0;
		end else begin
			UC_ifLst_iWay[fl]<=n_UC_ifLst_iWay[fl];
			UC_ifLst_iWay_valid[fl]<=n_UC_ifLst_iWay_valid[fl];
		end
	end
end : ifLST_IWAY
endgenerate


//Debug
assign debug_cmp_mngr.cmp_mngr_state=p_state;
assign debug_cmp_mngr.cmpresn_freeWay=cmpresn_freeWay;
assign debug_cmp_mngr.cmpresn_done=cmpresn_done;
assign debug_cmp_mngr.zsPgCnt=zsPgCnt;
endmodule
