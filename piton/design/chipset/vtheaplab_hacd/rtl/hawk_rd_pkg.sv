package hawk_rd_pkg;
import hacd_pkg::*;
    `include "hacd_define.vh"
typedef enum {AXI_RD_ATT,AXI_RD_TOL} AXI_RD_TYPE;
//FUnctions shared by hawkpg_rd_manger and hawk_cmpresn_mngr// They closely
//work together, so I have added themn in common hawk package , instead of separate packages just for both of them
//helper functions
function automatic axi_rd_pld_t get_axi_rd_pkt;
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
		get_axi_rd_pkt.arlen=8'd0;
	//handle other modes later
endfunction

//function  decode_AttEntry
function automatic trnsl_reqpkt_t decode_AttEntry;
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
function automatic ListEntry decode_LstEntry;
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

function automatic tol_updpkt_t get_Tolpkt;
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
localparam logic [13:0] suprted_comp_size[IFLST_COUNT]={14'd64}; //supportable compressed sizes in bytes, just one for now
function automatic logic [7:0] get_idx;
	input logic [13:0] size;
	integer i; 
	for(i=0;i<IFLST_COUNT;i=i+1) begin
		if(suprted_comp_size[i]==size) begin
			get_idx=i;	
		end
	end
endfunction

function automatic logic [13:0] get_cpage_size;
	input [7:0] idx;
	get_cpage_size=suprted_comp_size[idx];
endfunction

function automatic iWayORcPagePkt_t getFreeCpage_ZsPageiWay;
	input logic [`HACD_AXI4_DATA_WIDTH-1:0] rdata;
	iWayORcPagePkt_t pkt;
	ZsPg_Md_t md;
	logic [47:0] iway_ptr,nxtway_ptr;
	logic [13:0] cpage_size;

	md=rdata[(50*8-1)+2*48:2*48];
	nxtway_ptr=rdata[(48-1)+48:48];
	iway_ptr=rdata[(48-1)+0 : 0]; 
	
	cpage_size=suprted_comp_size[md.size];
	
	//cpage byte start
	if(md.way_vld[0]) begin
		if          (!md.pg_vld[0]) begin
				pkt.cPage_byteStart=iway_ptr+ZS_OFFSET; //first page
				md.page0=iway_ptr+ZS_OFFSET;
				md.pg_vld[0]=1'b1;
			//chk for 4KB crossover
		end else if (!md.pg_vld[1]) begin
				if (md.page0+(2*cpage_size)< (iway_ptr+4096)) begin
					pkt.cPage_byteStart=md.page0+cpage_size;
					md.page1=md.page0+cpage_size;
					md.pg_vld[1]=1'b1;
				end //not handling other cases for now 
		end else if (!md.pg_vld[2]) begin
				if (md.page1+(2*cpage_size)< (iway_ptr+4096)) begin
					pkt.cPage_byteStart=md.page1+cpage_size;
					md.page2=md.page1+cpage_size;
					md.pg_vld[2]=1'b1;
				end //not handling other cases for now 
		end
	end //not handling other ways for now

        //cpage size
	pkt.cpage_size=cpage_size;
	pkt.update=1'b0;
	pkt.iWay_ptr=iway_ptr;
	pkt.nxtWay_ptr=nxtway_ptr;
	pkt.zsPgMd=md;

	getFreeCpage_ZsPageiWay=pkt;
	`ifndef SYNTH
		$display ("RAGHAV DEBUG rdata- %0h",rdata );

		$display ("RAGHAV DEBUG ZSpage Size- %0h",pkt.zsPgMd.size );
		$display ("RAGHAV DEBUG way_vld- %0h", pkt.zsPgMd.way_vld );
		$display ("RAGHAV DEBUG pg_vld- %0h",pkt.zsPgMd.pg_vld );
		$display ("RAGHAV DEBUG way0- %0h",pkt.zsPgMd.way0 );
		$display ("RAGHAV DEBUG page0- %0h",pkt.zsPgMd.page0 );
		$display ("RAGHAV DEBUG page1- %0h",pkt.zsPgMd.page1 );
		$display ("RAGHAV DEBUG page2- %0h",pkt.zsPgMd.page2 );

		$display ("RAGHAV DEBUG cpagebyteStart- %0h",pkt.cPage_byteStart );
		$display ("RAGHAV DEBUG cpage_size - %0h",pkt.cpage_size );
		$display ("RAGHAV DEBUG iWay_ptr - %0h",pkt.iWay_ptr );
		$display ("RAGHAV DEBUG nxtWay_ptr - %0h",pkt.nxtWay_ptr );
	`endif
endfunction

function automatic iWayORcPagePkt_t setCpageBusy_ZsPageiWay;
	input logic [`HACD_AXI4_DATA_WIDTH-1:0] rdata;
	input logic [47:0] cPage_byteStart;
	iWayORcPagePkt_t pkt;

	pkt.zsPgMd=rdata[(50*8-1)+2*48:2*48]; //50 bytes on LSB
	pkt.nxtWay_ptr=rdata[(48-1)+48:48];
	pkt.iWay_ptr=rdata[(48-1)+0 : 0];  
	pkt.cpage_size=suprted_comp_size[pkt.zsPgMd.size];
	pkt.update=1'b0;
 		
	//cpage byte start
	if 	(pkt.zsPgMd.page0 == cPage_byteStart) begin
		pkt.zsPgMd.pg_vld[0]=1'b0;
	end 
	else if (pkt.zsPgMd.page1 == cPage_byteStart) begin
		pkt.zsPgMd.pg_vld[1]=1'b0;
	end
	else if (pkt.zsPgMd.page2 == cPage_byteStart) begin
		pkt.zsPgMd.pg_vld[2]=1'b0;
	end
	else if (pkt.zsPgMd.page3 == cPage_byteStart) begin
		pkt.zsPgMd.pg_vld[3]=1'b0;
	end
	else if (pkt.zsPgMd.page4 == cPage_byteStart) begin
		pkt.zsPgMd.pg_vld[4]=1'b0;
	end
	
	//[TODO] invalidate way valid based on if all page valid goes invalid later
		

	setCpageBusy_ZsPageiWay=pkt;

	`ifndef SYNTH
		$display ("RAGHAV SETCPAGE DEBUG rdata- %0h",rdata );

		$display ("RAGHAV SETCPAGE DEBUG ZSpage Size- %0h",pkt.zsPgMd.size );
		$display ("RAGHAV SETCPAGE DEBUG way_vld- %0h", pkt.zsPgMd.way_vld );
		$display ("RAGHAV SETCPAGE DEBUG pg_vld- %0h",pkt.zsPgMd.pg_vld );
		$display ("RAGHAV SETCPAGE DEBUG way0- %0h",pkt.zsPgMd.way0 );
		$display ("RAGHAV SETCPAGE DEBUG page0- %0h",pkt.zsPgMd.page0 );
		$display ("RAGHAV SETCPAGE DEBUG page1- %0h",pkt.zsPgMd.page1 );
		$display ("RAGHAV SETCPAGE DEBUG page2- %0h",pkt.zsPgMd.page2 );

		$display ("RAGHAV SETCPAGE DEBUG cpagebyteStart- %0h",pkt.cPage_byteStart );
		$display ("RAGHAV SETCPAGE DEBUG cpage_size - %0h",pkt.cpage_size );
		$display ("RAGHAV SETCPAGE DEBUG iWay_ptr - %0h",pkt.iWay_ptr );
		$display ("RAGHAV SETCPAGE DEBUG nxtWay_ptr - %0h",pkt.nxtWay_ptr );
	`endif

endfunction

endpackage
