`include "hacd_define.vh"
import hacd_pkg::*;
import hawk_rd_pkg::*;
`define FSM_WID_COMPCTR 4

module hawk_zsp_compacter (
    input clk_i,
    input rst_ni,
    
    input logic compact_trig,
    output logic compact_req,
    output logic compact_done,
    input logic decomp_mngr_done,
    
    input hacd_pkg::hawk_tol_ht_t tol_HT,
    output hacd_pkg::zsPageCompactPkt_t zspg_cmpact_pkt
);
typedef logic [`FSM_WID_COMPCTR-1:0] state_t;
state_t n_state,p_state;
localparam IDLE			     ='d0,
	   PEEK_IFL_TAIL	     ='d1,
	   FETCH_SRC_PAGE	     ='d2,
	   FETCH_SRC_PAGE	     ='d3,
	   FETCH_DST_PAGE	     ='d4,

localparam [3:0] FREEPAGE_CNT=4;
localparam [3:0] COMPACT_THRSHLD=1;
zsPageCompactPkt_t n_zscpt_pkt,p_zscpt_pkt;
function automatic  zsPageCompactPkt_t getPage2Compact;
	input zsPageCompactPkt_t pkt;
	input state_t p_state;
	input ZsPg_Md_t md;
	
	//default
	getPage2Compact=pkt;
	
	if	(p_state == FETCH_SRC_PAGE || p_state == PEEK_IFL_TAIL) begin 
		if(md.way_vld[0]) begin
			if    (md.pg_vld[0]) begin
				getPage2Compact.src_cpage_ptr=md.page0;
				md.pg_vld[0]=1'b0; //reset
			end else if (md.pg_vld[1]) begin
				getPage2Compact.src_cpage_ptr=md.page1;
				md.pg_vld[1]=1'b0; //reset
			end
		end
		getPage2Compact.src_empty=~|md.pg_vld[MAX_PAGE_ZSPAGE-1:0]; //all are zero, we can free this way
		`ifndef SYNTH
			$display("RAGHAV_DEBUG FECTH_SRC_PAGE = %0h, push_freeway=%0d",getPage2Compact.src_cpage_ptr,getPage2Compact.src_empty);
		`endif
	end 	
        else if (p_state == FETCH_DST_PAGE || p_state == PEEK_IFL_HEAD) begin
		if(md.way_vld[0]) begin
			if    (!md.pg_vld[0]) begin
				getPage2Compact.dst_cpage_ptr=md.page0;
				md.pg_vld[0]=1'b1; //set
			end else if (!md.pg_vld[1]) begin
				getPage2Compact.dst_cpage_ptr=md.page1;
				md.pg_vld[0]=1'b1; //set
			end
		end
		getPage2Compact.dst_full=&md.pg_vld[MAX_PAGE_ZSPAGE-1:0]; //all are zero, we can free this way
		`ifndef SYNTH
			$display("RAGHAV_DEBUG FECTH_DST_PAGE = %0h, push_freeway=%0d",getPage2Compact.dst_cpage_ptr,getPage2Compact.src_empty);
		`endif
	end
endfunction


always@* begin
	case(p_state)
		IDLE: begin
			if(compact_trig && (tol_HT.IfLstHead[0] != tol_HT.IfLstTail[0])) begin //We need 256 different triggers here
				n_state=PEEK_IFL_TAIL;
			end
		end
		PEEK_IFL_TAIL: begin
			if(p_zscpt_pkt.src_empty) begin
				if(arready && !arvalid) begin
				           n_comp_axireq = get_axi_rd_pkt(tol_HT.IfLstTail[0],'d0,AXI_RD_TOL); 
				           n_comp_req_arvalid = 1'b1;
				           n_state = FETCH_SRC_PAGE;
				end 
			end
			else begin
				     	   n_zscpt_pkt= getPage2Compact(p_zspage_src_md,p_zscpt_pkt,p_state);  
					   n_state = PEEK_IFL_HEAD;
			end
		end
		FETCH_SRC_PAGE: begin 
			  if(rvalid && rlast) begin 
				if(rresp =='d0) begin
				     n_zspage_src_md=rdata[(50*8-1)+2*48:2*48];
				     n_zscpt_pkt= getPage2Compact(n_zspage_src_md,p_zscpt_pkt,p_state);  
				     n_state = PEEK_IFL_HEAD;
				end
				else n_state = BUS_ERROR;
			  end
		end
		PEEK_IFL_HEAD: begin
			if(p_zscpt_pkt.dst_full) begin
				if(arready && !arvalid) begin
				           n_comp_axireq = get_axi_rd_pkt(tol_HT.IfLstHead[0],'d0,AXI_RD_TOL); 
				           n_comp_req_arvalid = 1'b1;
				           n_state = FETCH_DST_PAGE;
				end 
			end
			else begin
				     	   n_zscpt_pkt= getPage2Compact(p_zspage_dst_md,p_zscpt_pkt,p_state);  
					   n_state = RESET_FIFO_PTRS;
			end
		end
		FETCH_DST_PAGE: begin
			  if(rvalid && rlast) begin 
				if(rresp =='d0) begin
				     n_zspage_dst_md=rdata[(50*8-1)+2*48:2*48];
				     n_zscpt_pkt= getPage2Compact(n_zspage_dst_md,p_zscpt_pkt,p_state);  
				     n_state = RESET_FIFO_PTRS;
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
			        n_decomp_axireq.addr = p_zscpt_pkt.src_cpage_ptr; 
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
				n_zscpt_pkt.migrate=1'b1;
				n_state=MIGRATE;
			end
		end
		MIGRATE: begin
			        if (zspg_updated) begin //this also makes sure, decomprssed page has been written 	
				   n_zscpt_pkt.migrate=1'b0;
					//Do we need IFL push
					if(p_zscpt_pkt.src_empty) begin
			           		n_state= PUSH_FREEWAY;
					end
					else if (p_zscpt_pkt.dst_full) begin
			           		n_state= DETACH_IFL_HEAD;
					end
					else n_state = DONE;
				end
		end
		PUSH_FREEWAY : begin
			   	if(pgwr_mngr_ready) begin //we push this zspage wich was nuliify entry to ifl head now
					//n_decomp_tol_updpkt.attEntryId=p_listEntry.attEntryId; //tol_HT.uncompListHead;
					n_decomp_tol_updpkt.tolEntryId=((dc_iWayORcPagePkt.iWay_ptr-HAWK_PPA_START[47:0])>>12)+1;
				  	//n_decomp_tol_updpkt.lstEntry=p_listEntry;
				  	n_decomp_tol_updpkt.lstEntry.attEntryId='d0; //p_attEntryId;
					//n_decomp_tol_updpkt.lstEntry.way=c_iWayORcPagePkt.cPage_byteStart;
					n_decomp_tol_updpkt.TOL_UPDATE_ONLY=1'b1;
					n_decomp_tol_updpkt.src_list=IFL_DETACH; //it was detached before from ifl
					n_decomp_tol_updpkt.dst_list=IFL_SIZE1; 
					n_decomp_tol_updpkt.ifl_idx=get_idx(dc_iWayORcPagePkt.cpage_size);
					n_decomp_tol_updpkt.tbl_update=1'b1;		
				end
				if(tbl_update_done) begin
					n_state = DETACH_IFL_HEAD; 
				end
				$display("RAGHAV_DEBUG:In PUSH_IFL");
		end
		DETACH_IFL_HEAD : begin
				if (p_zscpt_pkt.dst_full) begin
			   		if(pgwr_mngr_ready) begin //we push this zspage wich was nuliify entry to ifl head now
						//n_decomp_tol_updpkt.attEntryId=p_listEntry.attEntryId; //tol_HT.uncompListHead;
						n_decomp_tol_updpkt.tolEntryId=((dc_iWayORcPagePkt.iWay_ptr-HAWK_PPA_START[47:0])>>12)+1;
					  	//n_decomp_tol_updpkt.lstEntry=p_listEntry;
					  	n_decomp_tol_updpkt.lstEntry.attEntryId='d0; //p_attEntryId;
						//n_decomp_tol_updpkt.lstEntry.way=c_iWayORcPagePkt.cPage_byteStart;
						n_decomp_tol_updpkt.TOL_UPDATE_ONLY=1'b1;
						n_decomp_tol_updpkt.src_list=IFL_DETACH; //it was detached before from ifl
						n_decomp_tol_updpkt.dst_list=IFL_SIZE1; 
						n_decomp_tol_updpkt.ifl_idx=get_idx(dc_iWayORcPagePkt.cpage_size);
						n_decomp_tol_updpkt.tbl_update=1'b1;		
					end
					if(tbl_update_done) begin
						n_state = DONE; 
					end
				end
				$display("RAGHAV_DEBUG:In PUSH_IFL");				   
		end
		DONE: begin
				n_state = IDLE;
		end
	endcase
end
//state register/output flops
always @(posedge clk_i or negedge rst_ni)
begin
	if(!rst_ni) begin
		p_state <= IDLE;
		p_zscpt_pkt <= 'd0;
	end
	else begin
 		p_state <= n_state;	
		p_zscpt_pkt <= n_zscpt_pkt;
	end
end




logic [FREEPAGE_CNT-1:0] freepage_count; //[IFLST_COUNT];
always @(posedge clk_i or negedge rst_ni)
begin
	if(!rst_ni) begin
		freepage_count<='d0;
	end
	else if (decomp_mngr_done) begin
		freepage_count<= freepage_count + 'd1;
	end
	else if (migrated && freepage_count >'d0) begin
		freepage_count<= freepage_count - 'd1;
	end
end
assign compact_req = (freepage_count >= COMPACT_THRSHLD);
assign compact_done= (p_state==DONE) && (tol_HT.IfLstHead[0] == tol_HT.IfLstTail[0]);
assign zspg_cmpact_pkt=p_zscpt_pkt;
endmodule
