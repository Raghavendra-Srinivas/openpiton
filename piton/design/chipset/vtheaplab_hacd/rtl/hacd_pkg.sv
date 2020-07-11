package hacd_pkg;
    `include "hacd_define.vh"
    /// 32 bit address, 32 bit data request package
    typedef struct packed {
        logic [31:0] addr;
        logic        write;
        logic [31:0] wdata;
        logic [3:0]  wstrb;
        logic        valid;
    } reg_intf_req_a32_d32;

    /// 32 bit Response packages
    typedef struct packed {
        logic [31:0] rdata;
        logic        error;
        logic        ready;
    } reg_intf_resp_d32;
  

    //default values for page tables start and end

    parameter int BLK_SIZE=64;
    parameter int ATT_ENTRY_SIZE=8;
    parameter int ATT_ENTRY_PER_BLK=BLK_SIZE/ATT_ENTRY_SIZE;
    parameter int LIST_ENTRY_SIZE=16;
    parameter int LST_ENTRY_PER_BLK=BLK_SIZE/LIST_ENTRY_SIZE;
    parameter int BYTE=8;

    parameter int COMPRESSION_RATIO=2; //4;
    parameter int DRAM_SIZE=1<<30; ////1GB
    parameter int PAGE_SIZE=1<<12; //4KB 
    parameter int LST_ENTRY_MAX=(DRAM_SIZE/PAGE_SIZE);
    parameter int ATT_ENTRY_MAX=COMPRESSION_RATIO*LST_ENTRY_MAX;
   

   `ifdef HAWK_FPGA
    	parameter int LIST_ENTRY_CNT= LST_ENTRY_MAX; 
    	parameter int ATT_ENTRY_CNT= ATT_ENTRY_MAX;  
    	parameter bit [63:0] DDR_START_ADDR=  64'h0; 
    	parameter bit [63:0] HAWK_ATT_START=  DDR_START_ADDR; // 0x0
        parameter bit [63:0] HAWK_LIST_START= HAWK_ATT_START + (ATT_ENTRY_MAX/8)*64'h40; //=0x400000 //8 ATT  entries can fit in one cache line //64'h1000; //0x1000
        parameter bit [63:0] HAWK_PPA_START = HAWK_LIST_START + (LST_ENTRY_MAX/4)*64'h40;//4 LIST entries can fit in one cache line //64'h1000; //0x2000
	parameter bit [63:0] HPPA_BASE_ADDR = DDR_START_ADDR; // + 64'h00200000; //200000
   `else
    	parameter int LIST_ENTRY_CNT=8;
	parameter int ATT_ENTRY_CNT= COMPRESSION_RATIO*LIST_ENTRY_CNT;  
    	parameter bit [63:0] DDR_START_ADDR=  64'hFFF6100000; //64'hC0000000; //64'hFFF6100000;
    	parameter bit [63:0] HAWK_ATT_START=  DDR_START_ADDR;  
    	parameter bit [63:0] HAWK_LIST_START= 64'hFFF6200000; //64'hC0100000; //64'hFFF6200000; //HAWK_ATT_START + 'd64;//HAWK_ATT_START+ ceil(ATT_ENTRY_CNT/ATT_ENTRY_PER_BLK)*BLK_SIZE;//64'hFFF6200000; 
    	parameter bit [63:0] HAWK_PPA_START = 64'hFFF6300000; //64'hC0200000; //64'hFFF6300000; //DDR_START_ADDR + 'd4096;//One page allocated for table for bringup//HAWK_LIST_START + ceil((LIST_ENTRY_CNT/LST_ENTRY_PER_BLK))*BLK_SIZE ; //64'hFFF6300000;
    	parameter bit [63:0] HPPA_BASE_ADDR=  64'hFFF6400000; //64'hC0400000; //64'hFFF6400000; //for DV
   `endif


    localparam [clogb2(LST_ENTRY_MAX)-1:0] NULL='d0;

    //parameter bit [63:0] HAWK_ATT_END=  64'hFFF6101000;    //64'h80001000;//32'h80800000
    //One memory block init data for ATT
    /*
    //ATT Entry , default values for init state 
    typedef struct packed {
	bit [63:2] ppa;
	bit c_sts;
	bit in_use;
 	} ATT_ENTRY;
    typedef union packed {
    	bit [63:2] superway;
	bit [63:2] hppa;
    } ptt_dat_t;
    //PTT Entry , default values for init state 
    typedef struct packed {
	ptt_dat_t ptt_dat;
	bit c_sts;
	bit is_free;
 	} PTT_ENTRY;
    */
 //align fields to byte, wherever possible
 parameter [1:0] STS_DALLOC=2'b00;
 parameter [1:0] STS_UNCOMP=2'b01;
 parameter [1:0] STS_COMP=2'b10;
 parameter [1:0] STS_INCOMP=2'b11;
 typedef struct packed {
	logic [63:56] zpd_cnt; //ZPD_CNT: zero page detection count
	logic [55:2]  way;     //WAY    : physical page address
	logic [1:0]   sts;     //STATUS : 0:Deallocated,1:Uncompressed,2:Compressed,3:Incompressible
 } AttEntry;

 typedef struct packed {
	logic [127:120] rsvd;
	logic [119:72] way;
	logic [71:48] attEntryId;
	logic [47:24] prev;
	logic [23:0] next;
 } ListEntry;

 //RSVD: Reserved                   
 //WAY : Physical page address  || ATT EID: ATTEntry that got this ppa 
 //PREV: Previous List entry ID || NEXT   : Next List entry ID 

 //Below packet is between hawk_axiwr_master and hawk_pgwr_mngr
 //For simplicity , we dont treat addr and data as separate, though they are
 //independnt channels for axi.
 typedef struct packed {
 	logic [63:0]  addr;
	logic [511:0] data;
	logic [63:0]  strb;
	logic awvalid;
	logic wvalid;
	//logic bready;
 } axi_wr_reqpkt_t;

  typedef struct packed {
 	logic [63:0]  addr;
	logic [511:0] data;
	logic [63:0]  strb;
 } axi_wr_pld_t;

 typedef struct packed {
 	logic awready;
	logic wready;
 } axi_wr_rdypkt_t;

 typedef struct packed {
 	logic [1:0] bresp;
	logic bvalid;
 } axi_wr_resppkt_t;

 //Axi Read Packets betwenn hawk_axird_master and hawk_pgrd_mngr
  typedef struct packed {
 	logic [63:0]  addr;
    	logic [`HACD_AXI4_LEN_WIDTH-1:0] arlen;
	logic arvalid;
	logic rready;
 } axi_rd_reqpkt_t;


  typedef struct packed {
 	logic [63:0]  addr;
    	logic [`HACD_AXI4_LEN_WIDTH-1:0] arlen;
 } axi_rd_pld_t; 

 typedef struct packed {
 	logic arready;
 } axi_rd_rdypkt_t;

 typedef struct packed {
 	logic [`HACD_AXI4_RESP_WIDTH-1:0] rresp;
 	logic [`HACD_AXI4_DATA_WIDTH-1:0] rdata;
 	logic rvalid;
	logic rlast;
 } axi_rd_resppkt_t;

 //packets for interaction between cu, rd and write managers

 typedef struct packed {
	logic zeroBlkWr;
 	logic [`HACD_AXI4_ADDR_WIDTH-1:12] hppa;
	logic lookup;
 } att_lkup_reqpkt_t;

 //below packet is used for  
 typedef struct packed {
	logic [7:0] zpd_cnt;
	logic zpd_update;
	logic [`HACD_AXI4_ADDR_WIDTH-1:0] ppa;
	logic [1:0] sts;
	logic allow_access;
 } trnsl_reqpkt_t;

	
 //typedef enum {FREE,UNCOMP,COMP,INCOMP} LIST_NAME;
 localparam [2:0] NULLIFY='d0,IFL_DETACH='d1,FREE='d2, UNCOMP='d3,INCOMP='d4,IFL_SIZE1='d5; //There can be 256 Irregular free list 
 typedef struct packed {
	logic [clogb2(ATT_ENTRY_MAX)-1:0] attEntryId;
	logic [clogb2(LST_ENTRY_MAX)-1:0] tolEntryId;
	ListEntry lstEntry;
	logic [2:0] src_list; //from which source we are removing this entry
	logic [2:0] dst_list; //to which list , we are moving this entry
	//logic [47:0] ppa;
	logic [7:0] ifl_idx; //this is needed for irregular free list
	logic ATT_UPDATE_ONLY;
	logic TOL_UPDATE_ONLY;
	logic [1:0] ATT_STS;
	logic [7:0] zpd_cnt;
	logic tbl_update;
 } tol_updpkt_t;


 typedef struct packed {
	logic zeroBlkWr;
	logic [`HACD_AXI4_ADDR_WIDTH-1:12] hppa;
	logic valid;
 } cpu_reqpkt_t;


 typedef struct packed {
	logic [`HACD_AXI4_ADDR_WIDTH-1:12] ppa;
	logic allow_access;
 } hawk_cpu_ovrd_pkt_t;

  






