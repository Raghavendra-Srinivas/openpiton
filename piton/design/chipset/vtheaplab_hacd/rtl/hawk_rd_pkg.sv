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


//ZSpage Identity Way
typedef struct packed {
	bit [7:0] size; //1byte
	bit [47:0] way1;//6 byte
	bit way_vld;
	bit [47:0] page0;//6 byte
	bit [47:0] page1;//6 byte
	bit [1:0] pg_vld;
} ZsPg_Md_t;

typedef packed struct{
	bit iWayORcPage; //packet type
	//where to write
	logic [47:0] iWay_start;
	//content
	ZsPg_Md_t zsPgMd;
	logic [47:0] iWay_ptr; //4KB aligned address
	logic [47:0] nxtWay_ptr; //4KB aligned address
	//page start-where to write compressed page
	logic [47:0] cPage_byteStart; // if (iWayORcPage==0) = > Byte address = iWay_start+ $size(zsPgMd)+3*(6bytes) else 
	logic [13:0] cpage_size;
} wr_iWayORcPagePkt_t;


endpackage
