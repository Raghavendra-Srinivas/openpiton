//Description:
// Supports multiple modes , controlled by hawk control unit
// INIT_ATT and INIT_LIST : Initialize ATT table and make one long free list in list table
//
`include "hacd_define.vh"
import hacd_pkg::*;
`define FSM_WID 5
module hawk_pgwr_mngr #(parameter int PWRUP_UNCOMP=0) (

  input clk_i,
  input rst_ni,

  input wire init_att,
  input wire init_list,  //change this to mode later 

 //FIFO 
    input wire wrfifo_empty,
 
  //AXI packets
  input hacd_pkg::axi_wr_rdypkt_t wr_rdypkt,
  output hacd_pkg::axi_wr_reqpkt_t wr_reqpkt,
  input hacd_pkg::axi_wr_resppkt_t wr_resppkt,

  //to rd manager
  output hacd_pkg::hawk_tol_ht_t tol_HT,

  //handshake with compress manager
  output logic zspg_updated,
  output logic zspg_migrated,
  input hacd_pkg::iWayORcPagePkt_t iWayORcPagePkt,
  input hacd_pkg::zsPageMigratePkt_t zspg_mig_pkt,

  //table update request pgrd_mangr
  input hacd_pkg::tol_updpkt_t tol_updpkt,
  //status handshake to main comntroller
  output logic init_att_done, 
  output logic init_list_done,
  output logic pgwr_mngr_ready,
  output wire tbl_update_done,

  //DEBUG
  output hacd_pkg::debug_pgwr_cmpdcmp_mngr debug_cmpdcmp_mngr,
  output hacd_pkg::debug_pgwr_mngr_t debug_pgwr_mngr, 
  output wire dump_mem  //this is used to help in  DV sims to dump mem when desired during different phase during same sims
);

//list head and tails
logic [clogb2(LST_ENTRY_MAX)-1:0] n_freeListHead,freeListHead;
logic [clogb2(LST_ENTRY_MAX)-1:0] n_freeListTail,freeListTail;
logic [clogb2(LST_ENTRY_MAX)-1:0] n_uncompListHead,uncompListHead;
logic [clogb2(LST_ENTRY_MAX)-1:0] n_uncompListTail,uncompListTail;
logic [clogb2(LST_ENTRY_MAX)-1:0] n_incompListHead,incompListHead;
logic [clogb2(LST_ENTRY_MAX)-1:0] n_incompListTail,incompListTail;
logic [clogb2(LST_ENTRY_MAX)-1:0] n_IfLstHead[IFLST_COUNT],IfLstHead[IFLST_COUNT];
logic [clogb2(LST_ENTRY_MAX)-1:0] n_IfLstTail[IFLST_COUNT],IfLstTail[IFLST_COUNT];

//debug
wire [clogb2(LST_ENTRY_MAX)-1:0] iflst_head,iflst_tail;
assign iflst_head=IfLstHead[0];
assign iflst_tail=IfLstTail[0];
//

wire tbl_update;
wire [clogb2(ATT_ENTRY_MAX)-1:0] attEntryId;
wire [clogb2(LST_ENTRY_MAX)-1:0] tolEntryId;
wire [2:0] src_list; //from which source we are removing this entry
wire [2:0] dst_list; //to which list , we are moving this entry
wire [127:114] rsvd; 
wire [113:64] way;
wire [63:32] prev;
wire [31:0] next;

assign tbl_update=tol_updpkt.tbl_update;
assign attEntryId=tol_updpkt.attEntryId;
assign tolEntryId=tol_updpkt.tolEntryId;
assign src_list=tol_updpkt.src_list;
assign dst_list=tol_updpkt.dst_list;
assign way=tol_updpkt.lstEntry.way;
assign prev=tol_updpkt.lstEntry.prev;
assign next=tol_updpkt.lstEntry.next;

