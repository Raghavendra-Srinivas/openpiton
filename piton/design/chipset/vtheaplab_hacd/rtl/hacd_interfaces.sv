     

`include "hacd_define.vh"

/// An AXI4 interface.
interface HACD_AXI_WR_BUS #(
  //parameter AXI_ADDR_WIDTH = -1,
  //parameter AXI_DATA_WIDTH = -1,
  //parameter AXI_ID_WIDTH   = -1,
  //parameter AXI_USER_WIDTH = -1
);

    // AXI Write Address Channel Signals
    logic [`HACD_AXI4_ID_WIDTH     -1:0]    axi_awid;
    logic [`HACD_AXI4_ADDR_WIDTH   -1:0]    axi_awaddr;
    logic [`HACD_AXI4_LEN_WIDTH    -1:0]    axi_awlen;
    logic [`HACD_AXI4_SIZE_WIDTH   -1:0]    axi_awsize;
    logic [`HACD_AXI4_BURST_WIDTH  -1:0]    axi_awburst;
    logic                              axi_awlock;
    logic [`HACD_AXI4_CACHE_WIDTH  -1:0]    axi_awcache;
    logic [`HACD_AXI4_PROT_WIDTH   -1:0]    axi_awprot;
    logic [`HACD_AXI4_QOS_WIDTH    -1:0]    axi_awqos;
    logic [`HACD_AXI4_REGION_WIDTH -1:0]    axi_awregion;
    logic [`HACD_AXI4_USER_WIDTH   -1:0]    axi_awuser;
    logic                              axi_awvalid;
    logic                              axi_awready;

    // AXI Write Data Channel Signals
    //logic  [`HACD_AXI4_ID_WIDTH     -1:0]   axi_wid;
    logic  [`HACD_AXI4_DATA_WIDTH   -1:0]   axi_wdata;
    logic  [`HACD_AXI4_STRB_WIDTH   -1:0]   axi_wstrb;
    logic                              axi_wlast;
    logic  [`HACD_AXI4_USER_WIDTH   -1:0]   axi_wuser;
    logic                              axi_wvalid;
    logic                              axi_wready;

    // AXI Write Response Channel Signals
    logic  [`HACD_AXI4_ID_WIDTH     -1:0]   axi_bid;
    logic  [`HACD_AXI4_RESP_WIDTH   -1:0]   axi_bresp;
    logic  [`HACD_AXI4_USER_WIDTH   -1:0]   axi_buser;
    logic                              axi_bvalid;
    logic                              axi_bready;

   modport mstr(output axi_awid,
	   	  output axi_awaddr,
		  output axi_awlen,
		  output axi_awsize,
		  output axi_awburst,
		  output axi_awlock,
		  output axi_awcache,
		  output axi_awprot,
		  output axi_awqos,
		  output axi_awregion,
		  output axi_awuser,
		  output axi_awvalid,
		  input axi_awready,

	      	  //output    axi_wid,
                  output    axi_wdata,
                  output    axi_wstrb,
                  output    axi_wlast,
                  output    axi_wuser,
                  output    axi_wvalid,
                  input     axi_wready,
              
                  input     axi_bid,
                  input     axi_bresp,
                  input     axi_buser,
                  input     axi_bvalid,
                  output    axi_bready
	  );

   modport slv(input axi_awid,
	   	  input axi_awaddr,
		  input axi_awlen,
		  input axi_awsize,
		  input axi_awburst,
		  input axi_awlock,
		  input axi_awcache,
		  input axi_awprot,
		  input axi_awqos,
		  input axi_awregion,
		  input axi_awuser,
		  input axi_awvalid,
		  output axi_awready,

	      	  //input    axi_wid,
                  input    axi_wdata,
                  input    axi_wstrb,
                  input    axi_wlast,
                  input    axi_wuser,
                  input    axi_wvalid,
                  output     axi_wready,
              
                  output     axi_bid,
                  output     axi_bresp,
                  output     axi_buser,
                  output     axi_bvalid,
                  input    axi_bready
	  );	  
endinterface
   
