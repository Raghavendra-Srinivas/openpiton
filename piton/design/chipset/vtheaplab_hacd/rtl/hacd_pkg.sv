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
    parameter bit [63:0] HAWK_ATT_START=  64'hFFF6100000; //64'h80000000;
    parameter bit [63:0] HAWK_LIST_START= 64'hFFF6200000; 
    parameter bit [63:0] HAWK_PPA_START = 64'hFFF6300000;

    parameter bit [63:0] DDR_START_ADDR=  64'h80000000;
    parameter bit [63:0] HPPA_BASE_ADDR=  64'hFFF6400000; //for DV //DDR_START_ADDR;

    parameter int BLK_SIZE=64;
    parameter int ATT_ENTRY_SIZE=8;
    parameter int ATT_ENTRY_PER_BLK=BLK_SIZE/ATT_ENTRY_SIZE;
    parameter int LIST_ENTRY_SIZE=16;
    parameter int LST_ENTRY_PER_BLK=BLK_SIZE/LIST_ENTRY_SIZE;
    parameter int BYTE=8;

    parameter int COMPRESSION_RATIO=4;
    parameter int DRAM_SIZE=1<<30; ////1GB
    parameter int PAGE_SIZE=1<<12; //4KB 
    parameter int ATT_ENTRY_MAX=COMPRESSION_RATIO*(DRAM_SIZE/PAGE_SIZE);
    parameter int LST_ENTRY_MAX=(DRAM_SIZE/PAGE_SIZE);
    parameter int ATT_ENTRY_CNT=4;  //ATT_ENTRY_MAX // lower count for verification //update later
    parameter int LIST_ENTRY_CNT=4; //LST_ENTRY_MAX // lower count for verification //update later

    localparam [clogb2(LST_ENTRY_MAX)-1:0] NULL='d0;
    parameter int IFLST_COUNT=1;

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
	logic [63:54] zpd_cnt; //zero page detection count
	logic [53:2]  way;      //technically it is start address of physical page
	logic [1:0]   sts;       //0:Deallocated,1:Uncompressed,2:Compressed,3:Incompressible
 	} AttEntry;
	
 typedef struct packed {
	logic [127:114] rsvd; 
	logic [113:64] way;
	logic [63:32] prev;
	logic [31:0] next;
 } ListEntry;

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
 	logic bresp;
	logic bvalid;
 } axi_wr_resppkt_t;

 //Axi Read Packets betwenn hawk_axird_master and hawk_pgrd_mngr
  typedef struct packed {
 	logic [63:0]  addr;
	logic arvalid;
	logic rready;
 } axi_rd_reqpkt_t;


  typedef struct packed {
 	logic [63:0]  addr;
    	logic [`HACD_AXI4_LEN_WIDTH-1:0] awlen;
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
 	logic [`HACD_AXI4_ADDR_WIDTH-1:12] hppa;
	logic lookup;
 } att_lkup_reqpkt_t;

 //below packet is used for  
 typedef struct packed {
	logic [`HACD_AXI4_ADDR_WIDTH-1:12] ppa;
	logic [1:0] sts;
	logic allow_access;
 } trnsl_reqpkt_t;

	
 //typedef enum {FREE,UNCOMP,COMP,INCOMP} LIST_NAME;
 localparam [1:0] NULLIFY='d0,FREE='d1, UNCOMP='d2,INCOMP='d3,IFL_SIZE1='d4; //There are 256 Irregular free list 
 typedef struct packed {
	logic [clogb2(ATT_ENTRY_MAX)-1:0] attEntryId;
	logic [clogb2(LST_ENTRY_MAX)-1:0] tolEntryId;
	ListEntry lstEntry;
	logic [2:0] src_list; //from which source we are removing this entry
	logic [2:0] dst_list; //to which list , we are moving this entry
	//logic [47:0] ppa;
	logic tbl_update;
 } tol_updpkt_t;


 typedef struct packed {
	logic [`HACD_AXI4_ADDR_WIDTH-1:12] hppa;
	logic valid;
 } cpu_reqpkt_t;


 typedef struct packed {
	logic [`HACD_AXI4_ADDR_WIDTH-1:12] ppa;
	logic allow_access;
 } hawk_cpu_ovrd_pkt_t;

  






//helper fucntins
function logic [511:0] get_8byte_byteswap;
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
		get_8byte_byteswap=data;
endfunction
function logic [63:0] get_strb_swap;
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
	get_strb_swap=data;	
endfunction
 
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


//////////
//ToL HEAD and TAILS
 typedef struct packed {
  logic [clogb2(LST_ENTRY_MAX)-1:0] freeListHead;	
  logic [clogb2(LST_ENTRY_MAX)-1:0] freeListTail;	
  logic [clogb2(LST_ENTRY_MAX)-1:0] uncompListHead;	
  logic [clogb2(LST_ENTRY_MAX)-1:0] uncompListTail;	
 } hawk_tol_ht_t;


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

parameter int ZS_MD_SIZE=50; //size+valids+3 ways+5 pages=50bytes 

//typedef enum {IWAY,CPAGE} CTYPE;
typedef struct packed{
	logic update;
	//CTYPE iWayORcPage; //packet type iWay type serves either while creating new ZsPage or Updating existing zsPage 
	logic [47:0] cPage_byteStart;//page start-where to write compressed page if (iWayORcPage==0) = > iWay_start+ Byte address(62bytes) = $size(zsPgMd)=50bytes+ iwayptr(6bytes) + nxtwayptr(6bytes) else 
	logic [13:0] cpage_size;
	//payload content
	logic [47:0] iWay_ptr;  //6B  
	logic [47:0] nxtWay_ptr; //6B 
	ZsPg_Md_t zsPgMd; //50bytes
} iWayORcPagePkt_t;

endpackage

