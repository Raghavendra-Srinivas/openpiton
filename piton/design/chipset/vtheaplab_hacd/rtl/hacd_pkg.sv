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
    parameter int ATT_ENTRY_CNT=8; // lower count for verification //update later
    parameter int LIST_ENTRY_CNT=8; // update later

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
	bit [63:54] zpd_cnt; //zero page detection count
	bit [53:2]  way;      //technically it is start address of physical page
	bit [1:0]   sts;       //0:Deallocated,1:Uncompressed,2:Compressed,3:Incompressible
 	} AttEntry;
	
 typedef struct packed {
	bit [127:114] rsvd; 
	bit [113:64] way;
	bit [63:32] prev;
	bit [31:0] next;
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
 localparam [1:0] FREE='d0, UNCOMP='d1,COMP='d2,INCOMP='d3;
 typedef struct packed {
	logic [clogb2(ATT_ENTRY_MAX)-1:0] attEntryId;
	logic [clogb2(LST_ENTRY_MAX)-1:0] tolEntryId;
	ListEntry lstEntry;
	logic [1:0] src_list; //from which source we are removing this entry
	logic [1:0] dst_list; //to which list , we are moving this entry
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
function bit [511:0] get_8byte_byteswap;
	input bit [511:0] data;
	integer i,j;
	bit [63:0] eightByte,swappedEightByte;

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
function bit [63:0] get_strb_swap;
	input bit [63:0] data;
	integer i,j;
	bit [7:0] eightByte,swappedEightByte;

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


//ToL HEAD and TAILS
 typedef struct packed {
  logic [clogb2(LST_ENTRY_MAX)-1:0] freeListHead;	
  logic [clogb2(LST_ENTRY_MAX)-1:0] freeListTail;	
  logic [clogb2(LST_ENTRY_MAX)-1:0] uncompListHead;	
  logic [clogb2(LST_ENTRY_MAX)-1:0] uncompListTail;	
 } hawk_tol_ht_t;

endpackage

