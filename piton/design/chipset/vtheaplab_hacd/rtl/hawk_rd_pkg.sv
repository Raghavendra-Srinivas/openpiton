package hawk_rd_pkg;
import hacd_pkg::*;
    `include "hacd_define.vh"
typedef enum {AXI_RD_ATT,AXI_RD_TOL} AXI_RD_TYPE;
//FUnctions shared by hawkpg_rd_manger and hawk_cmpresn_mngr// They closely
//work together, so I have added themn in common hawk package , instead of separate packages just for both of them
//helper functions
function axi_rd_pld_t get_axi_rd_pkt;
	input [clogb2(LST_ENTRY_MAX)-1:0] lstEntryId;
	input [clogb2(ATT_ENTRY_MAX)-1:0] attEntryId;
	input AXI_RD_TYPE p_state;
	integer i;
        AttEntry att_entry;
	ListEntry lst_entry;

	if      (p_state == AXI_RD_ATT) begin
		   //(hppa-HPPA_BASE_ADDR) isn ATT entry ID
		   //It is hppa adderss minus hppa_base gives AttEntryID. divide by (>>3) as 8 entries can fit in one cache,
		   //we get incremnt of 1 for every 8 incrments of hppa.
		   //and we need to multiply that quantity by 64(<<6) (as cacheline
		   //size is 64bytes
		 get_axi_rd_pkt.addr = HAWK_ATT_START + (((attEntryId-1) >> 3) << 6);//map hppa to att cache line address
        end
	else if (p_state == AXI_RD_TOL) begin
		 //generate address which does pop from free list referenced
		 //from free list head
		 get_axi_rd_pkt.addr = HAWK_LIST_START + (((lstEntryId-1) >> 2) << 6);
	end
	//handle other modes later
endfunction

//function  decode_AttEntry
function trnsl_reqpkt_t decode_AttEntry;
	input logic [`HACD_AXI4_ADDR_WIDTH-1:12] hppa;
	input logic [`HACD_AXI4_DATA_WIDTH-1:0] rdata;
		integer i;
        	AttEntry att_entry;
		//defaults
        	decode_AttEntry.ppa ='d0;
 		decode_AttEntry.sts ='d0;
 		decode_AttEntry.allow_access =1'b0;
        	//decode
		i=hppa[14:12];
		att_entry=rdata[64*i+:64];
		decode_AttEntry.ppa=att_entry.way;
		decode_AttEntry.sts=att_entry.sts;
endfunction 

//function  decode_AttEntry
function ListEntry decode_LstEntry;
	input [clogb2(LST_ENTRY_MAX)-1:0] lstEntryId;
	input logic [`HACD_AXI4_DATA_WIDTH-1:0] rdata;
		integer i;
        	ListEntry lst_entry;
		//defaults
        	decode_LstEntry.way ='d0;
 		decode_LstEntry.prev ='d0;
 		decode_LstEntry.next =1'b0;
        	//decode
		i= (lstEntryId[2:0] == 3'b000) ? 'd7: (lstEntryId[2:0]-1);
		lst_entry=rdata[128*i+:128];
        	decode_LstEntry.way = lst_entry.way;
 		decode_LstEntry.prev = lst_entry.prev;
 		decode_LstEntry.next = lst_entry.next;
endfunction


typedef enum {TOL_ALLOCATE_PPA,TOL_COMPRESS} TOL_UPDATE_TYPE;

function tol_updpkt_t get_Tolpkt;
	input [clogb2(LST_ENTRY_MAX)-1:0] lstEntryId;
	input [clogb2(ATT_ENTRY_MAX)-1:0] attEntryId;
 	input logic [`HACD_AXI4_DATA_WIDTH-1:0] rdata;
	input TOL_UPDATE_TYPE p_state;
	ListEntry list_entry;

	if(p_state == TOL_ALLOCATE_PPA) begin 
		//allocate_ppa: we have picked entry from freelist and moving it to uncompressed list
		 get_Tolpkt.attEntryId=attEntryId;
		 get_Tolpkt.tolEntryId=lstEntryId;
		 get_Tolpkt.src_list=FREE;
		 get_Tolpkt.dst_list=UNCOMP;
		 //one block contains 4 lsit entries, we need to pcik the one
		 //pointed by freeLstHead
		 case(lstEntryId[1:0])
			2'b01:	list_entry = rdata[127:0];
			2'b10:	list_entry = rdata[255:128];
			2'b11:	list_entry = rdata[383:256];
			2'b00:	list_entry = rdata[511:384];
		 endcase
		 get_Tolpkt.lstEntry=list_entry;
	
	end
	//handle other table update later

endfunction
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

function logic [13:0] get_cpage_size;
	input [7:0] idx;
	get_cpage_size=suprted_comp_size[idx];
endfunction

function iWayORcPagePkt_t decode_ZsPageiWay;
	input logic [`HACD_AXI4_DATA_WIDTH-1:0] rdata;
	iWayORcPagePkt_t pkt;
	ZsPg_Md_t md;
	logic [47:0] iway_ptr,nxtway_ptr;
	logic [13:0] cpage_size;

	iway_ptr=rdata[(50*8)+48+48-1:(50*8)+48];
	nxtway_ptr=rdata[(50*8)+48-1:(50*8)];
	md=rdata[(50*8)-1 : 0]; //50 bytes on LSB 

	//size
	cpage_size=suprted_comp_size[md.size];
	
	//cpage byte start
	if(md.way_vld[0]) begin
		if          (!md.pg_vld[0]) begin
				pkt.cPage_byteStart=iway_ptr+62; //first page
				md.page0=iway_ptr+62;
			//chk for 4KB crossover
		end else if (!md.pg_vld[1]) begin
				if (md.page0+cpage_size<4096) begin
					pkt.cPage_byteStart=md.page0+cpage_size;
					md.page1=md.page0+cpage_size;
				end //not handling other cases for now 
				//nxtway_ptr has to be valid in below case
		end
	end //not handling other ways for now


        //cpage size
	pkt.cpage_size=cpage_size;

	
	pkt.update=1'b0;
	pkt.iWay_ptr=iway_ptr;
	pkt.nxtWay_ptr=nxtway_ptr;
	pkt.zsPgMd=md;

endfunction

endpackage