//helper fucntins
function automatic logic [511:0] get_8byte_byteswap;
	input logic [511:0] data;
	integer i,j;
	logic [63:0] eightByte,swappedEightByte;

  	for(i=0;i<8;i=i+1) begin //8*8bytes = 64bytes per cacheline
		//Take first 8byte
		eightByte = data[(64*i)+:64];
		//within 8byte swap bytes
		for(j=0;j<8;j=j+1) begin //byteswap in each 8bytes 
			swappedEightByte[8*j+:8] = eightByte[(63-8*j)-:8];
		end
		get_8byte_byteswap[(64*i)+:64]=swappedEightByte;
	end
	
	//For hawk byteswap does not matter
		//get_8byte_byteswap=data;
endfunction 

function automatic logic [63:0] get_strb_swap;
	input logic [63:0] data;
	integer i,j;
	logic [7:0] eightByte,swappedEightByte;

  	for(i=0;i<8;i=i+1) begin //8*8bytes = 64bytes per cacheline
		//Take first 8byte
		eightByte = data[(8*i)+:8];
		//within 8byte swap bytes
		for(j=0;j<8;j=j+1) begin //byteswap in each 8bytes 
			swappedEightByte[1*j+:1] = eightByte[(7-1*j)-:1];
		end
		get_strb_swap[(8*i)+:8]=swappedEightByte;
	end
	//For hawk byteswap does not matter
	//get_strb_swap=data;	