// An AXI4 interface.
interface HACD_AXI_RD_BUS #(
  //parameter AXI_ADDR_WIDTH = -1,
  //parameter AXI_DATA_WIDTH = -1,
  //parameter AXI_ID_WIDTH   = -1,
  //parameter AXI_USER_WIDTH = -1
);

    // AXI Read Address Channel Signals
     logic  [`HACD_AXI4_ID_WIDTH     -1:0]    axi_arid;
     logic  [`HACD_AXI4_ADDR_WIDTH   -1:0]    axi_araddr;
     logic  [`HACD_AXI4_LEN_WIDTH    -1:0]    axi_arlen;
     logic  [`HACD_AXI4_SIZE_WIDTH   -1:0]    axi_arsize;
     logic  [`HACD_AXI4_BURST_WIDTH  -1:0]    axi_arburst;
     logic                               axi_arlock;
     logic  [`HACD_AXI4_CACHE_WIDTH  -1:0]    axi_arcache;
     logic  [`HACD_AXI4_PROT_WIDTH   -1:0]    axi_arprot;
     logic  [`HACD_AXI4_QOS_WIDTH    -1:0]    axi_arqos;
     logic  [`HACD_AXI4_REGION_WIDTH -1:0]    axi_arregion;
     logic  [`HACD_AXI4_USER_WIDTH   -1:0]    axi_aruser;
     logic                               axi_arvalid;
     logic                               axi_arready;

    // AXI Read Data Channel Signals
     logic  [`HACD_AXI4_ID_WIDTH     -1:0]    axi_rid;
     logic  [`HACD_AXI4_DATA_WIDTH   -1:0]    axi_rdata;
     logic  [`HACD_AXI4_RESP_WIDTH   -1:0]    axi_rresp;
     logic                               axi_rlast;
     logic  [`HACD_AXI4_USER_WIDTH   -1:0]    axi_ruser;
     logic                               axi_rvalid;
     logic                               axi_rready;


   modport mstr(output axi_arid,
	   	  output axi_araddr,
		  output axi_arlen,
		  output axi_arsize,
		  output axi_arburst,
		  output axi_arlock,
		  output axi_arcache,
		  output axi_arprot,
		  output axi_arqos,
		  output axi_arregion,
		  output axi_aruser,
		  output axi_arvalid,
		  input axi_arready,

	      	  input axi_rid,
                  input axi_rdata,
                  input axi_rresp,
                  input axi_rlast,
                  input axi_ruser,
                  input axi_rvalid,
                  output axi_rready
	  );
   
   modport slv(input axi_arid,
	   	  input axi_araddr,
		  input axi_arlen,
		  input axi_arsize,
		  input axi_arburst,
		  input axi_arlock,
		  input axi_arcache,
		  input axi_arprot,
		  input axi_arqos,
		  input axi_arregion,
		  input axi_aruser,
		  input axi_arvalid,
		  output axi_arready,

	      	  output axi_rid,
                  output axi_rdata,
                  output axi_rresp,
                  output axi_rlast,
                  output axi_ruser,
                  output axi_rvalid,
                  input axi_rready
	  );

endinterface


