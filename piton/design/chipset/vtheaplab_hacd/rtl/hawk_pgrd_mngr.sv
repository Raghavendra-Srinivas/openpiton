//Description:
// Supports multiple modes , controlled by hawk control unit
//
`include "hacd_define.vh"
import hacd_pkg::*;
`define FSM_WID 4
module hawk_pgrd_mngr (

  input clk_i,
  input rst_ni,

  input lookup_att,
  //AXI packets
  input hacd_pkg::axi_rd_rdypkt_t rd_rdypkt,
  output hacd_pkg::axi_rd_reqpkt_t rd_reqpkt,

  output lookup_att_done;
);

//fsm variables  
logic p_req_arvalid,n_req_arvalid;
typedef logic [`FSM_WID-1:0] state_t;
state_t n_state;
state_t p_state;
//states
localparam IDLE		='d0,
	   LOOKUP_ATT	='d1,
	   POP_FREE_LST ='d2;


//helper functions
function axi_rd_pld_t get_axi_rd_pkt;
	input [clogb2(ATT_ENTRY_MAX)-1:0] etry_cnt;
	input state_t p_state;
	input [63:0] addr;
	input [47:0] ppa; //if applicable , useful for LISt initiliazation
	integer i;
	//axi_rd_pld_t get_axi_rd_pkt;
        AttEntry att_entry;
	ListEntry lst_entry;
	get_axi_rd_pkt.strb ='d0;
	get_axi_rd_pkt.data ='d0;
	lst_entry.rsvd = 'd0;

	//optimization, 
	//if we are in Init mode, we can send entire wstrb once, as we know
	//data for entire cache line 
	if      (p_state == INIT_ATT) begin
		   //increment address by 64 (8 entries)
		   get_axi_rd_pkt.addr = addr + 64'd64; //;get_att_addr()
		   att_entry.zpd_cnt='d0;
		   att_entry.way='d0;
		   att_entry.sts=1'b0;	
		   for (i=0;i<(BLK_SIZE/ATT_ENTRY_SIZE);i++) begin
		    get_axi_rd_pkt.data[(i*ATT_ENTRY_SIZE*BYTE)+:ATT_ENTRY_SIZE*BYTE] = {att_entry.zpd_cnt,att_entry.way,att_entry.sts}; 
	           end
		   get_axi_rd_pkt.strb = {64{1'b1}};
        end
	else if (p_state == INIT_LIST ) begin
		   if (etry_cnt[1:0] == 2'b01) begin
		   	get_axi_rd_pkt.addr = addr + 64'd64; //;get_att_addr()
		   end else begin
		   	get_axi_rd_pkt.addr = addr; //;get_att_addr()
		   end
		   
		   //lst entry
		    lst_entry.way = ppa + 1; //this actually is 4KB aligned, so we incremnt sequentially here
		    lst_entry.prev = etry_cnt - 1; //entry_count = 0 is initilizaed to 0 and equivalent to NULL
		    lst_entry.next = etry_cnt + 1;
		    if (etry_cnt[1:0] == 2'b01) begin
		    	get_axi_rd_pkt.data[127:0] = {lst_entry.rsvd,lst_entry.way,lst_entry.prev,lst_entry.next}; 
		        get_axi_rd_pkt.strb[15:0] ={16{1'b1}};
		    end
		    else if  (etry_cnt[1:0] == 2'b10) begin
		    	get_axi_rd_pkt.data[255:128] = {lst_entry.rsvd,lst_entry.way,lst_entry.prev,lst_entry.next}; 
		        get_axi_rd_pkt.strb[31:16] ={16{1'b1}};
		    end	
		    else if  (etry_cnt[1:0] == 2'b11) begin
		    	get_axi_rd_pkt.data[383:256] = {lst_entry.rsvd,lst_entry.way,lst_entry.prev,lst_entry.next}; 
		        get_axi_rd_pkt.strb[47:32] ={16{1'b1}};
		    end	
		    else if  (etry_cnt[1:0] == 2'b00) begin
		    	get_axi_rd_pkt.data[511:384] = {lst_entry.rsvd,lst_entry.way,lst_entry.prev,lst_entry.next}; 
		        get_axi_rd_pkt.strb[63:48] ={16{1'b1}};
		    end	

		    get_axi_rd_pkt.ppa = ppa + 1;
	end
endfunction


wire arready,rready;
wire arvalid,rvalid;
assign arready = rd_rdypkt.arready; 

assign rready = rd_rdypkt.rready;
assign rvalid = rd_resppkt.rvalid;
assign rdata = rd_resppkt.rdata;

//axi_rd_pld_t p_axireq,n_axireq;

//logic to handle different modes
always_comb begin
//default
	n_state=p_state;	       //be in same state unless fsm decides to jump
	n_axireq= p_axireq;
	n_req_arvalid = 1'b0; 	       //reset->fsm decides when to send packet

	case(p_state)
		IDLE: begin
			//Put into target operating mode, along with
			//initial values on required variables as
			//needed
			if      (lookup_att & !lookup_att_done) begin //wait in same state till table initialiation is done
				n_state=LOOUP_ATT;
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
				     n_resp_rdata = rdata;
				     n_state = CHECK_ATT_ENTRY;
			  end
		end
		CHECK_ATT_ENTRY:begin
			  if(att_hit) begin
			  	//unhold cpu access (wr/rd)
			  end
			  else begin
				//lookup freelist
				n_state = POP_FREE_LIST;
			  end
				
		end	
		FREE_LIST: begin 
			  if() begin 
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
		p_req_arvalid <= 1'b0;
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
		p_req_arvalid <= n_req_arvalid ;
		p_req_wvalid <= n_req_wvalid;
	end
end

//done statuses
//later useful to map it to status register if needed
always @(posedge clk_i or negedge rst_ni)
	if(!rst_ni) begin
	  lookup_att_done <= 1'b0;
  	end
	else begin 
	if(n_lookup_att_done)
	  lookup_att_done <= 1'b1;
	end

//Output combo signals
assign rd_reqpkt.addr = p_axireq.addr;
assign rd_reqpkt.data = p_axireq.data;
assign rd_reqpkt.strb = p_axireq.strb;
assign rd_reqpkt.arvalid = p_req_arvalid;
assign rd_reqpkt.wvalid =  p_req_wvalid;



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
