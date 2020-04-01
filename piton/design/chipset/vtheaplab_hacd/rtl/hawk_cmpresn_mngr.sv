//If it is fresh Zspage creation, we need min 2 uncomp pages
`include "hacd_define.vh"
import hacd_pkg::*;
import hawk_rd_pkg::*;
`define FSM_WID_CMP_MNGR 4
module hawk_cmpresn_mngr (
    input cmpresn_trigger,
    input [clogb2(LST_ENTRY_MAX)-1:0] uncompLstTail,
    input logic [clogb2(ATT_ENTRY_MAX)-1:0] p_attEntryId,

    //AXI inputs  
    input hacd_pkg::axi_rd_rdypkt_t rd_rdypkt,
    input hacd_pkg::axi_rd_resppkt_t rd_resppkt,
     
    //previous AXI commands
    input hacd_pkg::axi_rd_pld_t p_axireq,
    input logic [`HACD_AXI4_DATA_WIDTH-1:0] p_rdata,

    output hacd_pkg::axi_rd_pld_t n_comp_axireq,
    output logic n_comp_rready,
    output logic n_comp_req_arvalid,
    output logic [`HACD_AXI4_DATA_WIDTH-1:0] n_comp_rdata,
    output hacd_pkg::trnsl_reqpkt_t n_comp_trnsl_reqpkt,
    output hacd_pkg::tol_updpkt_t n_comp_tol_updpkt,
    output logic cmpresn_done,
    output logic [`HACD_AXI4_ADDR_WIDTH-1:12] cmpresn_freeWay	
);

axi_rd_pld_t n_axireq;
logic p_req_arvalid,n_req_arvalid,p_rready,n_rready;
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
	   POP_UCMP_TAIL	='d1;

ListEntry n_listEntry;

always@* begin
//default
	n_state=p_state;	       //be in same state unless fsm decides to jump
	n_axireq= p_axireq;
	n_req_arvalid = 1'b0; 	       //fsm decides when to send packet
        n_rready=1'b1;   //no reason why we block read, as we are sure to issue arvlaid only when we need  
	n_rdata=p_rdata;
	n_comp_trnsl_reqpkt.allow_access=1'b0;
	n_comp_tol_updpkt.tbl_update=1'b0;
	case(p_state)
		IDLE: begin
			if(cmpresn_trigger && ) begin
				n_state=POP_UCMP_TAIL;
			end
		end
		POP_UCMP_TAIL: begin
			if(arready && !arvalid) begin
			           n_axireq = get_axi_rd_pkt(uncompTail,p_attEntryId,AXI_RD_TOL); //, first arguemnt is not useful, for this state
			           n_req_arvalid = 1'b1;
			           n_state = WAIT_ATT_ENTRY;
			end 
		end
		WAIT_UCMP_TAIL: begin //we can have multiple beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(rvalid && rlast) begin //rlast is expected as we have only one beat//added assertion for this
				if(rresp =='d0) begin
				     n_rdata= rdata; //get_8byte_byteswap(rdata); //swap back the data, as we had written swapped format to be compatible with ariane. 
				     n_state = DECODE_LST_ENTRY;
				end
				else n_state = BUS_ERROR;
			  end
		end
		DECODE_LST_ENTRY: begin
			   n_listEntry=decode_LstEntry(lkup_reqpkt.hppa,p_rdata);
			   //n_trnsl_reqpkt
			   //get address for
			
		end
		PREP_ZSPAGE_MD:begin
		
		end



	endcase
end
//state register/output flops
always @(posedge clk_i or negedge rst_ni)
begin
	if(!rst_ni) begin
		p_state <= IDLE;
	end
	else begin
 		p_state <= n_state;	
	end
end

localparam bit[13:0] suprted_comp_size[0]=512; //supportable compressed sizes in bytes, just one for now
integer i;
logic [47:0] ifLst_iWay[1];

genvar fl;
generate
for(fl=0;fl<1;fl=fl+1) begin : ifLST_IWAY
	always @(posedge clk_i or negedge rst_ni) begin
		if(!rst_ni) begin
			ifLst_iWay[fl]<='d0; //0 corresponds for NULL
		end else begin
			if(suprted_comp_size[fl]==comp_size)
				ifLst_iWay[fl]<=n_ifLst_iWay;
		end
	end
end : ifLST_IWAY

endmodule