endfunction 

function automatic logic [63:0] get_reverse_strb;
	input logic [63:0] strb_in;
	integer i;
  	for(i=0;i<64;i=i+1) begin
		get_reverse_strb[63-i]=strb_in[i];
	end
endfunction
 
  //generic helper function automatics
  function automatic integer clogb2;
      input [31:0] value;
      begin
          value = (value<<1) - 1;
          for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1) begin
              value = value >> 1;
          end
      end
  endfunction 


//////////
    parameter int IFLST_COUNT=1;
//ToL HEAD and TAILS
 typedef struct {
  logic [clogb2(LST_ENTRY_MAX)-1:0] freeListHead;	
  logic [clogb2(LST_ENTRY_MAX)-1:0] freeListTail;	
  logic [clogb2(LST_ENTRY_MAX)-1:0] uncompListHead;	
  logic [clogb2(LST_ENTRY_MAX)-1:0] uncompListTail;
  logic [clogb2(LST_ENTRY_MAX)-1:0] incompListHead;	
  logic [clogb2(LST_ENTRY_MAX)-1:0] incompListTail;
  logic [clogb2(LST_ENTRY_MAX)-1:0]  IfLstHead[IFLST_COUNT];	
  logic [clogb2(LST_ENTRY_MAX)-1:0]  IfLstTail[IFLST_COUNT];	
 } hawk_tol_ht_t;

localparam [2:0] MAX_PAGE_ZSPAGE=3; //to support naive compression //5;
localparam [2:0] MAX_WAY_ZSPAGE=1; //to support naive compression //3;
//Zspage
//ZSpage Identity Way
typedef struct packed {
	logic [47:0] page4;//6 byte
	logic [47:0] page3;//6 byte
	logic [47:0] page2;//6 byte
	logic [47:0] page1;//6 byte
	logic [47:0] page0;//6 byte
	logic [47:0] way2;//6 byte
	logic [47:0] way1;//6 byte
	logic [47:0] way0;//6 byte
	logic [4:0] pg_vld; //5 pages
	logic [2:0] way_vld; //3 sways
	logic [7:0] size; //1byte
} ZsPg_Md_t;
typedef struct packed {
	logic [47:0] src_cpage_ptr; //this shoudl indicate iWayptr while doing zspage_update atlast
	logic [47:0] dst_cpage_ptr;
	logic migrate;
	ZsPg_Md_t md;
	logic zspg_update;	
} zsPageMigratePkt_t;

parameter int ZS_OFFSET=48'd64; //size+valids+3 ways+5 pages=50bytes 

//typedef enum {IWAY,CPAGE} CTYPE;
typedef struct packed{
	logic update;
	logic comp_decomp;
	logic pp_ifl;
	//CTYPE iWayORcPage; //packet type iWay type serves either while creating new ZsPage or Updating existing zsPage 
	logic [47:0] cPage_byteStart;//page start-where to write compressed page if (iWayORcPage==0) = > iWay_start+ Byte address(62bytes) = $size(zsPgMd)=50bytes+ iwayptr(6bytes) + nxtwayptr(6bytes) else 
	logic [13:0] cpage_size;
	//payload content
	ZsPg_Md_t zsPgMd; //50bytes
	logic [47:0] nxtWay_ptr; //6B 
	logic [47:0] iWay_ptr;  //6B  
} iWayORcPagePkt_t;


//debug probes
   typedef struct packed  {
	   logic [63:0] last_addr0;
   	   logic [63:0] last_addr1; 

   	   logic [63:0] req_count0,resp_count0;
   	   logic [63:0] req_count1,resp_count1;
  	   logic overflow;
  	   logic bus_error;
	   logic [1:0] fsm_state;
	   logic illegal_hawk_table_access;
   } stall_debug_bus;

endpackage