/// An AXI4 interface.
interface HACD_MC_AXI_WR_BUS #(
  //parameter AXI_ADDR_WIDTH = -1,
  //parameter AXI_DATA_WIDTH = -1,
  //parameter AXI_ID_WIDTH   = -1,
  //parameter AXI_USER_WIDTH = -1
);

    // AXI Write Address Channel Signals
    logic [`HACD_MC_AXI4_ID_WIDTH     -1:0]    axi_awid;
    logic [`HACD_MC_AXI4_ADDR_WIDTH   -1:0]    axi_awaddr;
    logic [`HACD_MC_AXI4_LEN_WIDTH    -1:0]    axi_awlen;
    logic [`HACD_MC_AXI4_SIZE_WIDTH   -1:0]    axi_awsize;
    logic [`HACD_MC_AXI4_BURST_WIDTH  -1:0]    axi_awburst;
    logic                              axi_awlock;
    logic [`HACD_MC_AXI4_CACHE_WIDTH  -1:0]    axi_awcache;
    logic [`HACD_MC_AXI4_PROT_WIDTH   -1:0]    axi_awprot;
    logic [`HACD_MC_AXI4_QOS_WIDTH    -1:0]    axi_awqos;
    logic [`HACD_MC_AXI4_REGION_WIDTH -1:0]    axi_awregion;
    logic [`HACD_MC_AXI4_USER_WIDTH   -1:0]    axi_awuser;
    logic                              axi_awvalid;
    logic                              axi_awready;

    // AXI Write Data Channel Signals
    //logic  [`HACD_MC_AXI4_ID_WIDTH     -1:0]   axi_wid;
    logic  [`HACD_MC_AXI4_DATA_WIDTH   -1:0]   axi_wdata;
    logic  [`HACD_MC_AXI4_STRB_WIDTH   -1:0]   axi_wstrb;
    logic                              axi_wlast;
    logic  [`HACD_MC_AXI4_USER_WIDTH   -1:0]   axi_wuser;
    logic                              axi_wvalid;
    logic                              axi_wready;

    // AXI Write Response Channel Signals
    logic  [`HACD_MC_AXI4_ID_WIDTH     -1:0]   axi_bid;
    logic  [`HACD_MC_AXI4_RESP_WIDTH   -1:0]   axi_bresp;
    logic  [`HACD_MC_AXI4_USER_WIDTH   -1:0]   axi_buser;
    logic                              axi_bvalid;
    logic                              axi_bready;

   modport mstr(output axi_awid,
	   	  output axi_awaddr,
		  output axi_awlen,
		  output axi_awsize,
		  output axi_awburst,
		  output axi_awlock,
		  output axi_awcache,
		  output axi_awprot,
		  output axi_awqos,
		  output axi_awregion,
		  output axi_awuser,
		  output axi_awvalid,
		  input axi_awready,

	      	  //output    axi_wid,
                  output    axi_wdata,
                  output    axi_wstrb,
                  output    axi_wlast,
                  output    axi_wuser,
                  output    axi_wvalid,
                  input     axi_wready,
              
                  input     axi_bid,
                  input     axi_bresp,
                  input     axi_buser,
                  input     axi_bvalid,
                  output    axi_bready
	  );

   modport slv(input axi_awid,
	   	  input axi_awaddr,
		  input axi_awlen,
		  input axi_awsize,
		  input axi_awburst,
		  input axi_awlock,
		  input axi_awcache,
		  input axi_awprot,
		  input axi_awqos,
		  input axi_awregion,
		  input axi_awuser,
		  input axi_awvalid,
		  output axi_awready,

	      	  //input    axi_wid,
                  input    axi_wdata,
                  input    axi_wstrb,
                  input    axi_wlast,
                  input    axi_wuser,
                  input    axi_wvalid,
                  output     axi_wready,
              
                  output     axi_bid,
                  output     axi_bresp,
                  output     axi_buser,
                  output     axi_bvalid,
                  input    axi_bready
	  );	  
endinterface
   
// An AXI4 interface.
interface HACD_MC_AXI_RD_BUS #(
  //parameter AXI_ADDR_WIDTH = -1,
  //parameter AXI_DATA_WIDTH = -1,
  //parameter AXI_ID_WIDTH   = -1,
  //parameter AXI_USER_WIDTH = -1
);

    // AXI Read Address Channel Signals
     logic  [`HACD_MC_AXI4_ID_WIDTH     -1:0]    axi_arid;
     logic  [`HACD_MC_AXI4_ADDR_WIDTH   -1:0]    axi_araddr;
     logic  [`HACD_MC_AXI4_LEN_WIDTH    -1:0]    axi_arlen;
     logic  [`HACD_MC_AXI4_SIZE_WIDTH   -1:0]    axi_arsize;
     logic  [`HACD_MC_AXI4_BURST_WIDTH  -1:0]    axi_arburst;
     logic                               axi_arlock;
     logic  [`HACD_MC_AXI4_CACHE_WIDTH  -1:0]    axi_arcache;
     logic  [`HACD_MC_AXI4_PROT_WIDTH   -1:0]    axi_arprot;
     logic  [`HACD_MC_AXI4_QOS_WIDTH    -1:0]    axi_arqos;
     logic  [`HACD_MC_AXI4_REGION_WIDTH -1:0]    axi_arregion;
     logic  [`HACD_MC_AXI4_USER_WIDTH   -1:0]    axi_aruser;
     logic                               axi_arvalid;
     logic                               axi_arready;

    // AXI Read Data Channel Signals
     logic  [`HACD_MC_AXI4_ID_WIDTH     -1:0]    axi_rid;
     logic  [`HACD_MC_AXI4_DATA_WIDTH   -1:0]    axi_rdata;
     logic  [`HACD_MC_AXI4_RESP_WIDTH   -1:0]    axi_rresp;
     logic                               axi_rlast;
     logic  [`HACD_MC_AXI4_USER_WIDTH   -1:0]    axi_ruser;
     logic                               axi_rvalid;
     logic                               axi_rready;


   modport mstr(output axi_arid,
	   	  output axi_araddr,
		  output axi_arlen,
		  output axi_arsize,
		  output axi_arburst,
		  output axi_arlock,
		  output axi_arcache,
		  output axi_arprot,
		  output axi_arqos,
		  output axi_arregion,
		  output axi_aruser,
		  output axi_arvalid,
		  input axi_arready,

	      	  input axi_rid,
                  input axi_rdata,
                  input axi_rresp,
                  input axi_rlast,
                  input axi_ruser,
                  input axi_rvalid,
                  output axi_rready
	  );
   
   modport slv(input axi_arid,
	   	  input axi_araddr,
		  input axi_arlen,
		  input axi_arsize,
		  input axi_arburst,
		  input axi_arlock,
		  input axi_arcache,
		  input axi_arprot,
		  input axi_arqos,
		  input axi_arregion,
		  input axi_aruser,
		  input axi_arvalid,
		  output axi_arready,

	      	  output axi_rid,
                  output axi_rdata,
                  output axi_rresp,
                  output axi_rlast,
                  output axi_ruser,
                  output axi_rvalid,
                  input axi_rready
	  );
