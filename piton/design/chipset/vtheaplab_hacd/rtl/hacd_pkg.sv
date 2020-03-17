package hacd_pkg;
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
    parameter bit [63:0] HAWK_ATT_START=64'hFFF6100000; //64'h80000000;
    parameter bit [63:0] HAWK_LIST_START=64'hFFF6200000; 
    parameter bit [63:0] HAWK_PPA_START = 64'hFFF6300000;

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
 typedef struct packed {
	bit [63:56] zpd_cnt; //zero page detection count
	bit [/*49*/55:2]  way;      //technically it is start address of physical page
	bit [1:0]   sts;       //0:Deallocated,1:Uncompressed,2:Compressed,3:Incompressible
 	} AttEntry;
	
 typedef struct packed {
	bit [127:104] rsvd; 
	bit [103:54] way;
	bit [53:28] prev;
	bit [27:0] next;
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
 } axi_wr_reqpkt_t;

  typedef struct packed {
 	logic [63:0]  addr;
	logic [511:0] data;
	logic [63:0]  strb;
	//Below are extra othre fields
	logic [47:0] ppa;
 } axi_wr_pld_t;

 typedef struct packed {
 	logic awready;
	logic wready;
 } axi_wr_rdypkt_t;

 typedef struct packed {
 	logic bresp;
 } axi_wr_resppkt_t;

 //Axi Read Packets betwenn hawk_axird_master and hawk_pgrd_mngr
  typedef struct packed {
 	logic [63:0]  addr;
	logic arvalid;
 } axi_rd_reqpkt_t;


  typedef struct packed {
 	logic [63:0]  addr;
 } axi_rd_pld_t; 

 typedef struct packed {
 	logic arready;
	logic rready;
 } axi_rd_rdypkt_t;

 typedef struct packed {
 	logic rresp;
 	logic rdata;
 	logic rvalid;
	logic rlast;
 } axi_rd_resppkt_t;

 //packets for interaction between cu, rd and write managers

 typedef struct packed {
 	logic [47:0] hppa;
	logic lookup;
 } att_lkup_reqpkt_t;
 
 typedef struct packed {
	logic [47:0] ppa;
	logic [1:0] sts;
	logic update;
 } tblUpdt_reqpkt_t;

 typedef struct packed {
	logic [47:0] ppa;
	logic allow_cpu_access;
 } transltn_reqpkt_t;

 typedef struct packed {
	logic [47:0] hppa;
	logic valid;
 } cpu_rd_reqpkt_t;

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
 parameter int ATT_ENTRY_CNT=16; // lower count for verification //update later
 parameter int LIST_ENTRY_CNT=16; // update later



  //helkper fucntins
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


endpackage

