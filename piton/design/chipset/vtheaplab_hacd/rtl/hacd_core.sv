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
   hacd_pkg::axi_rd_rdypkt_t rd_rdypkt;
   hacd_pkg::axi_rd_reqpkt_t rd_reqpkt;
   hacd_pkg::axi_rd_resppkt_t rd_resppkt;

   hawk_pgwr_mngr u_hawk_pgwr_mngr (.*);  

   HACD_AXI_WR_BUS hawk_axi_wr_bus();
   HACD_AXI_RD_BUS hawk_axi_rd_bus();

//////Hawk Read Master
    hawk_axird_master u_hawk_axird_mstr (
      .clk(clk_i),
      .rst(!rst_ni),
    
     .s_axi_arid('d0),//in-order for now
     .s_axi_araddr(rd_reqpkt.addr),
     .s_axi_arlen('d0), //fix to 1 beat always for hawk now
     .s_axi_arsize(`HACD_AXI4_BURST_SIZE),
     .s_axi_arburst(`HACD_AXI4_BURST_TYPE),
     .s_axi_arlock('d0),
     .s_axi_arcache('d0),
     .s_axi_arprot(3'b010),
     .s_axi_arqos('d0),
     .s_axi_arregion('d0),
     .s_axi_aruser('d0),
     .s_axi_arvalid(rd_reqpkt.arvalid),
     .s_axi_arready(rd_rdypkt.arready),
     .s_axi_rid('d0),
     .s_axi_rdata(rd_resppkt.rdata),
     .s_axi_rresp(rd_resppkt.rresp),
     .s_axi_rlast(rd_resppkt.rlast),
     .s_axi_ruser(), //not used for now
     .s_axi_rvalid(rd_resppkt.rvalid),
     .s_axi_rready(rd_rdypkt.rready),

     .m_axi_arid(hawk_axi_rd_bus.axi_arid),
     .m_axi_araddr(hawk_axi_rd_bus.axi_araddr),
     .m_axi_arlen(hawk_axi_rd_bus.axi_arlen),
     .m_axi_arsize(hawk_axi_rd_bus.axi_arsize),
     .m_axi_arburst(hawk_axi_rd_bus.axi_arburst),
     .m_axi_arlock(hawk_axi_rd_bus.axi_arlock),
     .m_axi_arcache(hawk_axi_rd_bus.axi_arcache),
     .m_axi_arprot(hawk_axi_rd_bus.axi_arprot),
     .m_axi_arqos(hawk_axi_rd_bus.axi_arqos),
     .m_axi_arregion(hawk_axi_rd_bus.axi_arregion),
     .m_axi_aruser(hawk_axi_rd_bus.axi_aruser),
     .m_axi_arvalid(hawk_axi_rd_bus.axi_arvalid),
     .m_axi_arready(hawk_axi_rd_bus.axi_arready),
     .m_axi_rid(hawk_axi_rd_bus.axi_rid),
     .m_axi_rdata(hawk_axi_rd_bus.axi_rdata),
     .m_axi_rresp(hawk_axi_rd_bus.axi_rresp),
     .m_axi_rlast(hawk_axi_rd_bus.axi_rlast),
     .m_axi_ruser(hawk_axi_rd_bus.axi_ruser),
     .m_axi_rvalid(hawk_axi_rd_bus.axi_rvalid),
     .m_axi_rready(hawk_axi_rd_bus.axi_rready)
);

   //HAWK Axi Master //Page Writer
     hawk_axiwr_master hawk_axiwr_mstr (
	.clk(clk_i),
	.rst(!rst_ni),
	.s_axi_wdata(wr_reqpkt.data), 	      //wr_blk_data), 	 //from hk_pgwr_manager
        .s_axi_wstrb(wr_reqpkt.strb),
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
    hacd_pkg::cpu_rd_reqpkt_t cpu_rd_reqpkt; 
    hacd_pkg::cpu_wr_reqpkt_t cpu_wr_reqpkt; 
   //hawk main control unit
   hawk_ctrl_unit #() u_hawk_cu 
   (
	//Inputs
	.clk_i,
	.rst_ni,

    	//pg_writer handshake
	.init_att_done,
	.init_list_done,
	.tbl_update_done,

        //pg_rdmanager
    	.pgrd_mngr_ready,
    	.allow_cpu_access,
    	.tbl_update,

    	//cpu master handshake
	.cpu_rd_reqpkt,
	.cpu_wr_reqpkt,

	//controls
	.init_att,
	.init_list,
	.allow_cpu_rd_access,
	.allow_cpu_wr_access
   );



   //Arbiter between Hawk Master and CPU master
	
   //For phase-1 birngup, I consider to implemtn just Mux, so either one of
   //them is active at any given time. Later we may be need crossbar/arbiter
   //and should support out-order transactions from DDR controller
   //to enhance performance of whole system
   //below module also includes downsizer to be compatible with DDR controller data
   //width of geensys2 board (256 bits). But HAWK always work on cachelines (512 bits)
   
   //wire rd_mstr_sel;
   //wire wr_mstr_sel;
   //assign rd_mstr_sel= allow_cpu_rd_access; 
   //assign wr_mstr_sel= allow_cpu_wr_access; 

   hawk_axi_xbar_wrapper#() u_axi_xbar_wrpr (

	.clk_i,
	.rst_ni,
	.mstr_sel(1'b0), //not used

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



