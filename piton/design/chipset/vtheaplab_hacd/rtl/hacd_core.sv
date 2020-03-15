/////////////////////////////////////////////////////////////////////////////////
//
// Heap Lab Research
// Block: Hardware Accelerated Compressor Decompressor Core
// 
// Author : Raghavendra Srinivas
// Contact : raghavs@vt.edu	
/////////////////////////////////////////////////////////////////////////////////
// Description: module to encapsulate all module instantiation to
// support hardware accelerated compression/decompression
/////////////////////////////////////////////////////////////////////////////////
`include "hacd_define.vh"
import hacd_pkg::*;

module hacd_core (

    input clk_i,
    input rst_ni,
   
    //CPU<->HACD
    //hacd will observe these for request signals from cpu
    HACD_AXI_WR_BUS.slv cpu_axi_wr_bus, 
    HACD_AXI_RD_BUS.slv cpu_axi_rd_bus,  
    
    //HACD<->MC
    //hacd will act as request master on request singslas to mc 
    HACD_MC_AXI_WR_BUS.mstr mc_axi_wr_bus,  
    HACD_MC_AXI_RD_BUS.mstr mc_axi_rd_bus  
    );


   //hawk_pgwrite manager
   wire init_att,init_list,init_att_done,init_list_done;
   hacd_pkg::axi_wr_rdypkt_t wr_rdypkt;
   hacd_pkg::axi_wr_reqpkt_t wr_reqpkt;

   hawk_pgwr_mngr u_hawk_pgwr_mngr (.*);  

   HACD_AXI_WR_BUS hawk_axi_wr_bus();
   HACD_AXI_RD_BUS hawk_axi_rd_bus();

   //HAWK Axi Master //Page Writer
     hacd_axi_master hacd_axi_mstr (
	.clk(clk_i),
	.rst(!rst_ni),
	.s_axi_wdata(wr_reqpkt.data), 	      //wr_blk_data), 	 //from hk_pgwr_manager
	.s_axi_wvalid(wr_reqpkt.wvalid),      //wr_blk_vld), 	 //from hk_pgwr_manager
	.s_axi_wready(wr_rdypkt.wready),      //wr_data_fifo_ready),
	.s_axi_awaddr(wr_reqpkt.addr),        //wr_blk_adrr), 	 //from hk_pgwr_manager
	.s_axi_awvalid(wr_reqpkt.awvalid),    //wr_blk_addr_vld), //from hk_pgwr_manager
	.s_axi_awready(wr_rdypkt.awready),    //wr_addr_fifo_ready),
	
        .m_axi_awid(hawk_axi_wr_bus.axi_awid),
        .m_axi_awaddr(hawk_axi_wr_bus.axi_awaddr),
        .m_axi_awlen(hawk_axi_wr_bus.axi_awlen),
        .m_axi_awsize(hawk_axi_wr_bus.axi_awsize),
        .m_axi_awburst(hawk_axi_wr_bus.axi_awburst),
        .m_axi_awlock(hawk_axi_wr_bus.axi_awlock),
        .m_axi_awcache(hawk_axi_wr_bus.axi_awcache),
        .m_axi_awprot(hawk_axi_wr_bus.axi_awprot),
        .m_axi_awqos(hawk_axi_wr_bus.axi_awqos),
        .m_axi_awregion(hawk_axi_wr_bus.axi_awregion),
        .m_axi_awuser(hawk_axi_wr_bus.axi_awuser),
        .m_axi_awvalid(hawk_axi_wr_bus.axi_awvalid),
        .m_axi_awready(hawk_axi_wr_bus.axi_awready),
        .m_axi_wdata(hawk_axi_wr_bus.axi_wdata),
        .m_axi_wstrb(hawk_axi_wr_bus.axi_wstrb),
        .m_axi_wlast(hawk_axi_wr_bus.axi_wlast),
        .m_axi_wuser(hawk_axi_wr_bus.axi_wuser),
        .m_axi_wvalid(hawk_axi_wr_bus.axi_wvalid),
        .m_axi_wready(hawk_axi_wr_bus.axi_wready),
        .m_axi_bid(hawk_axi_wr_bus.axi_bid),
        .m_axi_bresp(hawk_axi_wr_bus.axi_bresp),
        .m_axi_buser(hawk_axi_wr_bus.axi_buser),
        .m_axi_bvalid(hawk_axi_wr_bus.axi_bvalid),
        .m_axi_bready(hawk_axi_wr_bus.axi_bready)
     );

     assign mc_axi_wr_bus.axi_wid='d0;
      
  
   //CPU Master  
   //controls from cu to cpu master
   wire hold_cpu;  

   wire cpu_vld_access;
   assign cpu_vld_access = 1'b0; // cpu_rd_vld | cpu_wr_vld;

   //pg_writer contrls from cu
   wire hold_hwk_wr;
   //hawk main control unit
   hawk_ctrl_unit #() u_hawk_cu 
   (
	//Inputs
	.clk_i,
	.rst_ni,
	.init_att_done,
	.init_list_done,

	.cpu_vld_access,

	//controls
	.init_att,
	.init_list,
	.hold_hwk_wr,
	.hold_cpu
   );




   //CPU master








   //Arbiter between Hawk Master and CPU master
	
   //For phase-1 birngup, I consider to implemtn just Mux, so either one of
   //them is active at any given time. Later we may be need crossbar/arbiter
   //and should supporot out-order transactions from DDR controller
   //to enhance performance of whole system
   //This also includes downsizer to be compatible with DDR controller data
   //width of geensys2 board (256 bits). But we work on cachelines (512 bits)
   
   wire mstr_sel;
   assign mstr_sel= !hold_cpu && hold_hwk_wr; //cpu can become master only it is not on hold and hawk is on hold 

   hawk_axi_xbar_wrapper#() u_axi_xbar_wrpr (

	.clk_i,
	.rst_ni,
	.mstr_sel,

	//From Hawk
 	.mstr0_axi_wr_bus_slv(hawk_axi_wr_bus.slv),
 	.mstr0_axi_rd_bus_slv(hawk_axi_rd_bus.slv),

	//From CPU
	.mstr1_axi_wr_bus_slv(cpu_axi_wr_bus),
	.mstr1_axi_rd_bus_slv(cpu_axi_rd_bus),

	//Towards memory controller   
   	.out_axi_wr_bus(mc_axi_wr_bus),
   	.out_axi_rd_bus(mc_axi_rd_bus)
   );






endmodule



