//If it is fresh Zspage creation, we need min 2 uncomp pages
`include "hacd_define.vh"
import hacd_pkg::*;
import hawk_rd_pkg::*;
`define FSM_WID_CMP_MNGR 4
module hawk_cmpresn_mngr (
    input clk_i,
    input rst_ni,

    input cmpresn_trigger,
    input [clogb2(LST_ENTRY_MAX)-1:0] uncompLstTail,
    input logic [clogb2(ATT_ENTRY_MAX)-1:0] p_attEntryId,

    //from compressor
    input logic [13:0] comp_size,
    output logic comp_start,
    input comp_done,
    
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
    output hacd_pkg::trnsl_reqpkt_t n_comp_trnsl_reqpkt,
    output hacd_pkg::tol_updpkt_t n_comp_tol_updpkt,
    output logic cmpresn_done,
    output logic [`HACD_AXI4_ADDR_WIDTH-1:12] cmpresn_freeWay	
);

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
localparam IDLE			='d0,
	   POP_UCMP_TAIL	='d1,
	   WAIT_UCMP_TAIL	='d2,
	   DECODE_LST_ENTRY	='d3,
	   BURST_READ		='d4,
	   COMP_WAIT		='d5,
	   PREP_ZSPAGE_MD	='d6,
	   MIGRATE_TO_ZSPAGE	='d7,
	   BUS_ERROR		='d8;


localparam bit[13:0] suprted_comp_size[2]={128,64}; //supportable compressed sizes in bytes, just one for now

function logic [7:0] get_idx;
	input [13:0] size;
	integer i; 
	for(i=0;i<256;i=i+1) begin
		if(suprted_comp_size[i]==size) begin
			get_idx=i;	
		end
	end
endfunction

logic [7:0] size_idx;

logic [13:0] n_comp_size,p_comp_size;
ListEntry p_listEntry,n_listEntry;
logic [1:0] n_burst_cnt,p_burst_cnt;
logic n_comp_start;
ZsPg_Md_t n_ZsPg_Md,p_ZsPg_Md;
logic [clogb2(LST_ENTRY_MAX)-1:0] n_IfLst_Head[1],IfLst_Head[1];
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
	n_comp_trnsl_reqpkt.allow_access=1'b0;
	n_comp_tol_updpkt.tbl_update=1'b0;
	n_comp_start=1'b0;
	n_cmpresn_done=1'b0;

	case(p_state)
		IDLE: begin
			if(cmpresn_trigger) begin
				n_state=POP_UCMP_TAIL;
			end
		end
		POP_UCMP_TAIL: begin
			if(arready && !arvalid) begin
			           n_comp_axireq = get_axi_rd_pkt(uncompLstTail,p_attEntryId,AXI_RD_TOL); //, first arguemnt is not useful, for this state
			           n_comp_req_arvalid = 1'b1;
			           n_state = WAIT_UCMP_TAIL;
			end 
		end
		WAIT_UCMP_TAIL: begin //we can have multiple beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(rvalid && rlast) begin //rlast is expected as we have only one beat//added assertion for this
				if(rresp =='d0) begin
				     n_comp_rdata= rdata; //get_8byte_byteswap(rdata); //swap back the data, as we had written swapped format to be compatible with ariane. 
				     n_state = DECODE_LST_ENTRY;
				end
				else n_state = BUS_ERROR;
			  end
		end
		DECODE_LST_ENTRY: begin
			   n_listEntry=decode_LstEntry(uncompLstTail,p_rdata);
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
				if(IfLst_Head[size_idx]!=NULL) begin
					n_state=MIGRATE_TO_ZSPAGE; 
				end else begin
					n_IfLst_Head[size_idx]=uncompLstTail;
					n_state=PREP_ZSPAGE_MD;
				end
			end
		end
		PREP_ZSPAGE_MD:begin
				//ZSPage Identiy way takes one cache line
				n_ZsPg_Md.size=comp_size;
				n_ZsPg_Md.way1=p_listEntry.way; //myself is way to store compressed page
				n_ZsPg_Md.way_vld=1'b1;	
				n_ZsPg_Md.page0=p_listEntry.way; //myself is the page
				n_ZsPg_Md.pg_vld=1'b1;	
				//send this packet and way_addr pg write to write compressed page, 
				//send tol_update packet to PWM to update uncompressTail 
				//and push entry to compressed list
				
				//We have not created free way yet, pop at-least
				//one more uncompressed
				n_state=POP_UCMP_TAIL;
		end
		MIGRATE_TO_ZSPAGE:begin //not handling now
				//send 
		end
		DONE: begin
				n_cmpresn_done=1'b1;
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
		p_ZsPg_Md<='d0;
		cmpresn_done<=1'b0;
	end
	else begin
 		p_state <= n_state;	
		p_listEntry <= n_listEntry;
		p_burst_cnt <= n_burst_cnt;
		comp_start<=n_comp_start;
		p_ZsPg_Md<=n_ZsPg_Md;
		cmpresn_done<=n_cmpresn_done;
	end
end



//logic [clogb2(LST_ENTRY_MAX)-1:0] IfLst_Tail[1];
genvar if_h;
generate 
for(if_h=0;if_h<IFLST_COUNT;if_h=if_h+1) begin
	always @(posedge clk_i or negedge rst_ni)
	begin
		if(!rst_ni) begin
			IfLst_Head[i]<='d0;
		end
		else begin
			IfLst_Head[i]<=n_IfLst_Head[i];
		end
	end
end
endgenerate

logic [47:0] ifLst_iWay[IFLST_COUNT];
genvar fl;
generate
for(fl=0;fl<IFLST_COUNT;fl=fl+1) begin : ifLST_IWAY
	always @(posedge clk_i or negedge rst_ni) begin
		if(!rst_ni) begin
			ifLst_iWay[fl]<='d0; //0 corresponds for NULL
		end else begin
			if(suprted_comp_size[fl]==comp_size  && p_state==PREP_ZSPAGE_MD) //Save page iWay of page under construction
				ifLst_iWay[fl]<=p_listEntry.way;
		end
	end
end : ifLST_IWAY
endgenerate

endmodule