//fsm variables  
logic [clogb2(ATT_ENTRY_MAX):0] p_etry_cnt,n_etry_cnt;  //serves as entry id
logic p_req_awvalid,p_req_wvalid,n_req_awvalid,n_req_wvalid;
logic n_init_att_done,n_init_list_done;
typedef logic [`FSM_WID-1:0] state_t;
state_t n_state;
state_t p_state;
//states
localparam IDLE			     ='d0,
	   INIT_ATT		     ='d1,
	   WAIT_ATT		     ='d2,
	   INIT_LIST		     ='d3,
	   WAIT_LIST		     ='d4,
	   ATT_UPDATE		     ='d5,
	   WAIT_ATT_UPDATE	     ='d6,
	   TOL_SLST_UPDATE	     ='d7,
	   WAIT_TOL_SLST_UPDATE      ='d8,
	   TOL_DLST_UPDATE1	     ='d9,
	   WAIT_TOL_DLST_UPDATE1     ='d10,
	   TOL_DLST_UPDATE2	     ='d11,
	   WAIT_TOL_DLST_UPDATE2     ='d12,
	   CMPDCMP		     ='d13,
	   ZSPG_COMPACT		     ='d14,
	   WAIT_BRESP      	     ='d15,
	   ERROR		     ='d16;


//helper functions
function axi_wr_pld_t get_axi_wr_pkt;
	input [clogb2(ATT_ENTRY_MAX)-1:0] etry_cnt;
	input state_t p_state;
	input [63:0] addr;
	integer i;
	logic [63:0] ppa;

	bit [511:0] data;
	bit [63:0] wstrb;
	//axi_wr_pld_t get_axi_wr_pkt;
        AttEntry att_entry;
	ListEntry lst_entry;
	get_axi_wr_pkt.strb ='d0;
	get_axi_wr_pkt.data ='d0;
	lst_entry.rsvd = 'd0;
	lst_entry.attEntryId='d0;

	ppa='d0;
        if(etry_cnt=='d1) begin
	   ppa = (HAWK_PPA_START>>12);
	end
	else begin	
	   ppa = (HAWK_PPA_START>>12)+ etry_cnt-1; //incremnt by 4KB for ppa
	end
	//optimization, 
	//if we are in Init mode, we can send entire wstrb once, as we know
	//data for entire cache line 
	if      (p_state == INIT_ATT) begin
		   //increment address by 64 (8 entries)
		   if (etry_cnt == 'd1) begin
		   	get_axi_wr_pkt.addr = HAWK_ATT_START; 
		   end
		   else if (etry_cnt[2:0] == 3'b001) begin
		   	get_axi_wr_pkt.addr = addr + 64'd64; 
		   end else begin
		   	get_axi_wr_pkt.addr = addr;
		   end
		   	
		   if (p_etry_cnt <= LIST_ENTRY_CNT && PWRUP_UNCOMP==1) begin
		       att_entry.zpd_cnt='d0;
		       att_entry.sts= STS_UNCOMP;//1'b0;	
		       att_entry.way=ppa;
		   end else begin
		       att_entry.zpd_cnt='d0;
		       att_entry.sts= STS_DALLOC;//1'b0;	
		       att_entry.way='d0;
		   end 
		    
		    i= (etry_cnt[2:0] == 3'b000) ? 'd7: (etry_cnt[2:0]-1);
		    data[(i*ATT_ENTRY_SIZE*BYTE)+:ATT_ENTRY_SIZE*BYTE] = {att_entry.zpd_cnt,att_entry.way,att_entry.sts};
		    wstrb[i*8+:8]={8{1'b1}};
		    
		   //for (i=0;i<(BLK_SIZE/ATT_ENTRY_SIZE);i++) begin
		   // att_entry.way=ppa+i; 
		   // data[(i*ATT_ENTRY_SIZE*BYTE)+:ATT_ENTRY_SIZE*BYTE] = {att_entry.zpd_cnt,att_entry.way,att_entry.sts}; 
	           //end
		   //wstrb = {64{1'b1}};
        end
	else if (p_state == INIT_LIST ) begin
		   if (etry_cnt == 'd1) begin
		   	get_axi_wr_pkt.addr = HAWK_LIST_START;
		   end 
		   else if (etry_cnt[1:0] == 2'b01) begin
		   	get_axi_wr_pkt.addr = addr + 64'd64; 
		   end else begin
		   	get_axi_wr_pkt.addr = addr; 
		   end
		   
		   //lst entry
		    lst_entry.way = ppa; //(ppa>>12) + 1;
		    lst_entry.prev = etry_cnt - 1; //entry_count = 0 is initilizaed to 0 and equivalent to NULL (for first entry)

		    if (etry_cnt == LIST_ENTRY_CNT) begin
		    	lst_entry.next = NULL;
		    end else begin
		    	lst_entry.next = etry_cnt + 1;
		    end

		    if (etry_cnt[1:0] == 2'b01) begin
		    	data[127:0] = {lst_entry.rsvd,lst_entry.way,lst_entry.attEntryId,lst_entry.prev,lst_entry.next}; 
		        wstrb[15:0] ={16{1'b1}};
		    end
		    else if  (etry_cnt[1:0] == 2'b10) begin
		    	data[255:128] = {lst_entry.rsvd,lst_entry.way,lst_entry.attEntryId,lst_entry.prev,lst_entry.next}; 
		        wstrb[31:16] ={16{1'b1}};
		    end	
		    else if  (etry_cnt[1:0] == 2'b11) begin
		    	data[383:256] = {lst_entry.rsvd,lst_entry.way,lst_entry.attEntryId,lst_entry.prev,lst_entry.next}; 
		        wstrb[47:32] ={16{1'b1}};
		    end	
		    else if  (etry_cnt[1:0] == 2'b00) begin
		    	data[511:384] = {lst_entry.rsvd,lst_entry.way,lst_entry.attEntryId,lst_entry.prev,lst_entry.next}; 
		        wstrb[63:48] ={16{1'b1}};
		    end
	end
	//Test byte swap/endianess of riscv core
	//data=511'h0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF;
 	get_axi_wr_pkt.data = data; //get_8byte_byteswap(data); //511'h0123456789ABCDEF;		
	get_axi_wr_pkt.strb = wstrb; //get_strb_swap(wstrb);		
endfunction

`define OPC_WID 3
localparam [`OPC_WID-1:0] NULLIFY='d0,IFL_DETACH='d1,PUSH_HEAD='d2, POP_HEAD='d3, PUSH_TAIL='d4,POP_TAIL='d5;
function axi_wr_pld_t get_tbl_axi_wrpkt;
	input tol_updpkt_t tbl_updat_pkt;
	input state_t p_state;
        input hacd_pkg::hawk_tol_ht_t tol_HT;
	input logic [`OPC_WID-1:0] OPCODE;
	integer i,j;
	bit [511:0] data='d0;
	bit [63:0] wstrb='d0;
        AttEntry att_entry='d0;
	ListEntry next_lst_entry='d0; //for pop
	ListEntry my_lst_entry='d0; //for push
	
	att_entry.way='d0;
	att_entry.sts=STS_DALLOC;
	get_tbl_axi_wrpkt.data='d0;
	get_tbl_axi_wrpkt.strb='d0;
        wstrb[63:0]= {64{1'b0}};
	
	if (p_state==ATT_UPDATE) begin
		get_tbl_axi_wrpkt.addr=HAWK_ATT_START + (((tbl_updat_pkt.attEntryId-1) >> 3) << 6);
		att_entry.zpd_cnt='d0;
		att_entry.way=tbl_updat_pkt.lstEntry.way;  //list way would go into att_entry.way field for allocation
		
	        if(tbl_updat_pkt.ATT_UPDATE_ONLY) begin
			att_entry.sts=tbl_updat_pkt.ATT_STS;
			att_entry.zpd_cnt=tbl_updat_pkt.zpd_cnt;
		end	
		else if(tbl_updat_pkt.src_list == UNCOMP && tbl_updat_pkt.dst_list==UNCOMP) begin //this entry must got compressed and provied freeway
			att_entry.sts=STS_COMP; //zpd_cnt gets default of 0
		end
		else if(tbl_updat_pkt.src_list == FREE && tbl_updat_pkt.dst_list==UNCOMP) begin
			att_entry.sts=STS_UNCOMP;
			att_entry.zpd_cnt=tbl_updat_pkt.zpd_cnt;
		end 
		else if(tbl_updat_pkt.src_list == UNCOMP && tbl_updat_pkt.dst_list==INCOMP) begin
			att_entry.sts=STS_INCOMP; 
		end 
		//handl others: by default I make it do to to COMP as there are too many irregular free lists and so no need to compare
		else begin
			att_entry.sts=STS_COMP; //zpd_cnt gets default of 0
		end
		
		//Which 64 bit we need to send this.
		//case(attEntryId[2:0])
		i=(tbl_updat_pkt.attEntryId[2:0] == 3'b000)?'d7:(tbl_updat_pkt.attEntryId[2:0]-1);
		data[64*i+:64]=att_entry;
		wstrb[8*i+:8]={8{1'b1}};
	end
	else if (p_state==TOL_SLST_UPDATE) begin  //POP FREE LIST , POP entry from head is same as updating prev of next entry to head, then update head to that

		if	(OPCODE == POP_HEAD) begin
			//Original: freehead=Entry-1    -> ||prev=0,Entry=1,next=2||prev=1,Entry=2,next=3||
			//AfterUpdate:freehead->Entry-2 -> ||prev=0,Entry=2,next=3||..
			
			//Change next entries content
			get_tbl_axi_wrpkt.addr=HAWK_LIST_START + (((tbl_updat_pkt.lstEntry.next-1) >> 2) << 6);
	
			//Which entry we shoudl change in cacheline
			i= (tbl_updat_pkt.lstEntry.next[1:0] == 2'b00 ) ? 3 : (tbl_updat_pkt.lstEntry.next[1:0]-1);
			//data[(128*i+32)+:32]=tbl_updat_pkt.lstEntry.prev; //pointers are 32 bits //only prev changes, remaining remains same
			//wstrb[(16*i+4)+:4]={4{1'b1}}; //pointers are 4 bytes
			//attentryid update
			data[(128*i+24)+:24]=tbl_updat_pkt.lstEntry.prev; //pointers are 24 bits //only prev changes, remaining remains same
			wstrb[(16*i+3)+:3]={3{1'b1}}; //pointers are 3 bytes adn attenry of 3 bytes
		end
		else if (OPCODE == POP_TAIL ) begin  //if it is UNCMP , we always do POP_BACK
			get_tbl_axi_wrpkt.addr=HAWK_LIST_START + (((tbl_updat_pkt.lstEntry.prev-1) >> 2) << 6);
			my_lst_entry.next= tbl_updat_pkt.lstEntry.next; ///'d0; //I am pointing to null/tail now, update UNCOMP_TAIL in next cycle	
			i=(tbl_updat_pkt.tolEntryId[1:0]==2'b00)? 3 : (tbl_updat_pkt.tolEntryId[1:0]-1);
			data[128*i+:24]=my_lst_entry.next; 
			wstrb[16*i+:3]={3{1'b1}};
		end
	end
	else if (p_state==TOL_DLST_UPDATE1) begin //PUSH BACK on tail of UNCOMPRESSED LIST
			i=(tbl_updat_pkt.tolEntryId[1:0]==2'b00)? 3 : (tbl_updat_pkt.tolEntryId[1:0]-1);
			data[(128*i+48)+:24]= tbl_updat_pkt.lstEntry.attEntryId; 
		
		if	(OPCODE == NULLIFY) begin //this works even for pop_head of IFL detach
			get_tbl_axi_wrpkt.addr=HAWK_LIST_START + (((tbl_updat_pkt.tolEntryId-1) >> 2) << 6);
			my_lst_entry.prev= NULL;	
			my_lst_entry.next= NULL;	
			//i=(tbl_updat_pkt.tolEntryId[1:0]==2'b00)? 3 : (tbl_updat_pkt.tolEntryId[1:0]-1);
			//data[(128*i+48)+:24]='d0; //tbl_updat_pkt.lstEntry.attEntryId; 
			data[128*i+:48]={my_lst_entry.prev,my_lst_entry.next}; //we update both prev and next for push
			//$display("RAGHAV DEBUG NULLLIFY = prev =%0d, next=%0d",my_lst_entry.prev,my_lst_entry.next); 
			//wstrb[16*i+:9]={9{1'b1}};
		end 
		else if	(OPCODE == PUSH_TAIL) begin
			get_tbl_axi_wrpkt.addr=HAWK_LIST_START + (((tbl_updat_pkt.tolEntryId-1) >> 2) << 6);

			if(tbl_updat_pkt.dst_list==UNCOMP) begin
				my_lst_entry.prev= tol_HT.uncompListTail;
			end else if(tbl_updat_pkt.dst_list==FREE) begin
				my_lst_entry.prev= tol_HT.freeListTail;
			end	//FIXME: else, error for sims
			my_lst_entry.next= NULL; //I am pointing to null/tail now, update UNCOMP_TAIL in next cycle	
			//i=(tbl_updat_pkt.tolEntryId[1:0]==2'b00)? 3 : (tbl_updat_pkt.tolEntryId[1:0]-1);
			//data[(128*i+48)+:24]=tbl_updat_pkt.lstEntry.attEntryId;
			//$display("RAGHAV DEBGU UNCOMP PUSH TAIL - Pushin TAIL = prev =%0d, next=%0d",my_lst_entry.prev,my_lst_entry.next); 
			data[128*i+:48]={my_lst_entry.prev,my_lst_entry.next}; //we update both prev and next for push
			//wstrb[16*i+:9]={9{1'b1}}; //whenver we push to uncomp tail, we record attentryid too
		end
		else if (OPCODE == PUSH_HEAD  ) begin 
			get_tbl_axi_wrpkt.addr=HAWK_LIST_START + (((tbl_updat_pkt.tolEntryId-1) >> 2) << 6);
			my_lst_entry.prev= 'd0;


			if(tbl_updat_pkt.dst_list==INCOMP) begin
				my_lst_entry.next= tol_HT.incompListHead; //I am pointing to head now, update IfLSTHead in next cycle
			end else begin
				j=tbl_updat_pkt.ifl_idx;
				my_lst_entry.next= tol_HT.IfLstHead[j]; //I am pointing to head now, update IfLSTHead in next cycle
			end
	
			//i=(tbl_updat_pkt.tolEntryId[1:0]==2'b00)? 3 : (tbl_updat_pkt.tolEntryId[1:0]-1);
			//data[(128*i+48)+:24]=tbl_updat_pkt.lstEntry.attEntryId; 
			data[128*i+:48]={my_lst_entry.prev,my_lst_entry.next}; //I update next of me to head and prev to null for push front
			$display("RAGHAV DEBGU PUSH HEAD - Pushin HEAD = prev =%0d, next=%0d",my_lst_entry.prev,my_lst_entry.next); 
			//wstrb[16*i+:9]={9{1'b1}};
		end 
			wstrb[16*i+:9]={9{1'b1}};
	end
	else if (p_state==TOL_DLST_UPDATE2) begin 
		
			
		if	(OPCODE == PUSH_TAIL) begin
		 //push_tail : uncompressed and free lits
 
		 if(tbl_updat_pkt.dst_list==UNCOMP) begin
		   get_tbl_axi_wrpkt.addr=HAWK_LIST_START + (((tol_HT.uncompListTail-1) >> 2) << 6);
		   i=(tol_HT.uncompListTail[1:0]==2'b00)? 3 : (tol_HT.uncompListTail[1:0]-1);
		 end else if(tbl_updat_pkt.dst_list==FREE) begin
		   get_tbl_axi_wrpkt.addr=HAWK_LIST_START + (((tol_HT.freeListTail-1) >> 2) << 6);
		   i=(tol_HT.freeListTail[1:0]==2'b00)? 3 : (tol_HT.freeListTail[1:0]-1);
		 end
		 data[128*i+:24]=tbl_updat_pkt.tolEntryId; //we update next of previous entry to me for push back
		 wstrb[16*i+:3]={3{1'b1}};
		end
		else if (OPCODE == PUSH_HEAD  ) begin

		 
		if(tbl_updat_pkt.dst_list==INCOMP) begin
		 get_tbl_axi_wrpkt.addr=HAWK_LIST_START + (((tol_HT.incompListHead-1) >> 2) << 6);
		 i=(tol_HT.incompListHead[1:0]==2'b00)? 3 : (tol_HT.incompListHead[1:0]-1);
		end else begin
		 j=tbl_updat_pkt.ifl_idx;
		 get_tbl_axi_wrpkt.addr=HAWK_LIST_START + (((tol_HT.IfLstHead[j]-1) >> 2) << 6);
		  //$display("RAGHAV_DEBUG: j=%0d, addr=%0h" ,j,get_tbl_axi_wrpkt.addr);
		 i=(tol_HT.IfLstHead[j][1:0]==2'b00)? 3 : (tol_HT.IfLstHead[j][1:0]-1);
		end

		 data[(128*i+24)+:24]=tbl_updat_pkt.tolEntryId; //I update prev of next entry to me
		 wstrb[(16*i+3)+:3]={3{1'b1}}; //pointers are 3 bytes
		end 
	end
 	get_tbl_axi_wrpkt.data = data; //get_8byte_byteswap(data); //511'h0123456789ABCDEF;
	get_tbl_axi_wrpkt.strb = wstrb;//get_strb_swap(wstrb);		
endfunction



//
logic cmpdcmp_done;
logic compact_done;

//From fsm manager point of view, I will unify readiness of addr and data channels, because
//For birngup phase, we always work only hawk_master if both addr and data channels are ready and at cache line granularity always
wire awready,wready;
wire awvalid,wvalid;
logic bresp_cmplt;
assign awready = wr_rdypkt.awready;// & wr_rdypkt.wready;
assign awvalid = wr_reqpkt.awvalid; // & vldpkt.wvalid;

assign wready = wr_rdypkt.wready;// & wr_rdypkt.wready;
assign wvalid = wr_reqpkt.wvalid; // & vldpkt.wvalid;

axi_wr_pld_t p_axireq,n_axireq;
tol_updpkt_t n_tol_updpkt,p_tol_updpkt;
logic [`OPC_WID-1:0] OPC;
logic error;
integer k;
//logic to handle different modes
always@* begin
//default
	n_init_att_done = 1'b0;
	n_init_list_done = 1'b0;		  
	n_etry_cnt = p_etry_cnt; 
	n_state=p_state;	       //be in same state unless fsm decides to jump
	n_axireq= p_axireq;
	n_etry_cnt = p_etry_cnt;         //retain previous
	n_req_awvalid = p_req_awvalid && !awready; //1'b0; 	       //reset->fsm decides when to send packet
	n_req_wvalid = 1'b0; 	       //reset->fsm decides when to send packet

	n_tol_updpkt=p_tol_updpkt;

	//default list head/tails
	n_freeListHead=freeListHead;
	n_freeListTail=freeListTail;
	n_uncompListHead=uncompListHead;
	n_uncompListTail=uncompListTail;
	n_incompListHead=incompListHead;
	n_incompListTail=incompListTail;
	n_IfLstHead=IfLstHead;
	n_IfLstTail=IfLstTail;
	error=1'b0;
	case(p_state)
		IDLE: begin
			//Put into target operating mode, along with
			//initial values on required variables as
			//needed //This handles only one mode at a time.
			if      (init_att & !init_att_done) begin //wait in same state till table initialiation is done
				n_state=INIT_ATT;
				n_axireq.addr = HAWK_ATT_START;  
				n_etry_cnt = 'd1;
			end
			else if (init_list & !init_list_done) begin
				n_state=INIT_LIST;
				n_axireq.addr = HAWK_LIST_START; //We can change this to any address if list tbael does not follow att immediately
				n_etry_cnt = 'd1;
				n_freeListHead = 'd1;
			end
			else if(tol_updpkt.tbl_update) begin
	        		if      (tol_updpkt.TOL_UPDATE_ONLY==1) begin //it used for TOL update only (both on src and dst lists)
			  	     	if (p_tol_updpkt.src_list==IFL_SIZE1) begin
						if (IfLstTail[0] != IfLstHead[0]) begin //FIXME 
							n_state=TOL_SLST_UPDATE;
						end else begin //only one element left in src list.
				     	  		n_IfLstHead[0] = NULL;
				     	  		n_IfLstTail[0] = NULL;
				     	  		n_state = TOL_DLST_UPDATE1;
						end	
					end
				end else if (tol_updpkt.TOL_UPDATE_ONLY==2) begin //it is used for TOL update only but only to add IFL detached entry to dst list
					n_state=TOL_DLST_UPDATE1;
				end else begin
					n_state=ATT_UPDATE;
				end	
			 		n_tol_updpkt=tol_updpkt;
			end
			else if (iWayORcPagePkt.update) begin
				n_state=CMPDCMP;
			end
			else if (zspg_mig_pkt.migrate || zspg_mig_pkt.zspg_update) begin
				n_state=ZSPG_COMPACT;
			end

		end
		INIT_ATT:begin
			  if(/*awready &&*/ !awvalid) begin
				  //handle ATT initialization 
				  if(p_etry_cnt <=(ATT_ENTRY_CNT)) begin //8 becuase 8 entry
				     n_axireq = get_axi_wr_pkt(p_etry_cnt,p_state,p_axireq.addr); //prepare next packet
				     n_req_awvalid = 1'b1;
			  	     n_etry_cnt = p_etry_cnt + 1;
				     //n_state = WAIT_ATT;
				  end
				  else begin
				     n_init_att_done = 1'b1;		  
				     n_state = WAIT_BRESP; //IDLE;
				  end

			  end
			  if(awready && awvalid) begin
				     n_state = WAIT_ATT;
			  end 
		end
		WAIT_ATT: begin 
			  if(wready && !wvalid) begin //data has been already set, in prev state, just assert wvalid
				     n_req_wvalid = 1'b1;
				     n_state = INIT_ATT;
			  end
		end
		INIT_LIST:begin
			  if(/*awready &&*/ !awvalid) begin
				  //handle LIST initialization
				  if (p_etry_cnt <= LIST_ENTRY_CNT) begin
				     n_axireq = get_axi_wr_pkt(p_etry_cnt,p_state,p_axireq.addr); //prepare next packet
				     
				     n_req_awvalid = 1'b1;
			  	     n_etry_cnt = p_etry_cnt + 1;
				     //n_state = WAIT_LIST;
				  end
				  else begin
					n_freeListTail=p_etry_cnt-'d1;
				        n_init_list_done = 1'b1;		  
					n_state = WAIT_BRESP; //IDLE;
				  end
			  end 
			  if(awready && awvalid) begin
				     n_state = WAIT_LIST;
			  end 
		end	
		WAIT_LIST: begin //we can hve multipel beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(wready && !wvalid) begin //data has been already set, in prev state, just assert wvalid
				     n_req_wvalid = 1'b1;
				     n_state = INIT_LIST;
			  end
		end
		ATT_UPDATE : begin
			  if(/*awready &&*/ !awvalid) begin
				     n_axireq = get_tbl_axi_wrpkt(p_tol_updpkt,p_state,tol_HT,'d0); //prepare next packet//lst argument is don't care
				     n_req_awvalid = 1'b1;
				     //n_state = WAIT_ATT_UPDATE;
			  end
			  if(awready && awvalid) begin
				     n_state = WAIT_ATT_UPDATE;
			  end 
		end
		WAIT_ATT_UPDATE: begin
			  if(wready && !wvalid) begin //data has been already set, in prev state, just assert wvalid
				     n_req_wvalid = 1'b1;
				   
				
	        		if(p_tol_updpkt.ATT_UPDATE_ONLY) begin
					n_state=WAIT_BRESP;
 				end else begin
	 
				     //If SRC is free list and is exhausted, then set
				     //freelisthead and tail as null and skip
				     //SRC list Update
			  	     if (p_tol_updpkt.src_list==FREE && ((freeListHead!=freeListTail))) begin // || (freeListTail==NULL))) begin
				     		n_state = TOL_SLST_UPDATE;
				     end
				     else if (p_tol_updpkt.src_list==UNCOMP &&((uncompListHead!=uncompListTail))) begin// || (uncompListHead==NULL))) begin
				     		n_state = TOL_SLST_UPDATE;
			  	     end
			  	     else begin
						if (p_tol_updpkt.src_list==FREE) begin
				     	  		n_freeListHead = NULL;
				     	  		n_freeListTail = NULL;
						end else if (p_tol_updpkt.src_list==UNCOMP) begin
				     	  		n_uncompListHead = NULL;
				     	  		n_uncompListTail = NULL;
						end
				     	  		n_state = TOL_DLST_UPDATE1;
			  	     end
				end
			  end
		end
		TOL_SLST_UPDATE: begin
					case(p_tol_updpkt.src_list)
					 FREE  : OPC=POP_HEAD;
					 UNCOMP: OPC=POP_HEAD;
					 IFL_SIZE1  : OPC=POP_TAIL;
					 default : error=1'b1; 
					endcase
			  if(error) n_state = ERROR;
			  else begin
			  	if(/*awready &&*/ !awvalid) begin
			  	   n_axireq = get_tbl_axi_wrpkt(p_tol_updpkt,p_state,tol_HT,OPC); //prepare next packet
			  	   n_req_awvalid = 1'b1;
			  	   //n_state = WAIT_TOL_SLST_UPDATE;
			  	end
			  	if (awready && awvalid) 
			  	    n_state = WAIT_TOL_SLST_UPDATE;
			  end
			  
		end
		WAIT_TOL_SLST_UPDATE: begin
			  if(wready && !wvalid) begin //data has been already set, in prev state, just assert wvalid
				     //Update SLST HEAD/TAIL
					case(p_tol_updpkt.src_list)
					 FREE  : n_freeListHead=p_tol_updpkt.lstEntry.next; //pop_front->my next will become head 	
					 UNCOMP  : n_uncompListHead=p_tol_updpkt.lstEntry.next; 	
					 IFL_SIZE1: begin
						k=p_tol_updpkt.ifl_idx;
						//n_IfLstHead[k]=p_tol_updpkt.lstEntry.next;
						n_IfLstTail[k]=p_tol_updpkt.lstEntry.prev;
					 end
					 //IFL_DETACH : ; we done' have to
					 //maintain list for fully occupied
					 //zspages ,so nothing to do here
				        endcase 
				     n_req_wvalid = 1'b1;
				     n_state = TOL_DLST_UPDATE1;
			  end
		end
		TOL_DLST_UPDATE1: begin
					case(p_tol_updpkt.dst_list)
					 FREE  : OPC=PUSH_TAIL;
					 UNCOMP    : OPC=PUSH_TAIL;
					 INCOMP : OPC=PUSH_HEAD;
					 IFL_SIZE1 : OPC=PUSH_HEAD;
					 IFL_DETACH  : OPC=NULLIFY; 
					 NULLIFY   : OPC=NULLIFY;
					endcase
				//$display("RAGHAV dst list in DLST_UPDATE1=%0d",p_tol_updpkt.dst_list);
			  if(/*awready &&*/ !awvalid) begin
				     n_axireq = get_tbl_axi_wrpkt(p_tol_updpkt,p_state,tol_HT,OPC); //prepare next packet
				     n_req_awvalid = 1'b1;
				     //n_state = WAIT_TOL_DLST_UPDATE1;
			  end
			  if(awready && awvalid) begin
				     n_state = WAIT_TOL_DLST_UPDATE1;
			  end 
		end
		WAIT_TOL_DLST_UPDATE1: begin
			  if(wready && !wvalid) begin //data has been already set, in prev state, just assert wvalid
						k=p_tol_updpkt.ifl_idx;
				     //Update DLST HEAD/TAIL
					if (p_tol_updpkt.dst_list==FREE && (freeListTail==NULL)) begin 
					   	n_freeListTail=p_tol_updpkt.tolEntryId; //I will become the tail	
					   	n_freeListHead=p_tol_updpkt.tolEntryId; //I will become the head	
				                n_state = WAIT_BRESP;
					end else if (p_tol_updpkt.dst_list==UNCOMP && (uncompListTail==NULL)) begin //for uncomp list as destination, it is push back
					   	n_uncompListTail=p_tol_updpkt.tolEntryId; //I will become the tail	
					   	n_uncompListHead=p_tol_updpkt.tolEntryId; //I will become the head	
				                n_state = WAIT_BRESP;
					end
					else if (p_tol_updpkt.dst_list==IFL_SIZE1 && (IfLstHead[k]==NULL)) begin
					   	 n_IfLstHead[k]=p_tol_updpkt.tolEntryId; //I will become the Head	
					   	 n_IfLstTail[k]=p_tol_updpkt.tolEntryId; //I will become the Tail 
				                 n_state = WAIT_BRESP;
				        end
					else if (p_tol_updpkt.dst_list==INCOMP && (incompListHead==NULL)) begin //for uncomp list as destination, it is push back
					   	n_incompListTail=p_tol_updpkt.tolEntryId; //I will become the tail	
					   	n_incompListHead=p_tol_updpkt.tolEntryId; //I will become the head	
				                n_state = WAIT_BRESP;
					end
					else if (p_tol_updpkt.dst_list==NULLIFY || p_tol_updpkt.dst_list==IFL_DETACH) begin //we don't need second UPDATE for nullify or detach entry
				                 n_state = WAIT_BRESP;
					end
					else begin
				                 n_state = TOL_DLST_UPDATE2;
					end
				     n_req_wvalid = 1'b1;
			  end
		end
		TOL_DLST_UPDATE2: begin
					case(p_tol_updpkt.dst_list)
					 FREE  : OPC=PUSH_TAIL;
					 UNCOMP    : OPC=PUSH_TAIL;
					 INCOMP    : OPC=PUSH_HEAD;
					 IFL_SIZE1 : OPC=PUSH_HEAD;
					 NULLIFY   : OPC=NULLIFY;
					endcase
			  if(/*awready &&*/ !awvalid) begin
				     n_axireq = get_tbl_axi_wrpkt(p_tol_updpkt,p_state,tol_HT,OPC); //prepare next packet
				     n_req_awvalid = 1'b1;
				     //n_state = WAIT_TOL_DLST_UPDATE2;
			  end
			  if(awready && awvalid) begin
				     n_state = WAIT_TOL_DLST_UPDATE2;
			  end 
		end
		WAIT_TOL_DLST_UPDATE2: begin
			  if(wready && !wvalid) begin //data has been already set, in prev state, just assert wvalid
					if(p_tol_updpkt.dst_list==UNCOMP) begin //for uncomp list as destination, it is push back
						n_uncompListTail=p_tol_updpkt.tolEntryId; // I would become tail	
					end
					else if(p_tol_updpkt.dst_list==FREE) begin //for free list as destination, it is push back
						n_freeListTail=p_tol_updpkt.tolEntryId; // I would become tail	
					end
					else if(p_tol_updpkt.dst_list==INCOMP) begin //for incomp list as destination, it is push front/head
						n_incompListHead=p_tol_updpkt.tolEntryId; // I would become head
					end
					else begin //by default we consdier as irregular free list and it si push head for ifl
						k=p_tol_updpkt.ifl_idx;
						n_IfLstHead[k]=p_tol_updpkt.tolEntryId;
					end	
				     n_req_wvalid = 1'b1;
				     n_state = WAIT_BRESP;
			  end
		end
		CMPDCMP:begin
			if(cmpdcmp_done) begin
				n_state=WAIT_BRESP;
			end
		end
		ZSPG_COMPACT:begin
			if(compact_done) begin
				n_state=WAIT_BRESP;
			end
		end
		WAIT_BRESP: begin
			  if(bresp_cmplt) begin 
				     n_state = IDLE;
			  end
		end
		ERROR: begin
			n_state=ERROR;
		end
		default: begin
			n_state=ERROR;
		end
	endcase
end

//FIXME: raghav: I have noticed undesired toggle on tbl_update_done because we
//retain old tbl_update. Actual fix should be in requestor side. For now, just
//gating done update below based on if other type of request are not active
assign tbl_update_done = p_tol_updpkt.tbl_update && (p_state == WAIT_BRESP) && bresp_cmplt && !zspg_updated && !zspg_migrated;
assign zspg_updated = iWayORcPagePkt.update && (p_state == WAIT_BRESP) && bresp_cmplt;
assign zspg_migrated = (zspg_mig_pkt.migrate || zspg_mig_pkt.zspg_update)  && (p_state == WAIT_BRESP) && bresp_cmplt;

hacd_pkg::axi_wr_reqpkt_t int_wr_reqpkt;
//state register/output flops
always @(posedge clk_i or negedge rst_ni)
begin
	if(!rst_ni) begin
		p_state <= IDLE;
		p_etry_cnt <= 'd0;

		//Axi signals
		p_axireq.addr <= HAWK_ATT_START; //'d0;
		p_axireq.data <= 'd0;
		p_axireq.strb <= 'd0;
		//p_axireq.bready<=1'b1;
		p_req_awvalid <= 1'b0;
		p_req_wvalid <= 1'b0;

		//Tabel update
		p_tol_updpkt <='d0;
	end
	else begin
 		p_state <= n_state;	
		p_etry_cnt <= n_etry_cnt;

		//Axi signals
		p_axireq.addr <= (p_state==CMPDCMP || p_state==ZSPG_COMPACT) ? int_wr_reqpkt.addr    : n_axireq.addr;
		p_axireq.data <= (p_state==CMPDCMP || p_state==ZSPG_COMPACT) ? int_wr_reqpkt.data    : n_axireq.data;
		p_axireq.strb <= (p_state==CMPDCMP || p_state==ZSPG_COMPACT) ? int_wr_reqpkt.strb    : n_axireq.strb;
		p_req_awvalid <= (p_state==CMPDCMP || p_state==ZSPG_COMPACT) ? int_wr_reqpkt.awvalid : n_req_awvalid ;
		p_req_wvalid <=  (p_state==CMPDCMP || p_state==ZSPG_COMPACT) ? int_wr_reqpkt.wvalid  : n_req_wvalid;

		//
		//p_axireq.bready<=1'b1;

		p_tol_updpkt<=n_tol_updpkt;
	end
end
assign pgwr_mngr_ready = p_state == IDLE;


assign wr_reqpkt.addr 	 =p_axireq.addr;
assign wr_reqpkt.data 	 =p_axireq.data;
assign wr_reqpkt.strb 	 =p_axireq.strb;
assign wr_reqpkt.awvalid =p_req_awvalid;
assign wr_reqpkt.wvalid  =p_req_wvalid;

//done statuses
//later useful to map it to status register if needed
always @(posedge clk_i or negedge rst_ni) begin
	if(!rst_ni) begin
	  init_att_done <= 1'b0;
	  init_list_done <= 1'b0;
  	end
	else begin 
		if(n_init_att_done) begin
		  init_att_done <= 1'b1;
		end
		if(n_init_list_done) begin
		  init_list_done <= 1'b1;
		end
	end
end




//Write Response are posted : Check
//For now, we support only in-order support: so no need to check ID

logic [6:0] pending_txn_cnt; //max we can have only 64 cache line in pending
logic bus_error; 
always @(posedge clk_i or negedge rst_ni) begin
	if(!rst_ni) begin
		pending_txn_cnt<='d1; //by default pending_txn_cnt is 1; so , we should never get 0, if yes, then tht is unexpected extra resp
		bus_error<=1'b0;
	end
	else begin
		if(wr_reqpkt.awvalid && wr_rdypkt.awready && wr_resppkt.bvalid && (wr_resppkt.bresp=='d0)) begin
			pending_txn_cnt<=pending_txn_cnt;
		end
		else if(wr_reqpkt.awvalid && wr_rdypkt.awready) begin
			pending_txn_cnt<=pending_txn_cnt+1;
		end
		else if(wr_resppkt.bvalid && (wr_resppkt.bresp=='d0)) begin
			pending_txn_cnt<=pending_txn_cnt-1;
		end
		if((wr_resppkt.bvalid && (wr_resppkt.bresp!='d0)) || (pending_txn_cnt=='d0))
		    bus_error<=1'b1;
	end
end
assign bresp_cmplt=pending_txn_cnt=='d1;

/*
logic [6:0] req_count0,resp_count0;
logic bus_error; 
always @(posedge clk_i or negedge rst_ni) begin
	if(!rst_ni) begin
		req_count0 <= 'd0;
		resp_count0 <= 'd0;
		bus_error<=1'b0;
	end
	else if(p_state==IDLE)begin
		req_count0 <= 'd0;
		resp_count0 <= 'd0;
		bus_error<=bus_error;
	end
	else begin
		if(wr_resppkt.bvalid && wr_resppkt.bresp!='d0) begin
		    bus_error<=1'b1;
		end
		if(wr_reqpkt.awvalid && wr_rdypkt.awready) begin
			req_count0<=req_count0+1;
		end
		if(wr_resppkt.bvalid && (wr_resppkt.bresp=='d0)) begin
			resp_count0<=resp_count0+1;
	 	end	
	end
end
assign bresp_cmplt=(req_count0==resp_count0) && req_count0!=0;
*/

//ToL Head and Tails //move to separate module if required

always @(posedge clk_i or negedge rst_ni) begin
	if(!rst_ni) begin
		freeListHead<='d0; //0 corresponds for NULL
		freeListTail<='d0; 
		uncompListHead<='d0; 
		uncompListTail<='d0;
		incompListHead<='d0; 
		incompListTail<='d0;
	end else begin
		freeListHead<=n_freeListHead;
		freeListTail<=n_freeListTail; 
		uncompListHead<=n_uncompListHead; 
		uncompListTail<=n_uncompListTail;
		incompListHead<=n_incompListHead; 
		incompListTail<=n_incompListTail;
	end
end
genvar if_h;
generate 
for(if_h=0;if_h<IFLST_COUNT;if_h=if_h+1) begin :IFL_HEADTAIL
	always @(posedge clk_i or negedge rst_ni)
	begin
		if(!rst_ni) begin
			IfLstHead[if_h]<=NULL;
			IfLstTail[if_h]<=NULL;
		end
		else begin
			IfLstHead[if_h]<=n_IfLstHead[if_h];
			IfLstTail[if_h]<=n_IfLstTail[if_h];
		end
	end
assign tol_HT.IfLstHead[if_h]=IfLstHead[if_h];
assign tol_HT.IfLstTail[if_h]=IfLstTail[if_h];
end : IFL_HEADTAIL
endgenerate

//share with pgrd manager
assign tol_HT.freeListHead=freeListHead;
assign tol_HT.freeListTail=freeListTail;
assign tol_HT.uncompListHead=uncompListHead;
assign tol_HT.uncompListTail=uncompListTail;
assign tol_HT.incompListHead=incompListHead;
assign tol_HT.incompListTail=incompListTail;


//For DV
assign dump_mem = pgwr_mngr_ready;  //dump memory after operation is complete , dump mem is sensitive to only edge, we can give level signal
//
logic cmpdcmp_trigger;
wire zspg_migrate;
assign cmpdcmp_trigger = p_state == CMPDCMP;
assign zspg_migrate = p_state == ZSPG_COMPACT;
hawk_cmpdcmp_wr_mngr u_hawk_cmpdcmp_wr_mngr(.*);


//DEBUG
/*
`ifdef HAWK_FPGA
	ila_3 ila_3_hawk_pwm (
		.clk(clk_i),
		.probe0({tol_updpkt.attEntryId,tol_updpkt.tolEntryId}),
		.probe1({pwm_state,init_att,init_list,init_att_done,init_list_done,p_etry_cnt,tol_updpkt.tbl_update,iWayORcPagePkt.update})
	);
`endif
*/

//current depth of each linked list
logic [clogb2(ATT_ENTRY_MAX):0] freeLstDpth,ucompLstDpth,ifSz1LstDpth,incompLstDpth; 
always @(posedge clk_i or negedge rst_ni) begin
	if(!rst_ni) begin
		freeLstDpth<='d0;
		ucompLstDpth<='d0;
		ifSz1LstDpth<='d0;
		incompLstDpth<='d0;
	
	end
	else if (init_att_done && !init_list_done) begin
		freeLstDpth<=p_etry_cnt-1; 
		ucompLstDpth<='d0;
		ifSz1LstDpth<='d0;
		incompLstDpth<='d0;
	end
	else if(tbl_update_done && !p_tol_updpkt.ATT_UPDATE_ONLY && |(p_tol_updpkt.src_list^p_tol_updpkt.dst_list)) begin

		if(p_tol_updpkt.src_list==FREE && tol_updpkt.TOL_UPDATE_ONLY!=2)
			freeLstDpth<=freeLstDpth-{{clogb2(ATT_ENTRY_MAX){1'b0}},1};
		else if (p_tol_updpkt.dst_list==FREE)
			freeLstDpth<=freeLstDpth+{{clogb2(ATT_ENTRY_MAX){1'b0}},1};
		if(p_tol_updpkt.src_list==UNCOMP && tol_updpkt.TOL_UPDATE_ONLY!=2)
			ucompLstDpth<=ucompLstDpth-{{clogb2(ATT_ENTRY_MAX){1'b0}},1};
		else if(p_tol_updpkt.dst_list==UNCOMP)
			ucompLstDpth<=ucompLstDpth+{{clogb2(ATT_ENTRY_MAX){1'b0}},1};
		if(p_tol_updpkt.src_list==IFL_SIZE1 && tol_updpkt.TOL_UPDATE_ONLY!=2)
			ifSz1LstDpth<=ifSz1LstDpth-{{clogb2(ATT_ENTRY_MAX){1'b0}},1};
		else if(p_tol_updpkt.dst_list==IFL_SIZE1)
			ifSz1LstDpth<=ifSz1LstDpth+{{clogb2(ATT_ENTRY_MAX){1'b0}},1};
		if(p_tol_updpkt.src_list==INCOMP && tol_updpkt.TOL_UPDATE_ONLY!=2)
			incompLstDpth<=incompLstDpth-{{clogb2(ATT_ENTRY_MAX){1'b0}},1};
		else if(p_tol_updpkt.dst_list==INCOMP)
			incompLstDpth<=incompLstDpth+{{clogb2(ATT_ENTRY_MAX){1'b0}},1};
	end
end

assign debug_pgwr_mngr.freeLstDpth=freeLstDpth;
assign debug_pgwr_mngr.ucompLstDpth=ucompLstDpth;
assign debug_pgwr_mngr.ifSz1LstDpth=ifSz1LstDpth;
assign debug_pgwr_mngr.incompLstDpth=incompLstDpth;
assign debug_pgwr_mngr.pwm_state = p_state;

endmodule
