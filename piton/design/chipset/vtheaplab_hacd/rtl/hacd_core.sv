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
    HACD_MC_AXI_RD_BUS.mstr mc_axi_rd_bus,

    output wire dump_mem 
    );

   //TOL Head tail broadcasted
   hacd_pkg::hawk_tol_ht_t tol_HT;
   //hawk_pgwrite manager
   logic init_att,init_list,init_att_done,init_list_done;
   hacd_pkg::axi_wr_rdypkt_t wr_rdypkt;
   hacd_pkg::axi_wr_reqpkt_t wr_reqpkt;
   hacd_pkg::axi_wr_resppkt_t wr_resppkt;
   //
   hawk_pgwr_mngr u_hawk_pgwr_mngr (.*);  
   //

   //rd manager
   hacd_pkg::att_lkup_reqpkt_t lkup_reqpkt;
   hacd_pkg::axi_rd_rdypkt_t rd_rdypkt;
   hacd_pkg::axi_rd_reqpkt_t rd_reqpkt;
   hacd_pkg::axi_rd_resppkt_t rd_resppkt;
   hacd_pkg::trnsl_reqpkt_t trnsl_reqpkt;
   hacd_pkg::tol_updpkt_t tol_updpkt;

   wire pgrd_mngr_ready;
   wire pgwr_mngr_ready;
   hawk_pgrd_mngr u_hawk_pgrd_mngr (.*);  

   HACD_AXI_WR_BUS hawk_axi_wr_bus();
   HACD_AXI_RD_BUS hawk_axi_rd_bus();


   HACD_AXI_WR_BUS stall_axi_wr_bus(); 
   HACD_AXI_RD_BUS stall_axi_rd_bus();
  
   hacd_pkg::hawk_cpu_ovrd_pkt_t hawk_cpu_ovrd_rdpkt,hawk_cpu_ovrd_wrpkt;
   hacd_pkg::cpu_reqpkt_t cpu_rd_reqpkt,cpu_wr_reqpkt;
