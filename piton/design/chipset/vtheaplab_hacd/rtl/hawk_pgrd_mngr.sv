//Description:
// Supports multiple modes , controlled by hawk control unit
//
`include "hacd_define.vh"
import hacd_pkg::*;
import hawk_rd_pkg::*;
`define FSM_WID_PGRD 4
module hawk_pgrd_mngr (

  input clk_i,
  input rst_ni,

  input hacd_pkg::att_lkup_reqpkt_t lkup_reqpkt,
  output logic rdm_reset,
 
  //handshake with PWM
  input zspg_updated,
  input zspg_migrated,
  input tbl_update_done,
  output hacd_pkg::iWayORcPagePkt_t iWayORcPagePkt,
  output hacd_pkg::zsPageMigratePkt_t zspg_mig_pkt,
	
  //from compressor
  input logic [13:0] comp_size,
  output logic comp_start,
  input wire comp_done,
  input wire incompressible,

  output logic decomp_start,
  input wire decomp_done,
 
  //from AXI FIFO
  input wire rdfifo_full,
  input wire rdfifo_empty,

 //with PWM
  input pgwr_mngr_ready,

  input hacd_pkg::hawk_tol_ht_t tol_HT,

  //AXI packets
  input hacd_pkg::axi_rd_rdypkt_t rd_rdypkt,
  output hacd_pkg::axi_rd_reqpkt_t rd_reqpkt,
  input hacd_pkg::axi_rd_resppkt_t rd_resppkt,

  output hacd_pkg::trnsl_reqpkt_t trnsl_reqpkt,
  output hacd_pkg::tol_updpkt_t tol_updpkt,
  output pgrd_mngr_ready,

  //DEBUG
  output [`FSM_WID_PGRD-1:0] prm_state,
  output hacd_pkg::debug_pgrd_cmp_mngr debug_cmp_mngr,	
  output hacd_pkg::debug_pgrd_decmp_mngr debug_decmp_mngr,
 
  output hacd_pkg::debug_pgrd_mngr debug_hkpgrd_mngr
);

  //in waves, not able to obseves struct ports, so mapping for easier debug
  wire lookup;
  wire [`HACD_AXI4_ADDR_WIDTH-1:12] lookup_hppa;
  assign lookup=lkup_reqpkt.lookup;
  assign lookup_hppa=lkup_reqpkt.hppa;

  wire [clogb2(LST_ENTRY_MAX)-1:0] freeLstHead;	
  wire [clogb2(LST_ENTRY_MAX)-1:0] freeLstTail;
  wire [clogb2(LST_ENTRY_MAX)-1:0] uncompLstHead;	
  wire [clogb2(LST_ENTRY_MAX)-1:0] uncompLstTail;
	
  assign freeLstHead=tol_HT.freeListHead;
  assign freeLstTail=tol_HT.freeListTail;

  assign uncompLstHead=tol_HT.uncompListHead;
  assign uncompLstTail=tol_HT.uncompListTail;

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
	   DECODE_ATT_ENTRY	='d3,
	   CHK_ATT_ENTRY	='d4,
	   POP_FREE_LST 	='d5,
	   WAIT_LST_ENTRY	='d6,
           DECODE_LST_ENTRY	='d7,
	   ALLOCATE_PPA 	='d8,
	   TBL_UPDATE		='d9,
	   TBL_UPDATE_DONE	='d10,
	   COMPRESS		='d11,
	   DECOMPRESS		='d12,
	   COMPACT		='d13,
	   BUS_ERROR		='d14;



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

hacd_pkg::axi_rd_pld_t p_axireq,n_axireq;
hacd_pkg::trnsl_reqpkt_t n_trnsl_reqpkt,p_trnsl_reqpkt;

logic [clogb2(ATT_ENTRY_MAX)-1:0] n_attEntryId,p_attEntryId;
hacd_pkg::tol_updpkt_t n_tol_updpkt,p_tol_updpkt;
hacd_pkg::tol_updpkt_t n_comp_tol_updpkt;
hacd_pkg::tol_updpkt_t n_decomp_tol_updpkt;
hacd_pkg::tol_updpkt_t n_cmpt_tol_updpkt;


//handshakes with comp_manager
wire cmpresn_done;
wire logic [`HACD_AXI4_ADDR_WIDTH-1:12] cmpresn_freeWay;
axi_rd_pld_t n_comp_axireq;
logic n_comp_req_arvalid,n_comp_rready;
logic [`HACD_AXI4_DATA_WIDTH-1:0] n_comp_rdata;
//
wire decomp_mngr_done;
hacd_pkg::axi_rd_pld_t p_decomp_axireq;
logic p_decomp_req_arvalid,n_decomp_rready;
logic [`HACD_AXI4_DATA_WIDTH-1:0] n_decomp_rdata;
logic [`HACD_AXI4_ADDR_WIDTH-1:0] n_decomp_cPage_byteStart,decomp_cPage_byteStart;
logic  [`HACD_AXI4_ADDR_WIDTH-1:0] n_decomp_freeWay,decomp_freeWay;

//compacter
logic compact_trig;
logic compact_req;
logic compact_done;
axi_rd_pld_t n_cmpt_axireq;
logic n_cmpt_req_arvalid,n_cmpt_rready;
logic [`HACD_AXI4_DATA_WIDTH-1:0] n_cmpt_rdata;

logic n_alert_out_of_memory,alert_out_of_memory;

//logic to handle different modes
always@* begin
//default
	n_state=p_state;	       //be in same state unless fsm decides to jump
	n_axireq= p_axireq;
	n_req_arvalid = 1'b0; 	       //fsm decides when to send packet
        n_rready=1'b1;   //no reason why we block read, as we are sure to issue arvlaid only when we need  
	n_rdata=p_rdata;
	n_trnsl_reqpkt = p_trnsl_reqpkt;
	n_trnsl_reqpkt.allow_access=1'b0;
	n_tol_updpkt = p_tol_updpkt;
	n_tol_updpkt.tbl_update=1'b0;
	n_tol_updpkt.ATT_UPDATE_ONLY=1'b0;
	n_decomp_freeWay=decomp_freeWay;
	n_decomp_cPage_byteStart=decomp_cPage_byteStart;
	n_alert_out_of_memory=alert_out_of_memory;		
	case(p_state)
		IDLE: begin
			//Put into target operating mode, along with
			//initial values on required variables as
			//needed
			if      (lkup_reqpkt.lookup /*&& !p_trnsl_reqpkt.allow_access*/) begin 
				//For ATT lookup, we need to have attEntryId to
				n_attEntryId=lkup_reqpkt.hppa-(HPPA_BASE_ADDR>>12)+1; //entry id starts from 1
				n_state=LOOKUP_ATT;
			end
		 	else if (compact_req) begin
				n_state=COMPACT;
			end
	
		end
		LOOKUP_ATT:begin
			  if(arready && !arvalid) begin
				     n_axireq = get_axi_rd_pkt(freeLstHead,p_attEntryId,AXI_RD_ATT); //, first arguemnt is not useful, for this state
				     n_req_arvalid = 1'b1;
				     n_state = WAIT_ATT_ENTRY;
			  end 
		end
		WAIT_ATT_ENTRY: begin //we can have multiple beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(rvalid && rlast) begin //rlast is expected as we have only one beat//added assertion for this
				if(rresp =='d0) begin
				     n_rdata= rdata; //get_8byte_byteswap(rdata); //swap back the data, as we had written swapped format to be compatible with ariane. 
				     n_state = DECODE_ATT_ENTRY;
				end
				else n_state = BUS_ERROR;
			  end
		end
		DECODE_ATT_ENTRY:begin
			   n_trnsl_reqpkt=decode_AttEntry(lkup_reqpkt,p_rdata);
			   n_trnsl_reqpkt.zpd_update=1'b0; //remove this later, not checkign zpd on fpga now
			   n_state = CHK_ATT_ENTRY;
		end
	        CHK_ATT_ENTRY: begin 
	        			//ATT 
			   if     (p_trnsl_reqpkt.sts==STS_UNCOMP || p_trnsl_reqpkt.sts==STS_INCOMP) begin //this case though hit still needs att updateif there is zpd_cnt update
					if(p_trnsl_reqpkt.zpd_update) begin
						n_tol_updpkt.attEntryId=p_attEntryId;
						n_tol_updpkt.lstEntry.way=p_trnsl_reqpkt.ppa;//now ATT way if freeway
						n_tol_updpkt.ATT_UPDATE_ONLY=1'b1;
						n_tol_updpkt.ATT_STS=p_trnsl_reqpkt.sts;
						n_tol_updpkt.zpd_cnt=p_trnsl_reqpkt.zpd_cnt;
						n_state = TBL_UPDATE;
					end else begin
						n_state = IDLE; // no change in zpd_cnt : nothing to do 
						n_trnsl_reqpkt.allow_access=1'b1;
					end
			   end
			   else if(p_trnsl_reqpkt.sts==STS_COMP) begin
					n_state = POP_FREE_LST; 
			   end
			   else begin //DALLOC: if it powerup, everything is deallcoated, and if deallocated proactively, it means , freelist has been updated with that ppa.
			  	n_state = POP_FREE_LST; 
			   end
	        end
		POP_FREE_LST: begin 
			  if(freeLstHead!==NULL) begin 
			             n_axireq=get_axi_rd_pkt(freeLstHead,'d0,AXI_RD_TOL);		
				     n_req_arvalid = 1'b1;
				     n_state = WAIT_LST_ENTRY;
			  end
			  else begin
				    if(uncompLstTail!==uncompLstHead) begin //it means I have at-least 2 entries in uncomp list
				    n_state = COMPRESS;
				    end else begin  //handle other cases later, moving to IDLE for now
				    //assert LED
				    n_alert_out_of_memory=1'b1;		
				    n_state = IDLE;
				    end 
			  end
		end
		WAIT_LST_ENTRY: begin //we can have multiple beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(rvalid && rlast) begin //rlast is expected as we have only one beat//added assertion for this
				if(rresp =='d0) begin
				     n_rdata= rdata; //get_8byte_byteswap(rdata); //swap back the data, as we had written swapped format to be compatible with ariane. 
				     n_state = DECODE_LST_ENTRY;
				end
				else n_state = BUS_ERROR;
			  end
		end
		DECODE_LST_ENTRY: begin 
			  //if(rvalid && rlast) begin //rlast is expected as we have only one beat//added assertion for this
				     //n_rdata=rdata; //get_8byte_byteswap(rdata);
				     //decode freeway from freelist from read
				     //data

				     n_tol_updpkt=get_Tolpkt(freeLstHead,p_attEntryId,'d0,p_rdata,TOL_ALLOCATE_PPA); //freelisthead tells, which tol entry we need
					if(lkup_reqpkt.zeroBlkWr) begin
						n_tol_updpkt.zpd_cnt='d1;
					end
				     //If caller of POP_FREE_LST was
				     //decompressor state then go back  
					if(p_trnsl_reqpkt.sts==STS_COMP) begin //if this call because targeted acccess is on compressed page, go to decompress state to expand page on this freeWay
						n_decomp_freeWay=n_tol_updpkt.lstEntry.way<<12;
			   		        n_decomp_cPage_byteStart=p_trnsl_reqpkt.ppa; // attEntry ppa will be where compressed page is stored
						n_state = DECOMPRESS; 
					end
					else begin
				     		n_state = ALLOCATE_PPA;
					end
			  //end
		end

		ALLOCATE_PPA: begin 
					n_trnsl_reqpkt.ppa=tol_updpkt.lstEntry.way<<12;
					n_trnsl_reqpkt.sts=STS_UNCOMP;
				        n_state = TBL_UPDATE;	
		end
		TBL_UPDATE:begin
			   //we can deliver packet to PWM only if it's ready
			   if(pgwr_mngr_ready) begin
				     n_tol_updpkt.tbl_update=1'b1;
				     n_state = TBL_UPDATE_DONE;
			   end
		end
		TBL_UPDATE_DONE:begin
				if(tbl_update_done) begin
					n_trnsl_reqpkt.allow_access=1'b1;
				     	n_state = IDLE;
				end
		end
	  	COMPRESS:begin
				if(cmpresn_done) begin //get the freeway from comp_mnger
					//Am I servicing to make freeway for
					//decompressor or for new Hppa ?
					if(p_trnsl_reqpkt.sts==STS_COMP) begin //my Attenry says compressed, then I am doen servicing for decompressor, so give freeway to it
						n_decomp_freeWay=cmpresn_freeWay<<12;
			   			n_decomp_cPage_byteStart=p_trnsl_reqpkt.ppa>>12; // attEntry ppa will be where compressed page is stored
						n_state = DECOMPRESS; 
					end else begin //I am done serving for new hppa ,so share freeway over translation request 	
						n_trnsl_reqpkt.ppa=cmpresn_freeWay<<12;
						n_trnsl_reqpkt.sts=UNCOMP;
						n_trnsl_reqpkt.allow_access=1'b1;
				     		n_state = IDLE;
					end
				end		
		end
		DECOMPRESS: begin
				if(decomp_mngr_done) begin 
					n_trnsl_reqpkt.ppa=decomp_freeWay; //dcomp done, so this way is expanded with needed page, send it over trnls packet
					n_trnsl_reqpkt.sts=UNCOMP;
				        if(freeLstHead!=NULL) begin //If i just uncompressed compressed page to popped way from free list, i need tol update
					  n_state = TBL_UPDATE;
					end else begin //it must be called from COMPRESS, so it internally updated necessary tol
					  n_state = IDLE;
					  n_trnsl_reqpkt.allow_access=1'b1;
					end
				end
		end
		COMPACT:begin
				if(compact_done) begin
					  n_state = IDLE;
				end
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
		p_attEntryId <= 'd0;		
		p_axireq.addr <= HAWK_ATT_START; 
		p_axireq.arlen <= 8'd0;
		p_req_arvalid <= 1'b0;
		p_rready <= 1'b0;
		p_rdata <='d0;

	        alert_out_of_memory <= 1'b0;
	end
	else begin
 		p_state <= n_state;	
		p_attEntryId <= n_attEntryId;
		
	        alert_out_of_memory <= n_alert_out_of_memory;

		//Axi signals
		p_axireq.addr <= (p_state==COMPRESS) ? n_comp_axireq.addr : 
				 (p_state==DECOMPRESS) ? p_decomp_axireq.addr : 
				 (p_state==COMPACT) ? n_cmpt_axireq.addr : n_axireq.addr;

		p_axireq.arlen <= (p_state==COMPRESS) ? n_comp_axireq.arlen : 
				  (p_state==DECOMPRESS) ? p_decomp_axireq.arlen :
				  (p_state==COMPACT) ? 	n_cmpt_axireq.arlen : 'd0;

		p_req_arvalid <= (p_state==COMPRESS) ? n_comp_req_arvalid :
				 (p_state==DECOMPRESS) ? p_decomp_req_arvalid : 
				 (p_state==COMPACT) ? n_cmpt_req_arvalid : n_req_arvalid;

		p_rready <= (p_state==COMPRESS) ? n_comp_rready : 
			    (p_state==DECOMPRESS) ? n_decomp_rready : 
			    (p_state==COMPACT) ? n_cmpt_rready : n_rready;

		p_rdata <= (p_state==COMPRESS) ? n_comp_rdata :
			   (p_state==DECOMPRESS) ? n_decomp_rdata : 
			   (p_state==COMPACT) ? n_cmpt_rdata : n_rdata;

	end
end

//inputs for decompressor
always@(posedge clk_i or negedge rst_ni) 
begin
 if(!rst_ni) begin
 	decomp_cPage_byteStart <= 'd0;
 	decomp_freeWay <= 'd0;
 end else begin
 	decomp_cPage_byteStart <= n_decomp_cPage_byteStart;
 	decomp_freeWay <= n_decomp_freeWay;
 end
end

//table packets
always @(posedge clk_i or negedge rst_ni)
begin
	if(!rst_ni) begin
		p_trnsl_reqpkt<='d0;
		p_tol_updpkt <='d0;
	end
	else begin
		//Tranalstion Request : It can be att hit or tbl update
		p_trnsl_reqpkt<= n_trnsl_reqpkt; //(p_state==COMPRESS) ? n_comp_trnsl_reqpkt : n_trnsl_reqpkt;
		p_tol_updpkt <=  (p_state==COMPRESS) ? n_comp_tol_updpkt : 
				 (p_state==DECOMPRESS) ? n_decomp_tol_updpkt : 
			         (p_state==COMPACT) ? n_cmpt_tol_updpkt : n_tol_updpkt;
	end
end


//Output combo signals
assign rd_reqpkt.addr = p_axireq.addr;
assign rd_reqpkt.arlen = p_axireq.arlen;
assign rd_reqpkt.arvalid = p_req_arvalid;

assign rd_reqpkt.rready =p_rready;

assign trnsl_reqpkt=p_trnsl_reqpkt;
assign tol_updpkt=p_tol_updpkt;
// just for debug
wire [`HACD_AXI4_ADDR_WIDTH-1:0] ppa;
wire [1:0] sts;
wire debug_allow_access;

assign ppa=trnsl_reqpkt.ppa;
assign sts=trnsl_reqpkt.sts;
assign debug_allow_access=trnsl_reqpkt.allow_access;
//
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


//Compression Manager
hacd_pkg::iWayORcPagePkt_t c_iWayORcPagePkt;
wire cmpresn_trigger;
wire comp_rdm_reset;
logic zeroBlkWr;	 
assign cmpresn_trigger=(p_state==COMPRESS);
assign zeroBlkWr=lkup_reqpkt.zeroBlkWr;
hawk_cmpresn_mngr u_cmpresn_mngr (.*);


hacd_pkg::iWayORcPagePkt_t dc_iWayORcPagePkt;
wire decomp_trigger;
wire decomp_rdm_reset;
assign decomp_trigger=(p_state==DECOMPRESS);

hawk_decomp_mngr u_decomp_mngr (.*);

wire cmpt_rdm_reset;
assign compact_trig = p_state==COMPACT;
hawk_zsp_compacter u_zsp_compacter(.*);

//muxing for FIFO
assign rdm_reset = (p_state==COMPRESS)   ? comp_rdm_reset :
		   (p_state==DECOMPRESS) ? decomp_rdm_reset : 
		   (p_state==COMPACT) ? cmpt_rdm_reset : 1'b0;

//muxing for ZsPg Pkt
assign iWayORcPagePkt = (p_state==COMPRESS)   ? c_iWayORcPagePkt :
			(p_state==DECOMPRESS) ? dc_iWayORcPagePkt : 'd0;


//DEBUG
assign prm_state = p_state;

assign debug_hkpgrd_mngr.alert_oom=alert_out_of_memory;

//`ifdef HAWK_FPGA
//	ila_3 ila_3_hawk_prm (
//		.clk(clk_i),
//		.probe0(trnsl_reqpkt.ppa),
//		.probe1({prm_state,trnsl_reqpkt.allow_access,trnsl_reqpkt.sts,trnsl_reqpkt.zpd_update,trnsl_reqpkt.zpd_cnt})
//	);
//`endif

endmodule
