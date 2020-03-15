//Description:
// Supports multiple modes , controlled by hawk control unit
// INIT_ATT and INIT_LIST : Initialize ATT table and make one long free list in list table
//
`include "hacd_define.vh"
import hacd_pkg::*;
`define FSM_WID 4
module hawk_pgwr_mngr (

  input clk_i,
  input rst_ni,

  input wire init_att,
  input wire init_list,  //change this to mode later 

  //AXI packets
  input hacd_pkg::axi_wr_rdypkt_t wr_rdypkt,
  output hacd_pkg::axi_wr_reqpkt_t wr_reqpkt,

  //AXI Signals
  //output logic wr_blk_vld,
  //output logic [`HACD_AXI4_DATA_WIDTH-1:0] wr_blk_data;
  //output logic wr_blk_addr_vld,
  //output logic [63:0] wr_blk_adrr,

  //status handshake to main comntroller
  output logic init_att_done, 
  output logic init_list_done 
);

//fsm variables  
logic [clogb2(ATT_ENTRY_MAX):0] p_etry_cnt,n_etry_cnt;  //serves as entry id
logic p_req_awvalid,p_req_wvalid,n_req_awvalid,n_req_wvalid;
logic n_init_att_done,n_init_list_done;
typedef logic [`FSM_WID-1:0] state_t;
state_t n_state;
state_t p_state;
//states
localparam IDLE		='d0,
	   INIT_ATT	='d1,
	   WAIT_ATT	='d2,
	   INIT_LIST	='d3,
	   WAIT_LIST	='d4;


//helper functions
function axi_wr_pld_t get_axi_wr_pkt;
	input [clogb2(ATT_ENTRY_MAX)-1:0] etry_cnt;
	input state_t p_state;
	input [63:0] addr;
	input [47:0] ppa; //if applicable , useful for LISt initiliazation
	integer i;
	//axi_wr_pld_t get_axi_wr_pkt;
        AttEntry att_entry;
	ListEntry lst_entry;
	get_axi_wr_pkt.strb ='d0;
	get_axi_wr_pkt.data ='d0;
	lst_entry.rsvd = 'd0;

	//optimization, 
	//if we are in Init mode, we can send entire wstrb once, as we know
	//data for entire cache line 
	if      (p_state == INIT_ATT) begin
		   //increment address by 64 (8 entries)
		   get_axi_wr_pkt.addr = addr + 64'd64; //;get_att_addr()
		   for (i=0;i<(BLK_SIZE/ATT_ENTRY_SIZE);i++) begin
		    get_axi_wr_pkt.data[(i*ATT_ENTRY_SIZE*BYTE)+:ATT_ENTRY_SIZE*BYTE] = {att_entry.zpd_cnt,att_entry.way,att_entry.sts}; 
	           end
		   get_axi_wr_pkt.strb = {64{1'b1}};
        end
	else if (p_state == INIT_LIST ) begin
		   if (etry_cnt[1:0] == 2'b01) begin
		   	get_axi_wr_pkt.addr = addr + 64'd64; //;get_att_addr()
		   end else begin
		   	get_axi_wr_pkt.addr = addr; //;get_att_addr()
		   end
		   
		   //lst entry
		    lst_entry.way = ppa + 1; //this actually is 4KB aligned, so we incremnt sequentially here
		    lst_entry.prev = etry_cnt - 1; //entry_count = 0 is initilizaed to 0 and equivalent to NULL
		    lst_entry.next = etry_cnt + 1;
		    if (etry_cnt[1:0] == 2'b01) begin
		    	get_axi_wr_pkt.data[127:0] = {lst_entry.rsvd,lst_entry.way,lst_entry.prev,lst_entry.next}; 
		        get_axi_wr_pkt.strb[15:0] ={16{1'b1}};
		    end
		    else if  (etry_cnt[1:0] == 2'b10) begin
		    	get_axi_wr_pkt.data[255:128] = {lst_entry.rsvd,lst_entry.way,lst_entry.prev,lst_entry.next}; 
		        get_axi_wr_pkt.strb[31:16] ={16{1'b1}};
		    end	
		    else if  (etry_cnt[1:0] == 2'b11) begin
		    	get_axi_wr_pkt.data[383:256] = {lst_entry.rsvd,lst_entry.way,lst_entry.prev,lst_entry.next}; 
		        get_axi_wr_pkt.strb[47:32] ={16{1'b1}};
		    end	
		    else if  (etry_cnt[1:0] == 2'b00) begin
		    	get_axi_wr_pkt.data[511:384] = {lst_entry.rsvd,lst_entry.way,lst_entry.prev,lst_entry.next}; 
		        get_axi_wr_pkt.strb[63:48] ={16{1'b1}};
		    end	

		    get_axi_wr_pkt.ppa = ppa + 1;
	end
endfunction


//From fsm manager point of view, I will unify readiness of addr and data channels, because
//For birngup phase, we always work only hawk_master if both addr and data channels are ready and at cache line granularity always
wire awready,wready;
wire awvalid,wvalid;
assign awready = wr_rdypkt.awready;// & wr_rdypkt.wready;
assign awvalid = wr_reqpkt.awvalid; // & vldpkt.wvalid;

assign wready = wr_rdypkt.wready;// & wr_rdypkt.wready;
assign wvalid = wr_reqpkt.wvalid; // & vldpkt.wvalid;

axi_wr_pld_t p_axireq,n_axireq;

//logic to handle different modes
always_comb begin
//default
	n_init_att_done = 1'b0;
	n_etry_cnt = p_etry_cnt; 
	n_state=p_state;	       //be in same state unless fsm decides to jump
	n_axireq= p_axireq;
	n_etry_cnt = p_etry_cnt;         //retain previous
	n_req_awvalid = 1'b0; 	       //reset->fsm decides when to send packet
	n_req_wvalid = 1'b0; 	       //reset->fsm decides when to send packet

	case(p_state)
		IDLE: begin
			//Put into target operating mode, along with
			//initial values on required variables as
			//needed
			if      (init_att & !init_att_done) begin //wait in same state till table initialiation is done
				n_state=INIT_ATT;
				n_etry_cnt = 'd0;
			end
			else if (init_list & !init_list_done) begin
				n_state=INIT_LIST;
				n_axireq.ppa=HAWK_PPA_START;
				n_axireq.addr = HAWK_LIST_START; //We can change this to any address if list tbael does not follow att immediately
				n_etry_cnt = 'd1;
			end
			//handle other modes below

		end
		INIT_ATT:begin
			  if(awready && !awvalid) begin
				  //handle ATT initialization 
				  if(p_etry_cnt < (ATT_ENTRY_CNT/ATT_ENTRY_PER_BLK)) begin //8 becuase 8 entry
				     n_axireq = get_axi_wr_pkt(p_etry_cnt,p_state,p_axireq.addr,p_axireq.ppa); //prepare next packet
				     n_req_awvalid = 1'b1;
			  	     n_etry_cnt = p_etry_cnt + 1;
				     n_state = WAIT_ATT;
				  end
				  else begin
				     n_init_att_done = 1'b1;		  
				     n_state = IDLE;
				  end

			  end 
		end
		WAIT_ATT: begin //we can hve multipel beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(wready && !wvalid) begin //data has been already set, in prev state, just assert wvalid
				     n_req_wvalid = 1'b1;
				     n_state = INIT_ATT;
			  end
		end
		INIT_LIST:begin
			  if(awready && !awvalid) begin
				  //handle LIST initialization
				  if (p_etry_cnt <= LIST_ENTRY_CNT) begin
				     n_axireq = get_axi_wr_pkt(p_etry_cnt,p_state,p_axireq.addr,p_axireq.ppa); //prepare next packet
				     
				     n_req_awvalid = 1'b1;
			  	     n_etry_cnt = p_etry_cnt + 1;
				     n_state = WAIT_LIST;
				  end
				  else begin
				        n_init_list_done = 1'b1;		  
					n_state = IDLE;
				  end
			  end 
		end	
		WAIT_LIST: begin //we can hve multipel beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(wready && !wvalid) begin //data has been already set, in prev state, just assert wvalid
				     n_req_wvalid = 1'b1;
				     n_state = INIT_LIST;
			  end
		end
	endcase
end


//state register/output flops
always @(posedge clk_i or negedge rst_ni)
begin
	if(!rst_ni) begin
		p_state <= IDLE;
		p_etry_cnt <= 'd0;
		p_axireq.ppa <= HAWK_PPA_START;

		//Axi signals
		p_axireq.addr <= HAWK_ATT_START; //'d0;
		p_axireq.data <= 'd0;
		p_axireq.strb <= 'd0;
		p_req_awvalid <= 1'b0;
		p_req_wvalid <= 1'b0;
	end
	else begin
 		p_state <= n_state;	
		p_etry_cnt <= n_etry_cnt;
		p_axireq.ppa <= n_axireq.ppa;

		//Axi signals
		p_axireq.addr <= n_axireq.addr;
		p_axireq.data <= n_axireq.data;
		p_axireq.strb <= n_axireq.strb;
		p_req_awvalid <= n_req_awvalid ;
		p_req_wvalid <= n_req_wvalid;
	end
end

//done statuses
//later useful to map it to status register if needed
always @(posedge clk_i or negedge rst_ni)
	if(!rst_ni) begin
	  init_att_done <= 1'b0;
	  init_list_done <= 1'b0;
  	end
	else begin 
	if(n_init_att_done)
	  init_att_done <= 1'b1;
	if(n_init_list_done)
	  init_list_done <= 1'b1;
	end

//Output combo signals
assign wr_reqpkt.addr = p_axireq.addr;
assign wr_reqpkt.data = p_axireq.data;
assign wr_reqpkt.strb = p_axireq.strb;
assign wr_reqpkt.awvalid = p_req_awvalid;
assign wr_reqpkt.wvalid =  p_req_wvalid;



//generic helper functions
function integer clogb2;
    input [31:0] value;
    begin
        value = value - 1;
        for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1) begin
            value = value >> 1;
        end
    end
endfunction

endmodule