///hawk cpu rd stall
hawk_cpu_stall_rd u_hawk_cpu_stall_rd (
    .clk(clk_i),
    .rst(!rst_ni),

    /*hawk interface*/
    .hawk_cpu_ovrd_pkt(hawk_cpu_ovrd_rdpkt),
    .cpu_reqpkt(cpu_rd_reqpkt),
    .hawk_inactive(1'b1), //disabling for now 

    /*
     * AXI slave interface
     */
    .s_axi_arid(cpu_axi_rd_bus.axi_arid),
    .s_axi_araddr(cpu_axi_rd_bus.axi_araddr),
    .s_axi_arlen(cpu_axi_rd_bus.axi_arlen),
    .s_axi_arsize(cpu_axi_rd_bus.axi_arsize),
    .s_axi_arburst(cpu_axi_rd_bus.axi_arburst),
    .s_axi_arlock(cpu_axi_rd_bus.axi_arlock),
    .s_axi_arcache(cpu_axi_rd_bus.axi_arcache),
    .s_axi_arprot(cpu_axi_rd_bus.axi_arprot),
    .s_axi_arqos(cpu_axi_rd_bus.axi_arqos),
    .s_axi_arregion(cpu_axi_rd_bus.axi_arregion),
    .s_axi_aruser(cpu_axi_rd_bus.axi_aruser),
    .s_axi_arvalid(cpu_axi_rd_bus.axi_arvalid),
    .s_axi_arready(cpu_axi_rd_bus.axi_arready),
    .s_axi_rid(cpu_axi_rd_bus.axi_rid),
    .s_axi_rdata(cpu_axi_rd_bus.axi_rdata),
    .s_axi_rresp(cpu_axi_rd_bus.axi_rresp),
    .s_axi_rlast(cpu_axi_rd_bus.axi_rlast),
    .s_axi_ruser(cpu_axi_rd_bus.axi_ruser),
    .s_axi_rvalid(cpu_axi_rd_bus.axi_rvalid),
    .s_axi_rready(cpu_axi_rd_bus.axi_rready),

    /*
     * AXI master interface
     */
    .m_axi_arid(stall_axi_rd_bus.axi_arid),
    .m_axi_araddr(stall_axi_rd_bus.axi_araddr),
    .m_axi_arlen(stall_axi_rd_bus.axi_arlen),
    .m_axi_arsize(stall_axi_rd_bus.axi_arsize),
    .m_axi_arburst(stall_axi_rd_bus.axi_arburst),
    .m_axi_arlock(stall_axi_rd_bus.axi_arlock),
    .m_axi_arcache(stall_axi_rd_bus.axi_arcache),
    .m_axi_arprot(stall_axi_rd_bus.axi_arprot),
    .m_axi_arqos(stall_axi_rd_bus.axi_arqos),
    .m_axi_arregion(stall_axi_rd_bus.axi_arregion),
    .m_axi_aruser(stall_axi_rd_bus.axi_aruser),
    .m_axi_arvalid(stall_axi_rd_bus.axi_arvalid),
    .m_axi_arready(stall_axi_rd_bus.axi_arready),
    .m_axi_rid(stall_axi_rd_bus.axi_rid),
    .m_axi_rdata(stall_axi_rd_bus.axi_rdata),
    .m_axi_rresp(stall_axi_rd_bus.axi_rresp),
    .m_axi_rlast(stall_axi_rd_bus.axi_rlast),
    .m_axi_ruser(stall_axi_rd_bus.axi_ruser),
    .m_axi_rvalid(stall_axi_rd_bus.axi_rvalid),
    .m_axi_rready(stall_axi_rd_bus.axi_rready)

);

assign stall_axi_rd_bus.axi_rid[5]=1'b0;
assign stall_axi_wr_bus.axi_bid[5]=1'b0;

///hawk cpu wr stall
hawk_cpu_stall_wr u_hawk_cpu_stall_wr (
    .clk(clk_i),
    .rst(!rst_ni),

    /*hawk interface*/
    .hawk_cpu_ovrd_pkt(hawk_cpu_ovrd_wrpkt),
    .cpu_reqpkt(cpu_wr_reqpkt),
    .hawk_inactive(1'b1), //disabling for now 
 
    /*
     * AXI slave interface
     */
    .s_axi_awid(cpu_axi_wr_bus.axi_awid),
    .s_axi_awaddr(cpu_axi_wr_bus.axi_awaddr),
    .s_axi_awlen(cpu_axi_wr_bus.axi_awlen),
    .s_axi_awsize(cpu_axi_wr_bus.axi_awsize),
    .s_axi_awburst(cpu_axi_wr_bus.axi_awburst),
    .s_axi_awlock(cpu_axi_wr_bus.axi_awlock),
    .s_axi_awcache(cpu_axi_wr_bus.axi_awcache),
    .s_axi_awprot(cpu_axi_wr_bus.axi_awprot),
    .s_axi_awqos(cpu_axi_wr_bus.axi_awqos),
    .s_axi_awregion(cpu_axi_wr_bus.axi_awregion),
    .s_axi_awuser(cpu_axi_wr_bus.axi_awuser),
    .s_axi_awvalid(cpu_axi_wr_bus.axi_awvalid),
    .s_axi_awready(cpu_axi_wr_bus.axi_awready),
    .s_axi_wdata(cpu_axi_wr_bus.axi_wdata),
    .s_axi_wstrb(cpu_axi_wr_bus.axi_wstrb),
    .s_axi_wlast(cpu_axi_wr_bus.axi_wlast),
    .s_axi_wuser(cpu_axi_wr_bus.axi_wuser),
    .s_axi_wvalid(cpu_axi_wr_bus.axi_wvalid),
    .s_axi_wready(cpu_axi_wr_bus.axi_wready),
    .s_axi_bid(cpu_axi_wr_bus.axi_bid),
    .s_axi_bresp(cpu_axi_wr_bus.axi_bresp),
    .s_axi_buser(cpu_axi_wr_bus.axi_buser),
    .s_axi_bvalid(cpu_axi_wr_bus.axi_bvalid),
    .s_axi_bready(cpu_axi_wr_bus.axi_bready),

    /*
     * AXI master interface
     */
    .m_axi_awid(stall_axi_wr_bus.axi_awid),
    .m_axi_awaddr(stall_axi_wr_bus.axi_awaddr),
    .m_axi_awlen(stall_axi_wr_bus.axi_awlen),
    .m_axi_awsize(stall_axi_wr_bus.axi_awsize),
    .m_axi_awburst(stall_axi_wr_bus.axi_awburst),
    .m_axi_awlock(stall_axi_wr_bus.axi_awlock),
    .m_axi_awcache(stall_axi_wr_bus.axi_awcache),
    .m_axi_awprot(stall_axi_wr_bus.axi_awprot),
    .m_axi_awqos(stall_axi_wr_bus.axi_awqos),
    .m_axi_awregion(stall_axi_wr_bus.axi_awregion),
    .m_axi_awuser(stall_axi_wr_bus.axi_awuser),
    .m_axi_awvalid(stall_axi_wr_bus.axi_awvalid),
    .m_axi_awready(stall_axi_wr_bus.axi_awready),
    .m_axi_wdata(stall_axi_wr_bus.axi_wdata),
    .m_axi_wstrb(stall_axi_wr_bus.axi_wstrb),
    .m_axi_wlast(stall_axi_wr_bus.axi_wlast),
    .m_axi_wuser(stall_axi_wr_bus.axi_wuser),
    .m_axi_wvalid(stall_axi_wr_bus.axi_wvalid),
    .m_axi_wready(stall_axi_wr_bus.axi_wready),
    .m_axi_bid(stall_axi_wr_bus.axi_bid),
    .m_axi_bresp(stall_axi_wr_bus.axi_bresp),
    .m_axi_buser(stall_axi_wr_bus.axi_buser),
    .m_axi_bvalid(stall_axi_wr_bus.axi_bvalid),
    .m_axi_bready(stall_axi_wr_bus.axi_bready)
);
//////Hawk Read Master
    hawk_axird_master u_hawk_axird_mstr (
      .clk(clk_i),
      .rst(!rst_ni),
    
     .s_axi_arid(6'd0),//in-order for now
     .s_axi_araddr(rd_reqpkt.addr),
     .s_axi_arlen(8'd0), //fix to 1 beat always for hawk now
     .s_axi_arsize(`HACD_AXI4_BURST_SIZE),
     .s_axi_arburst(`HACD_AXI4_BURST_TYPE),
     .s_axi_arlock(1'd0),
     .s_axi_arcache(4'd0),
     .s_axi_arprot(3'b010),
     .s_axi_arqos(4'd0),
     .s_axi_arregion(4'd0),
     .s_axi_aruser(11'd0),
     .s_axi_arvalid(rd_reqpkt.arvalid),
     .s_axi_arready(rd_rdypkt.arready),
     .s_axi_rid(6'd0),//in-order for now
     .s_axi_rdata(rd_resppkt.rdata),
     .s_axi_rresp(rd_resppkt.rresp),
     .s_axi_rlast(rd_resppkt.rlast),
     .s_axi_ruser(), //not used for now
     .s_axi_rvalid(rd_resppkt.rvalid),
     .s_axi_rready(rd_reqpkt.rready),

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
        .s_axi_bready(1'b1), //wr_reqpkt.bready),
	.s_axi_bresp(wr_resppkt.bresp),
	.s_axi_bvalid(wr_resppkt.bvalid),
	
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

     //assign mc_axi_wr_bus.axi_wid='d0;
      
  
   wire tbl_update_done;
   //controls from cu to cpu master
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
	.trnsl_reqpkt,
	.tol_updpkt,
	.lkup_reqpkt,

    	//cpu master handshake
	.cpu_rd_reqpkt,
	.cpu_wr_reqpkt,

	//controls
	.init_att,
	.init_list,

	.hawk_cpu_ovrd_rdpkt,
	.hawk_cpu_ovrd_wrpkt
   );



   //Arbiter between Hawk Master and CPU master
	
   //For phase-1 birngup, I consider to implemtn just Mux, so either one of
   //them is active at any given time. Later we may be need crossbar/arbiter
   //and should support out-order transactions from DDR controller
   //to enhance performance of whole system
   //below module also includes downsizer to be compatible with DDR controller data
   //width of geensys2 board (256 bits). But HAWK always work on cachelines (512 bits)
   

   hawk_axi_xbar_wrapper#() u_axi_xbar_wrpr (

	.clk_i,
	.rst_ni,
	.mstr_sel(1'b0), //not used

	//From Hawk
 	.mstr0_axi_wr_bus_slv(hawk_axi_wr_bus.slv),
 	.mstr0_axi_rd_bus_slv(hawk_axi_rd_bus.slv),

	//From CPU
	.mstr1_axi_wr_bus_slv(stall_axi_wr_bus.slv),
	.mstr1_axi_rd_bus_slv(stall_axi_rd_bus.slv),

	//Towards memory controller   
   	.out_axi_wr_bus(mc_axi_wr_bus),
   	.out_axi_rd_bus(mc_axi_rd_bus)
   );






endmodule