endinterface

/// An AXI4 interface.
interface HACD_AXI_XBAR_WR_BUS #(
  //parameter AXI_ADDR_WIDTH = -1,
  //parameter AXI_DATA_WIDTH = -1,
  //parameter AXI_ID_WIDTH   = -1,
  //parameter AXI_USER_WIDTH = -1
);

    // AXI Write Address Channel Signals
    logic [`HACD_MC_AXI4_ID_WIDTH     -1:0]    axi_awid;
    logic [`HACD_AXI4_ADDR_WIDTH   -1:0]    axi_awaddr;
    logic [`HACD_AXI4_LEN_WIDTH    -1:0]    axi_awlen;
    logic [`HACD_AXI4_SIZE_WIDTH   -1:0]    axi_awsize;
    logic [`HACD_AXI4_BURST_WIDTH  -1:0]    axi_awburst;
    logic                              axi_awlock;
    logic [`HACD_AXI4_CACHE_WIDTH  -1:0]    axi_awcache;
    logic [`HACD_AXI4_PROT_WIDTH   -1:0]    axi_awprot;
    logic [`HACD_AXI4_QOS_WIDTH    -1:0]    axi_awqos;
    logic [`HACD_AXI4_REGION_WIDTH -1:0]    axi_awregion;
    logic [`HACD_AXI4_USER_WIDTH   -1:0]    axi_awuser;
    logic                              axi_awvalid;
    logic                              axi_awready;

    // AXI Write Data Channel Signals
    //logic  [`HACD_AXI4_ID_WIDTH     -1:0]   axi_wid;
    logic  [`HACD_AXI4_DATA_WIDTH   -1:0]   axi_wdata;
    logic  [`HACD_AXI4_STRB_WIDTH   -1:0]   axi_wstrb;
    logic                              axi_wlast;
    logic  [`HACD_AXI4_USER_WIDTH   -1:0]   axi_wuser;
    logic                              axi_wvalid;
    logic                              axi_wready;

    // AXI Write Response Channel Signals
    logic  [`HACD_MC_AXI4_ID_WIDTH     -1:0]   axi_bid;
    logic  [`HACD_AXI4_RESP_WIDTH   -1:0]   axi_bresp;
    logic  [`HACD_AXI4_USER_WIDTH   -1:0]   axi_buser;
    logic                              axi_bvalid;
    logic                              axi_bready;

   modport mstr(output axi_awid,
	   	  output axi_awaddr,
		  output axi_awlen,
		  output axi_awsize,
		  output axi_awburst,
		  output axi_awlock,
		  output axi_awcache,
		  output axi_awprot,
		  output axi_awqos,
		  output axi_awregion,
		  output axi_awuser,
		  output axi_awvalid,
		  input axi_awready,

	      	  //output    axi_wid,
                  output    axi_wdata,
                  output    axi_wstrb,
                  output    axi_wlast,
                  output    axi_wuser,
                  output    axi_wvalid,
                  input     axi_wready,
              
                  input     axi_bid,
                  input     axi_bresp,
                  input     axi_buser,
                  input     axi_bvalid,
                  output    axi_bready
	  );

   modport slv(input axi_awid,
	   	  input axi_awaddr,
		  input axi_awlen,
		  input axi_awsize,
		  input axi_awburst,
		  input axi_awlock,
		  input axi_awcache,
		  input axi_awprot,
		  input axi_awqos,
		  input axi_awregion,
		  input axi_awuser,
		  input axi_awvalid,
		  output axi_awready,

	      	  //input    axi_wid,
                  input    axi_wdata,
                  input    axi_wstrb,
                  input    axi_wlast,
                  input    axi_wuser,
                  input    axi_wvalid,
                  output     axi_wready,
              
                  output     axi_bid,
                  output     axi_bresp,
                  output     axi_buser,
                  output     axi_bvalid,
                  input    axi_bready
	  );	  
