`include "hacd_define.vh"
import hacd_pkg::*;
import hawk_rd_pkg::*;
`define FSM_WID_COMPCTR 5

module hawk_zsp_compacter (
    input clk_i,
    input rst_ni,
    
    input logic compact_trig,
    output logic compact_req,
    output logic compact_done,
    input logic decomp_mngr_done,

    input pgwr_mngr_ready,
    input tbl_update_done,

    //handshake with PWM
    input zspg_migrated,	
    output logic cmpt_rdm_reset,

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

    output hacd_pkg::axi_rd_pld_t n_cmpt_axireq,
    output logic n_cmpt_rready,
    output logic n_cmpt_req_arvalid,
    output logic [`HACD_AXI4_DATA_WIDTH-1:0] n_cmpt_rdata,
    output hacd_pkg::tol_updpkt_t n_cmpt_tol_updpkt,
 
    input hacd_pkg::hawk_tol_ht_t tol_HT,
    output hacd_pkg::zsPageMigratePkt_t zspg_mig_pkt
);
typedef logic [`FSM_WID_COMPCTR-1:0] state_t;
state_t n_state,p_state;
localparam [`FSM_WID_COMPCTR-1:0] 
	   IDLE			     ='d0,
	   PEEK_IFL_TAIL	     ='d1,
	   WAIT_IFL_TAIL	     ='d2,
	   DECODE_SRC_LST_ENTRY	     ='d3,
	   FETCH_SRC_PAGE	     ='d4,
	   WAIT_SRC_PAGE	     ='d5,
	   PEEK_IFL_HEAD	     ='d6,
	   WAIT_IFL_HEAD	     ='d7,
	   DECODE_DST_LST_ENTRY	     ='d8,
	   FETCH_DST_PAGE	     ='d9,
	   WAIT_DST_PAGE	     ='d10,
	   RESET_FIFO_PTRS	     ='d11,	
	   WAIT_RESET 		     ='d12,
	   BURST_READ_START	     ='d13,
	   BURST_READ		     ='d14,
	   MIGRATE		     ='d15,
	   PUSH_FREEWAY		     ='d16,
	   DETACH_IFL_HEAD	     ='d17,
	   ZSPAGE_UPDATE	     ='d18,
	   DONE			     ='d19,
	   BUS_ERROR		     ='d20;

localparam [3:0] FREEPAGE_CNT=4;
localparam [3:0] COMPACT_THRSHLD=1;

typedef struct packed{
	ZsPg_Md_t src_md;
	ZsPg_Md_t dst_md;
	logic src_empty;
	logic dst_full;
	logic [47:0] src_iWay_ptr;
	logic [47:0] dst_iWay_ptr;
	zsPageMigratePkt_t mig_pkt;
} zsPageCompactPkt_t;
zsPageCompactPkt_t n_zscpt_pkt,p_zscpt_pkt;

assign zspg_mig_pkt = p_zscpt_pkt.mig_pkt;

function automatic  zsPageCompactPkt_t getMigratePkt;
	input zsPageCompactPkt_t pkt;
	input state_t p_state;
	
	//default
	getMigratePkt=pkt;

	if	(p_state == FETCH_SRC_PAGE || p_state == PEEK_IFL_TAIL) begin 
		if(pkt.src_md.way_vld[0]) begin
			if    (pkt.src_md.pg_vld[0]) begin
				getMigratePkt.mig_pkt.src_cpage_ptr=pkt.src_md.page0;
				getMigratePkt.src_md.pg_vld[0]=1'b0; //reset
			end else if (pkt.src_md.pg_vld[1]) begin
				getMigratePkt.mig_pkt.src_cpage_ptr=pkt.src_md.page1;
				getMigratePkt.src_md.pg_vld[1]=1'b0; //reset
			end
		end
		getMigratePkt.src_empty=~|getMigratePkt.src_md.pg_vld[MAX_PAGE_ZSPAGE-1:0];
		`ifndef SYNTH
			$display("RAGHAV_DEBUG FECTH_SRC_PAGE = %0h, src empty=%0d",getMigratePkt.mig_pkt.src_cpage_ptr,getMigratePkt.src_empty);
		`endif
	end 	
        else if (p_state == FETCH_DST_PAGE || p_state == PEEK_IFL_HEAD) begin
		if(pkt.dst_md.way_vld[0]) begin
			if    (pkt.dst_md.pg_vld[0]) begin
				getMigratePkt.mig_pkt.dst_cpage_ptr=pkt.dst_md.page0;
				getMigratePkt.dst_md.pg_vld[0]=1'b0; //reset
			end else if (pkt.dst_md.pg_vld[1]) begin
				getMigratePkt.mig_pkt.dst_cpage_ptr=pkt.dst_md.page1;
				getMigratePkt.dst_md.pg_vld[1]=1'b0; //reset
			end
		end
		getMigratePkt.dst_full=&getMigratePkt.dst_md.pg_vld[MAX_PAGE_ZSPAGE-1:0];
		`ifndef SYNTH
			$display("RAGHAV_DEBUG FECTH_DST_PAGE = %0h, dst full=%0d",getMigratePkt.mig_pkt.dst_cpage_ptr,getMigratePkt.dst_full);
		`endif
	end
endfunction

ZsPg_Md_t zspage_md;
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
logic n_cmpt_rdm_reset;
logic [5:0] n_burst_cnt,p_burst_cnt;
ListEntry p_src_listEntry,n_src_listEntry;
ListEntry p_dst_listEntry,n_dst_listEntry;
always@* begin
//default
	n_state=p_state;	       //be in same state unless fsm decides to jump
	n_cmpt_axireq.addr= p_axireq.addr;
	n_cmpt_axireq.arlen = 8'd0; //by default, one beat
	n_cmpt_req_arvalid = 1'b0; 	       //fsm decides when to send packet
        n_cmpt_rready=1'b1;     
	n_cmpt_rdata=p_rdata;
	n_cmpt_tol_updpkt.tbl_update=1'b0;
	n_cmpt_tol_updpkt.TOL_UPDATE_ONLY=1'b0;
	n_burst_cnt=p_burst_cnt;	
	n_cmpt_rdm_reset=1'b0;
	//lookup IF list for corresponding size
	case(p_state)
		IDLE: begin
			if(compact_trig && (tol_HT.IfLstHead[0] != tol_HT.IfLstTail[0])) begin //We need 256 different triggers here
				n_state=PEEK_IFL_TAIL;
			end
		end
		PEEK_IFL_TAIL: begin
			if(p_zscpt_pkt.src_empty) begin
				if(arready && !arvalid) begin
				           n_cmpt_axireq = get_axi_rd_pkt(tol_HT.IfLstTail[0],'d0,AXI_RD_TOL); 
				           n_cmpt_req_arvalid = 1'b1;
				           n_state = WAIT_IFL_TAIL;;
				end 
			end
			else begin
				     	   n_zscpt_pkt= getMigratePkt(p_zscpt_pkt,p_state);  
					   n_state = PEEK_IFL_HEAD;
			end
		end
		WAIT_IFL_TAIL: begin //we can have multiple beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(rvalid && rlast) begin //rlast is expected as we have only one beat//added assertion for this
				if(rresp =='d0) begin
				     n_cmpt_rdata= rdata;  
				     n_state = DECODE_SRC_LST_ENTRY;
				end
				else n_state = BUS_ERROR;
			  end
		end
		DECODE_SRC_LST_ENTRY: begin
			   n_src_listEntry=decode_LstEntry(tol_HT.IfLstTail[0],p_rdata);
			   n_state=FETCH_SRC_PAGE;
		end
		FETCH_SRC_PAGE : begin
				if(arready && !arvalid) begin
				           n_cmpt_axireq.addr = (p_src_listEntry.way<<12); 
				           n_cmpt_req_arvalid = 1'b1;
				           n_state = WAIT_SRC_PAGE;
				end 
		end
		WAIT_SRC_PAGE: begin 
			  if(rvalid && rlast) begin 
				if(rresp =='d0) begin
				     n_zscpt_pkt.src_md=rdata[(50*8-1)+2*48:2*48];
				     n_zscpt_pkt.src_iWay_ptr=rdata[(48-1)+0 : 0];
				     n_zscpt_pkt= getMigratePkt(n_zscpt_pkt,p_state);  
				     n_state = PEEK_IFL_HEAD;
				end
				else n_state = BUS_ERROR;
			  end
		end
		PEEK_IFL_HEAD: begin
			if(p_zscpt_pkt.dst_full) begin
				if(arready && !arvalid) begin
				           n_cmpt_axireq = get_axi_rd_pkt(tol_HT.IfLstHead[0],'d0,AXI_RD_TOL); 
				           n_cmpt_req_arvalid = 1'b1;
				           n_state = WAIT_IFL_HEAD;
				end 
			end
			else begin
				     	   n_zscpt_pkt= getMigratePkt(p_zscpt_pkt,p_state);  
					   n_state = RESET_FIFO_PTRS;
			end
		end
		WAIT_IFL_HEAD: begin //we can have multiple beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(rvalid && rlast) begin //rlast is expected as we have only one beat//added assertion for this
				if(rresp =='d0) begin
				     n_cmpt_rdata= rdata;  
				     n_state = DECODE_DST_LST_ENTRY;
				end
				else n_state = BUS_ERROR;
			  end
		end
		DECODE_DST_LST_ENTRY: begin
			   n_dst_listEntry=decode_LstEntry(tol_HT.IfLstHead[0],p_rdata);
			   n_state=FETCH_DST_PAGE;
			   	
		end
		FETCH_DST_PAGE : begin
				if(arready && !arvalid) begin
				           n_cmpt_axireq.addr = (p_dst_listEntry.way<<12); 
				           n_cmpt_req_arvalid = 1'b1;
				           n_state = WAIT_DST_PAGE;
				end 
		end
		WAIT_DST_PAGE: begin
			  if(rvalid && rlast) begin 
				if(rresp =='d0) begin
				     n_zscpt_pkt.dst_md=rdata[(50*8-1)+2*48:2*48];
				     n_zscpt_pkt.dst_iWay_ptr=rdata[(48-1)+0 : 0];
				     n_zscpt_pkt= getMigratePkt(n_zscpt_pkt,p_state);  
				     n_state = RESET_FIFO_PTRS;
				end
				else n_state = BUS_ERROR;
			  end
		end
		RESET_FIFO_PTRS:begin
			   n_cmpt_rdm_reset = 1'b1; //Later connect this to WRITE FIFO as well. 
			   n_state=WAIT_RESET;
		end
		WAIT_RESET: begin
			   n_cmpt_rdm_reset = 1'b0;
			   n_state=BURST_READ_START;
			   n_burst_cnt=(get_cpage_size(p_zscpt_pkt.src_md.size) >> 6) + 1;
		end
		BURST_READ_START: begin
        		n_cmpt_rready=1'b0;     
			if(arready && !arvalid && p_burst_cnt > 'd0 && rdfifo_empty) begin
			        n_cmpt_axireq.addr = p_zscpt_pkt.mig_pkt.src_cpage_ptr; 
				n_cmpt_axireq.arlen = 8'd0; 
			        n_cmpt_req_arvalid = 1'b1;
				n_burst_cnt = p_burst_cnt - 'd1;
				n_state=BURST_READ;
			end
		end
		BURST_READ: begin
        		n_cmpt_rready=1'b0;     
			if(arready && !arvalid && (p_burst_cnt > 'd0) && !rdfifo_full) begin
			        n_cmpt_axireq.addr = p_axireq.addr + 64'd64; //16beats per burst, each beat is 64 bytes part(cacheline) 
				n_cmpt_axireq.arlen = 8'd0; 
			        n_cmpt_req_arvalid = 1'b1;
				n_burst_cnt = p_burst_cnt-'d1;
			end 
			else if(p_burst_cnt=='d0) begin
				n_zscpt_pkt.mig_pkt.migrate=1'b1;
				n_state=MIGRATE;
			end
		end
		MIGRATE: begin
			        if (zspg_migrated) begin  	
				   n_zscpt_pkt.mig_pkt.migrate=1'b0;
					//Do we need IFL push
					if(p_zscpt_pkt.src_empty) begin
			           		n_state= PUSH_FREEWAY;
					end
					else if (p_zscpt_pkt.dst_full) begin
			           		n_state= DETACH_IFL_HEAD;
					end
					else n_state = ZSPAGE_UPDATE;
				end
		end
		PUSH_FREEWAY : begin
			   	if(pgwr_mngr_ready) begin 
					//n_cmpt_tol_updpkt.attEntryId=
					n_cmpt_tol_updpkt.tolEntryId=((p_zscpt_pkt.src_iWay_ptr-HAWK_PPA_START[47:0])>>12)+1;
				  	n_cmpt_tol_updpkt.lstEntry=p_src_listEntry;
				  	n_cmpt_tol_updpkt.lstEntry.attEntryId='d0; //p_attEntryId;
					n_cmpt_tol_updpkt.TOL_UPDATE_ONLY=1'b1;
					n_cmpt_tol_updpkt.src_list=IFL_SIZE1;
					n_cmpt_tol_updpkt.dst_list=FREE; 
					n_cmpt_tol_updpkt.ifl_idx=p_zscpt_pkt.src_md.size;
					n_cmpt_tol_updpkt.tbl_update=1'b1;		
				end
				if(tbl_update_done) begin
					n_state = DETACH_IFL_HEAD; 
				end
				$display("RAGHAV_DEBUG:In PUSH_FREEWAY");
		end
		DETACH_IFL_HEAD : begin
				if (p_zscpt_pkt.dst_full) begin
			   		if(pgwr_mngr_ready) begin 
						//n_cmpt_tol_updpkt.attEntryId=
						n_cmpt_tol_updpkt.tolEntryId=((p_zscpt_pkt.dst_iWay_ptr-HAWK_PPA_START[47:0])>>12)+1;
					  	n_cmpt_tol_updpkt.lstEntry=p_dst_listEntry;
					  	n_cmpt_tol_updpkt.lstEntry.attEntryId='d0; 
						n_cmpt_tol_updpkt.TOL_UPDATE_ONLY=1'b1;
						n_cmpt_tol_updpkt.src_list=IFL_SIZE1; 
						n_cmpt_tol_updpkt.dst_list=IFL_DETACH; 
						n_cmpt_tol_updpkt.ifl_idx=p_zscpt_pkt.dst_md.size;
						n_cmpt_tol_updpkt.tbl_update=1'b1;		
					end
					if(tbl_update_done) begin
						n_state = ZSPAGE_UPDATE; 
					end
				end
				$display("RAGHAV_DEBUG:In DETACH_IFL_HEAD");				   
		end
		ZSPAGE_UPDATE:begin
				if (tol_HT.IfLstHead[0] == tol_HT.IfLstTail[0]) begin //full compaction done? then send zspage update for final entry that is src entry that remained
			   		if(pgwr_mngr_ready) begin 
						n_zscpt_pkt.mig_pkt.src_cpage_ptr=p_zscpt_pkt.src_iWay_ptr;
						n_zscpt_pkt.mig_pkt.md=p_zscpt_pkt.src_md;
						n_zscpt_pkt.mig_pkt.zspg_update=1'b1;
					end
			        	if (zspg_migrated) begin  	
				   		n_zscpt_pkt.mig_pkt.zspg_update=1'b0;
						n_state = DONE;
					end
				end else begin 
						n_state = PEEK_IFL_TAIL;
				end
		end
		DONE: begin
				n_state = IDLE;
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
		p_zscpt_pkt <= 'd0;
	        cmpt_rdm_reset <=1'b0;
		p_src_listEntry <='d0;
		p_dst_listEntry <='d0;
	end
	else begin
 		p_state <= n_state;	
		p_zscpt_pkt <= n_zscpt_pkt;
	        cmpt_rdm_reset <= n_cmpt_rdm_reset;
		p_src_listEntry <= n_src_listEntry;
		p_dst_listEntry <= n_dst_listEntry;
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
	else if (zspg_migrated && freepage_count >'d0) begin
		freepage_count<= freepage_count - 'd1;
	end
end
assign compact_req = 1'b0; //(freepage_count >= COMPACT_THRSHLD);
assign compact_done= (p_state==DONE) && (tol_HT.IfLstHead[0] == tol_HT.IfLstTail[0]);
assign zspg_cmpact_pkt=p_zscpt_pkt;
endmodule