endinterface
   
// An AXI4 interface.
interface HACD_AXI_XBAR_RD_BUS #(
  //parameter AXI_ADDR_WIDTH = -1,
  //parameter AXI_DATA_WIDTH = -1,
  //parameter AXI_ID_WIDTH   = -1,
  //parameter AXI_USER_WIDTH = -1
);

    // AXI Read Address Channel Signals
     logic  [`HACD_MC_AXI4_ID_WIDTH     -1:0]    axi_arid;
     logic  [`HACD_AXI4_ADDR_WIDTH   -1:0]    axi_araddr;
     logic  [`HACD_AXI4_LEN_WIDTH    -1:0]    axi_arlen;
     logic  [`HACD_AXI4_SIZE_WIDTH   -1:0]    axi_arsize;
     logic  [`HACD_AXI4_BURST_WIDTH  -1:0]    axi_arburst;
     logic                               axi_arlock;
     logic  [`HACD_AXI4_CACHE_WIDTH  -1:0]    axi_arcache;
     logic  [`HACD_AXI4_PROT_WIDTH   -1:0]    axi_arprot;
     logic  [`HACD_AXI4_QOS_WIDTH    -1:0]    axi_arqos;
     logic  [`HACD_AXI4_REGION_WIDTH -1:0]    axi_arregion;
     logic  [`HACD_AXI4_USER_WIDTH   -1:0]    axi_aruser;
     logic                               axi_arvalid;
     logic                               axi_arready;

    // AXI Read Data Channel Signals
     logic  [`HACD_MC_AXI4_ID_WIDTH     -1:0]    axi_rid;
     logic  [`HACD_AXI4_DATA_WIDTH   -1:0]    axi_rdata;
     logic  [`HACD_AXI4_RESP_WIDTH   -1:0]    axi_rresp;
     logic                               axi_rlast;
     logic  [`HACD_AXI4_USER_WIDTH   -1:0]    axi_ruser;
     logic                               axi_rvalid;
     logic                               axi_rready;


   modport mstr(output axi_arid,
	   	  output axi_araddr,
		  output axi_arlen,
		  output axi_arsize,
		  output axi_arburst,
		  output axi_arlock,
		  output axi_arcache,
		  output axi_arprot,
		  output axi_arqos,
		  output axi_arregion,
		  output axi_aruser,
		  output axi_arvalid,
		  input axi_arready,

	      	  input axi_rid,
                  input axi_rdata,
                  input axi_rresp,
                  input axi_rlast,
                  input axi_ruser,
                  input axi_rvalid,
                  output axi_rready
	  );
   
   modport slv(input axi_arid,
	   	  input axi_araddr,
		  input axi_arlen,
		  input axi_arsize,
		  input axi_arburst,
		  input axi_arlock,
		  input axi_arcache,
		  input axi_arprot,
		  input axi_arqos,
		  input axi_arregion,
		  input axi_aruser,
		  input axi_arvalid,
		  output axi_arready,

	      	  output axi_rid,
                  output axi_rdata,
                  output axi_rresp,
                  output axi_rlast,
                  output axi_ruser,
                  output axi_rvalid,
                  input axi_rready
	  );

endinterface
