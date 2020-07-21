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
    input [1:0] hawk_sw_ctrl,
    input hawk_reg_inactive_ctrl, 
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
   wire tbl_update_done;


   //rd manager
   hacd_pkg::att_lkup_reqpkt_t lkup_reqpkt;
   hacd_pkg::axi_rd_rdypkt_t rd_rdypkt;
   hacd_pkg::axi_rd_reqpkt_t rd_reqpkt;
   hacd_pkg::axi_rd_resppkt_t rd_resppkt;
   hacd_pkg::trnsl_reqpkt_t trnsl_reqpkt;
   hacd_pkg::tol_updpkt_t tol_updpkt;

   wire pgrd_mngr_ready;
   wire pgwr_mngr_ready;

   wire [13:0] comp_size;
   wire comp_start;
   wire comp_done;
   wire decomp_start;
   wire decomp_done;
   wire zspg_updated;
   wire zspg_migrated;
   hacd_pkg::iWayORcPagePkt_t iWayORcPagePkt;
   hacd_pkg::zsPageMigratePkt_t zspg_mig_pkt;

   wire rdfifo_rdptr_rst,rdfifo_wrptr_rst,rdfifo_empty,rdfifo_full,wrfifo_empty,wrfifo_full;
   assign rdfifo_rdptr_rst = 1'b0;
   assign rdfifo_wrptr_rst = 1'b0;


   wire rdm_reset;
   wire [3:0] prm_state;
   hacd_pkg::debug_pgrd_cmp_mngr debug_cmp_mngr;	
   hawk_pgrd_mngr u_hawk_pgrd_mngr (.*);  

   //
   wire [3:0] pwm_state;
   hacd_pkg::debug_pgwr_cmpdcmp_mngr debug_cmpdcmp_mngr;
   hawk_pgwr_mngr u_hawk_pgwr_mngr (.*);  
   //

   hacd_pkg::stall_debug_bus stall_rd_dbg_bus;
   hacd_pkg::stall_debug_bus stall_wr_dbg_bus;
   HACD_AXI_WR_BUS hawk_axi_wr_bus();
   HACD_AXI_RD_BUS hawk_axi_rd_bus();


   HACD_AXI_WR_BUS stall_axi_wr_bus(); 
   HACD_AXI_RD_BUS stall_axi_rd_bus();
 
   hacd_pkg::hawk_cpu_ovrd_pkt_t hawk_cpu_ovrd_rdpkt,hawk_cpu_ovrd_wrpkt;
   hacd_pkg::cpu_reqpkt_t cpu_rd_reqpkt,cpu_wr_reqpkt;


//hawk cpu rd stall
hawk_cpu_stall_rd u_hawk_cpu_stall_rd (
    .clk(clk_i),
    .rst(!rst_ni),

    /*hawk interface*/
    .hawk_cpu_ovrd_pkt(hawk_cpu_ovrd_rdpkt),
    .cpu_reqpkt(cpu_rd_reqpkt),
    .hawk_inactive(hawk_sw_ctrl[0] || hawk_reg_inactive_ctrl), //disabling for now 

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

     //Response
    .m_axi_rid(stall_axi_rd_bus.axi_rid),
    .m_axi_rdata(stall_axi_rd_bus.axi_rdata),
    .m_axi_rresp(stall_axi_rd_bus.axi_rresp),
    .m_axi_rlast(stall_axi_rd_bus.axi_rlast),
    .m_axi_ruser(stall_axi_rd_bus.axi_ruser),
    .m_axi_rvalid(stall_axi_rd_bus.axi_rvalid),
    .m_axi_rready(stall_axi_rd_bus.axi_rready),

    .stall_rd_dbg_bus(stall_rd_dbg_bus)

);


///hawk cpu wr stall

hawk_cpu_stall_wr u_hawk_cpu_stall_wr (
    .clk(clk_i),
    .rst(!rst_ni),

    /*hawk interface*/
    .hawk_cpu_ovrd_pkt(hawk_cpu_ovrd_wrpkt),
    .cpu_reqpkt(cpu_wr_reqpkt),
    .hawk_inactive(hawk_sw_ctrl[0] || hawk_reg_inactive_ctrl), //disabling for now 
 
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

     //Response	
    .m_axi_bid(stall_axi_wr_bus.axi_bid),
    .m_axi_bresp(stall_axi_wr_bus.axi_bresp),
    .m_axi_buser(stall_axi_wr_bus.axi_buser),
    .m_axi_bvalid(stall_axi_wr_bus.axi_bvalid),
    .m_axi_bready(stall_axi_wr_bus.axi_bready),
    
    .stall_wr_dbg_bus(stall_wr_dbg_bus)
);


wire compdecomp_rready;
wire [`FIFO_PTR_WIDTH-1:0] comdecomp_rdfifo_rdptr;
wire comdecomp_ld_rdfifo_rdptr;
//for now, addign mux for read channel from axird master 
logic axird_master_rready,axird_master_rvalid;
logic comp_decomp_rd_valid;
always@* begin
 if(comp_start || decomp_start) begin //rready from comp_decmp unit and rdata goes to it
	axird_master_rready  = compdecomp_rready;	
        comp_decomp_rd_valid = axird_master_rvalid; 
        rd_resppkt.rvalid = 1'b0;
	
 end else begin
   	axird_master_rready = rd_reqpkt.rready;  
	comp_decomp_rd_valid = 1'b0;
	rd_resppkt.rvalid = axird_master_rvalid;
 end
end

logic compdecomp_wr_valid,axiwr_master_wvalid;
logic [`HACD_AXI4_STRB_WIDTH -1:0] compdecomp_wr_strb,axiwr_master_wstrb;
logic  [`HACD_AXI4_DATA_WIDTH-1:0] compdecomp_wr_data,axiwr_master_wdata;

//Mux between compdecomp unit and hawk to access write FIFO
`ifdef HAWK_NAIVE_COMPRESSION
always@* begin
 if(comp_start || decomp_start) begin //rready from comp_decmp unit and rdata goes to it
        axiwr_master_wvalid = compdecomp_wr_valid;
	axiwr_master_wstrb  = compdecomp_wr_strb;
	axiwr_master_wdata =  compdecomp_wr_data;
 end else begin
        axiwr_master_wvalid = wr_reqpkt.wvalid; 
	axiwr_master_wstrb  = wr_reqpkt.strb;
	axiwr_master_wdata =  wr_reqpkt.data;
 end
end
`else
        assign axiwr_master_wvalid = wr_reqpkt.wvalid; 
	assign axiwr_master_wstrb  = wr_reqpkt.strb;
	assign axiwr_master_wdata =  wr_reqpkt.data;

`endif
hacd_pkg::debug_compressor debug_comp;
wire incompressible;

hawk_comdecomp u_hawk_comdecomp(
     .clk_i,
     .rst_ni,
     .comp_size,
     .comp_start,
     .comp_done,
     .incompressible,
     .decomp_start,
     .decomp_done,
     //.rdfifo_rdptr_rst,
     .rdfifo_empty,
     .wrfifo_full,
     .compdecomp_rready,
     .rd_data(rd_resppkt.rdata),
     .rd_rresp(rd_resppkt.rresp),
     .rd_valid(comp_decomp_rd_valid),
     .compdecomp_rdfifo_rdptr(comdecomp_rdfifo_rdptr),
     .compdecomp_ld_rdfifo_rdptr(comdecomp_ld_rdfifo_rdptr),

     //WrFifo interface
     .compdecomp_wr_req(compdecomp_wr_valid),
     .compdecomp_wr_strb(compdecomp_wr_strb),
     .compdecomp_wr_data(compdecomp_wr_data),

     .debug_comp
);



    hacd_pkg::debug_rdfifo   debug_rdfifo;
//////Hawk Read Master
    hawk_axird_master u_hawk_axird_mstr (
      .clk(clk_i),
      .rst(!rst_ni || rdm_reset),
   
      //compressoer interface
     .rdfifo_rdptr_rst(rdfifo_rdptr_rst),
     .rdfifo_wrptr_rst(rdfifo_wrptr_rst),
     .rdfifo_empty(rdfifo_empty),
     .rdfifo_full(rdfifo_full),
     .rdfifo_rdptr(comdecomp_rdfifo_rdptr),
     .ld_rdfifo_rdptr(comdecomp_ld_rdfifo_rdptr),
 
     .s_axi_arid(6'd0),//in-order for now
     .s_axi_araddr(rd_reqpkt.addr),
     .s_axi_arlen(rd_reqpkt.arlen), //fix to 1 beat always for hawk now
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
     .s_axi_rid(),//in-order for now
     .s_axi_rdata(rd_resppkt.rdata),
     .s_axi_rresp(rd_resppkt.rresp),
     .s_axi_rlast(rd_resppkt.rlast),
     .s_axi_ruser(), //not used for now
     .s_axi_rvalid(axird_master_rvalid), //rd_resppkt.rvalid),
     .s_axi_rready(axird_master_rready),

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
     .m_axi_rready(hawk_axi_rd_bus.axi_rready),
     
     .debug_rdfifo(debug_rdfifo)
);

    hacd_pkg::debug_wrfifo   debug_wrfifo;
   //HAWK Axi Master //Page Writer
     hawk_axiwr_master hawk_axiwr_mstr (
	.clk(clk_i),
	.rst(!rst_ni),
	.wrfifo_full,
	.wrfifo_empty,
	.s_axi_wdata(axiwr_master_wdata),   //(wr_reqpkt.data), 	      	 //from hk_pgwr_manager
        .s_axi_wstrb(axiwr_master_wstrb), 		    //(wr_reqpkt.strb),
	.s_axi_wvalid(axiwr_master_wvalid), //(wr_reqpkt.wvalid),       	 //from hk_pgwr_manager
	.s_axi_wready(wr_rdypkt.wready),      
	.s_axi_awaddr(wr_reqpkt.addr),         	 //from hk_pgwr_manager
	.s_axi_awvalid(wr_reqpkt.awvalid),     //from hk_pgwr_manager
	.s_axi_awready(wr_rdypkt.awready),    
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
        .m_axi_bready(hawk_axi_wr_bus.axi_bready),

        .debug_wrfifo(debug_wrfifo)
     );

     //assign mc_axi_wr_bus.axi_wid='d0;
      
  
   //controls from cu to cpu master
   //hawk main control unit
   wire cu_init_att,cu_init_list;
   wire [3:0] cu_state;
   hawk_ctrl_unit #() u_hawk_cu 
   (
	//Inputs
	.clk_i,
	.rst_ni,

    	//pg_writer handshake
	.init_att_done,
	.init_list_done,

        //pg_rdmanager
    	.pgrd_mngr_ready,
	.trnsl_reqpkt,
	.tol_updpkt,
	.lkup_reqpkt,

    	//cpu master handshake
	.cpu_rd_reqpkt,
	.cpu_wr_reqpkt,

	//controls
	.init_att(cu_init_att),
	.init_list(cu_init_list),

	.hawk_cpu_ovrd_rdpkt,
	.hawk_cpu_ovrd_wrpkt,
	
	.cu_state
   );

   assign  init_att = cu_init_att & (!hawk_sw_ctrl[0]);   // || !hawk_reg_inactive_ctrl);
   assign  init_list = cu_init_list & (!hawk_sw_ctrl[0]); // || !hawk_reg_inactive_ctrl);


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

	//.mstr1_axi_wr_bus_slv(cpu_axi_wr_bus),
	//.mstr1_axi_rd_bus_slv(cpu_axi_rd_bus),

	//Towards memory controller   
   	.out_axi_wr_bus(mc_axi_wr_bus),
   	.out_axi_rd_bus(mc_axi_rd_bus)
   );


`ifdef HAWK_FPGA //_DBG

/*
	//ILA debug
	ila_3 ila_3_hawk_ovrd_addr (
		.clk(clk_i),
		//.probe0({cpu_axi_wr_bus.axi_awaddr[62:0],cpu_axi_wr_bus.axi_awvalid}),
		//.probe1({hawk_cpu_ovrd_wrpkt.ppa,hawk_cpu_ovrd_wrpkt.allow_access})
		  .probe0({'d0,tol_HT.freeListHead[9:0],tol_HT.freeListTail[9:0],prm_state,pwm_state,cu_state}),
		  .probe1({
			'd0,hawk_sw_ctrl[1],
			tol_HT.uncompListHead[9:0],
			tol_HT.uncompListTail[9:0]
		})	
	);

	ila_3 ila_hawk_debug_states (
		.clk(clk_i),
		.probe0({cpu_axi_rd_bus.axi_araddr[30:0],cpu_axi_rd_bus.axi_arvalid,stall_axi_rd_bus.axi_araddr[30:0],stall_axi_rd_bus.axi_arvalid}),
		.probe1({hawk_sw_ctrl[1],cpu_axi_wr_bus.axi_awaddr[29:0],cpu_axi_wr_bus.axi_awvalid,stall_axi_wr_bus.axi_awaddr[30:0],stall_axi_wr_bus.axi_awvalid})
	);


     ila_0 debug_hawk_wr_rd
        (
         .clk(clk_i),
         .probe0(!rst_ni),
         .probe40(init_list_done),
         // Slave Interface Write Address Ports
         .probe19 (hawk_axi_wr_bus.axi_awid),  // input [5:0]          s_axi_awid
         .probe1  (hawk_axi_wr_bus.axi_awaddr),  // input [29:0]            s_axi_awaddr
         .probe21 (hawk_axi_wr_bus.axi_awlen),  // input [7:0]          s_axi_awlen
         .probe17 (hawk_axi_wr_bus.axi_awsize),  // input [2:0]         s_axi_awsize
         .probe2  (hawk_axi_wr_bus.axi_awburst),  // input [1:0]            s_axi_awburst
         .probe3  (hawk_axi_wr_bus.axi_awlock),  // input [0:0]         s_axi_awlock
         .probe31 (hawk_axi_wr_bus.axi_awcache),  // input [3:0]            s_axi_awcache
         .probe18 (hawk_axi_wr_bus.axi_awprot),  // input [2:0]         s_axi_awprot
         .probe32 (hawk_axi_wr_bus.axi_awqos),  // input [3:0]          s_axi_awqos
         .probe4  (hawk_axi_wr_bus.axi_awvalid),  // input          s_axi_awvalid
         .probe6  (hawk_axi_wr_bus.axi_awready),  // output         s_axi_awready
         // Slave Interface Write Data Ports
         .probe10 (hawk_axi_wr_bus.axi_wdata),  // input [255:0]            s_axi_wdata
         .probe15 (hawk_axi_wr_bus.axi_wstrb),  // input [31:0]         s_axi_wstrb
         .probe7 (hawk_axi_wr_bus.axi_wlast),  // input            s_axi_wlast
         .probe8 (hawk_axi_wr_bus.axi_wvalid),  // input           s_axi_wvalid
         .probe9 (hawk_axi_wr_bus.axi_wready),  // output          s_axi_wready
         // Slave Interface Write Response Ports
         .probe20 (hawk_axi_wr_bus.axi_bid),  // output [5:0]          s_axi_bid
         .probe13 (hawk_axi_wr_bus.axi_bresp),  // output [1:0]         s_axi_bresp
         .probe11 (hawk_axi_wr_bus.axi_bvalid),  // output          s_axi_bvalid
         .probe12 (hawk_axi_wr_bus.axi_bready),  // input           s_axi_bready
         // Slave Interface Read Address Ports
         .probe25 (hawk_axi_rd_bus.axi_arid),  // input [5:0]          s_axi_arid
         .probe5  (hawk_axi_rd_bus.axi_araddr),  // input [29:0]            s_axi_araddr
         .probe27 (hawk_axi_rd_bus.axi_arlen),  // input [7:0]          s_axi_arlen
         .probe23 (hawk_axi_rd_bus.axi_arsize),  // input [2:0]         s_axi_arsize
         .probe24 (hawk_axi_rd_bus.axi_arburst),  // input [1:0]            s_axi_arburst
         .probe22 (hawk_axi_rd_bus.axi_arlock),  // input [0:0]         s_axi_arlock
         .probe33 (hawk_axi_rd_bus.axi_arcache),  // input [3:0]            s_axi_arcache
         .probe28 (hawk_axi_rd_bus.axi_arprot),  // input [2:0]         s_axi_arprot
         .probe34 (hawk_axi_rd_bus.axi_arqos),  // input [3:0]          s_axi_arqos
         .probe16 (hawk_axi_rd_bus.axi_arvalid),  // input          s_axi_arvalid
         .probe26 (hawk_axi_rd_bus.axi_arready),  // output         s_axi_arready
         // Slave Interface Read Data Ports
         .probe38 (hawk_axi_rd_bus.axi_rid),  // output [5:0]          s_axi_rid
         .probe14 (hawk_axi_rd_bus.axi_rdata),  // output [255:0]           s_axi_rdata
         .probe29 (hawk_axi_rd_bus.axi_rresp),  // output [1:0]         s_axi_rresp
         .probe30(hawk_axi_rd_bus.axi_rlast),  // output           s_axi_rlast
         .probe35 (hawk_axi_rd_bus.axi_rvalid),  // output          s_axi_rvalid
         .probe39 (hawk_axi_rd_bus.axi_rready),  // input           s_axi_rready
     
         .probe41 (hawk_sw_ctrl[1]), //ddr_we_n),
         .probe42 ('d0),
         .probe43 ('d0),
     
         .probe36 ('d0),
         .probe37 ('d0)
     
     );


     //
     ila_0 debug_cpu_wr_rd
        (
         .clk(clk_i),
         .probe0(!rst_ni),
         .probe40(init_list_done),
         // Slave Interface Write Address Ports
         .probe19 (cpu_axi_wr_bus.axi_awid),  // input [5:0]          s_axi_awid
         .probe1  (cpu_axi_wr_bus.axi_awaddr),  // input [29:0]            s_axi_awaddr
         .probe21 (cpu_axi_wr_bus.axi_awlen),  // input [7:0]          s_axi_awlen
         .probe17 (cpu_axi_wr_bus.axi_awsize),  // input [2:0]         s_axi_awsize
         .probe2  (cpu_axi_wr_bus.axi_awburst),  // input [1:0]            s_axi_awburst
         .probe3  (cpu_axi_wr_bus.axi_awlock),  // input [0:0]         s_axi_awlock
         .probe31 (cpu_axi_wr_bus.axi_awcache),  // input [3:0]            s_axi_awcache
         .probe18 (cpu_axi_wr_bus.axi_awprot),  // input [2:0]         s_axi_awprot
         .probe32 (cpu_axi_wr_bus.axi_awqos),  // input [3:0]          s_axi_awqos
         .probe4  (cpu_axi_wr_bus.axi_awvalid),  // input          s_axi_awvalid
         .probe6  (cpu_axi_wr_bus.axi_awready),  // output         s_axi_awready
         // Slave Interface Write Data Ports
         .probe10 (cpu_axi_wr_bus.axi_wdata),  // input [255:0]            s_axi_wdata
         .probe15 (cpu_axi_wr_bus.axi_wstrb),  // input [31:0]         s_axi_wstrb
         .probe7 (cpu_axi_wr_bus.axi_wlast),  // input            s_axi_wlast
         .probe8 (cpu_axi_wr_bus.axi_wvalid),  // input           s_axi_wvalid
         .probe9 (cpu_axi_wr_bus.axi_wready),  // output          s_axi_wready
         // Slave Interface Write Response Ports
         .probe20 (cpu_axi_wr_bus.axi_bid),  // output [5:0]          s_axi_bid
         .probe13 (cpu_axi_wr_bus.axi_bresp),  // output [1:0]         s_axi_bresp
         .probe11 (cpu_axi_wr_bus.axi_bvalid),  // output          s_axi_bvalid
         .probe12 (cpu_axi_wr_bus.axi_bready),  // input           s_axi_bready
         // Slave Interface Read Address Ports
         .probe25 (cpu_axi_rd_bus.axi_arid),  // input [5:0]          s_axi_arid
         .probe5  (cpu_axi_rd_bus.axi_araddr),  // input [29:0]            s_axi_araddr
         .probe27 (cpu_axi_rd_bus.axi_arlen),  // input [7:0]          s_axi_arlen
         .probe23 (cpu_axi_rd_bus.axi_arsize),  // input [2:0]         s_axi_arsize
         .probe24 (cpu_axi_rd_bus.axi_arburst),  // input [1:0]            s_axi_arburst
         .probe22 (cpu_axi_rd_bus.axi_arlock),  // input [0:0]         s_axi_arlock
         .probe33 (cpu_axi_rd_bus.axi_arcache),  // input [3:0]            s_axi_arcache
         .probe28 (cpu_axi_rd_bus.axi_arprot),  // input [2:0]         s_axi_arprot
         .probe34 (cpu_axi_rd_bus.axi_arqos),  // input [3:0]          s_axi_arqos
         .probe16 (cpu_axi_rd_bus.axi_arvalid),  // input          s_axi_arvalid
         .probe26 (cpu_axi_rd_bus.axi_arready),  // output         s_axi_arready
         // Slave Interface Read Data Ports
         .probe38 (cpu_axi_rd_bus.axi_rid),  // output [5:0]          s_axi_rid
         .probe14 (cpu_axi_rd_bus.axi_rdata),  // output [255:0]           s_axi_rdata
         .probe29 (cpu_axi_rd_bus.axi_rresp),  // output [1:0]         s_axi_rresp
         .probe30(cpu_axi_rd_bus.axi_rlast),  // output           s_axi_rlast
         .probe35 (cpu_axi_rd_bus.axi_rvalid),  // output          s_axi_rvalid
         .probe39 (cpu_axi_rd_bus.axi_rready),  // input           s_axi_rready
     
         .probe41 (hawk_sw_ctrl[1]), //ddr_we_n),
         .probe42 ('d0),
         .probe43 ('d0),
     
         .probe36 ('d0),
         .probe37 ('d0)
     
     );
*/

ila_4 ila_hawk_ain1_debug (
   .clk(clk_i),//clk;
   .probe0('d0),//(cpu_axi_wr_bus.axi_awaddr[35:0]),  //[35:0]probe0;
   .probe1('d0),//(cpu_axi_wr_bus.axi_awvalid), //[0:0]probe1;
   .probe2('d0),//(cpu_axi_wr_bus.axi_awid),//[5:0]probe2;
   .probe3('d0),//(cpu_axi_wr_bus.axi_wdata),//[511:0]probe3;
   .probe4('d0),//(cpu_axi_wr_bus.axi_wvalid),//[0:0]probe4;
   .probe5('d0),//(cpu_axi_wr_bus.axi_bid),//[5:0]probe5;
   .probe6('d0),//(cpu_axi_wr_bus.axi_wstrb),//[63:0]probe6;
   .probe7('d0),//(cpu_axi_wr_bus.axi_bvalid),//[0:0]probe7;
   .probe8('d0),//(cpu_axi_wr_bus.axi_bresp),//[1:0]probe8;
   .probe9('d0),//(cpu_axi_wr_bus.axi_wlast),//[0:0]probe9;

   .probe10('d0),//(cpu_axi_rd_bus.axi_araddr[35:0]),//[35:0]probe10;
   .probe11('d0),//(cpu_axi_rd_bus.axi_arvalid),//[0:0]probe11;
   .probe12('d0),//(cpu_axi_rd_bus.axi_arid),//[5:0]probe12;
   .probe13('d0),//(cpu_axi_rd_bus.axi_rdata),//[511:0]probe13;
   .probe14('d0),//(cpu_axi_rd_bus.axi_rvalid),//[0:0]probe14;
   .probe15('d0),//(cpu_axi_rd_bus.axi_rlast),//[0:0]probe15;
   .probe16('d0),//(cpu_axi_rd_bus.axi_rresp),//[1:0]probe16;

   .probe17('d0),//(stall_axi_wr_bus.axi_awaddr[35:0]),  //[35:0]probe0;
   .probe18('d0),//(stall_axi_wr_bus.axi_awvalid), //[0:0]probe1;
   .probe19('d0),//(stall_axi_wr_bus.axi_awid),//[5:0]probe2;

   //.probe20(stall_axi_wr_bus.axi_wdata),//[511:0]probe3;
   .probe20({'d0, hawk_cpu_ovrd_wrpkt.ppa,hawk_cpu_ovrd_wrpkt.allow_access,tol_HT.uncompListHead,tol_HT.uncompListTail,stall_wr_dbg_bus.fsm_state,stall_wr_dbg_bus.overflow,stall_wr_dbg_bus.bus_error,stall_wr_dbg_bus.last_addr0,stall_wr_dbg_bus.last_addr1,stall_wr_dbg_bus.req_count0,stall_wr_dbg_bus.req_count1,stall_wr_dbg_bus.resp_count0,stall_wr_dbg_bus.resp_count1}),//[511:0]probe3;

   .probe21(stall_axi_wr_bus.axi_wvalid),//[0:0]probe4;
   .probe22(stall_axi_wr_bus.axi_bid),//[5:0]probe5;
   .probe23('d0), //stall_axi_wr_bus.axi_wstrb),//[63:0]probe6;
   .probe24(stall_axi_wr_bus.axi_bvalid),//[0:0]probe7;
   .probe25(stall_axi_wr_bus.axi_bresp),//[1:0]probe8;
   .probe26(stall_axi_wr_bus.axi_wlast),//[0:0]probe9;

   .probe27(stall_axi_rd_bus.axi_araddr[35:0]),//[35:0]probe10;
   .probe28(stall_axi_rd_bus.axi_arvalid),//[0:0]probe11;
   .probe29(stall_axi_rd_bus.axi_arid),//[5:0]probe12;

   //.probe30(stall_axi_rd_bus.axi_rdata),//[511:0]probe13;
   .probe30({'d0, hawk_cpu_ovrd_rdpkt.ppa,hawk_cpu_ovrd_rdpkt.allow_access,tol_HT.freeListHead,tol_HT.freeListTail,stall_rd_dbg_bus.fsm_state,stall_rd_dbg_bus.overflow,stall_rd_dbg_bus.bus_error,stall_rd_dbg_bus.last_addr0,stall_rd_dbg_bus.last_addr1,stall_rd_dbg_bus.req_count0,stall_rd_dbg_bus.req_count1,stall_rd_dbg_bus.resp_count0,stall_rd_dbg_bus.resp_count1}),

   .probe31(stall_axi_rd_bus.axi_rvalid),//[0:0]probe14;
   .probe32(stall_axi_rd_bus.axi_rlast),//[0:0]probe15;
   .probe33(stall_axi_rd_bus.axi_rresp),//[1:0]probe16;

   .probe34(hawk_axi_wr_bus.axi_awaddr[39:0]),  //[35:0]probe0;
   .probe35(hawk_axi_wr_bus.axi_awvalid), //[0:0]probe1;
   .probe36(hawk_axi_wr_bus.axi_awid),//[5:0]probe2;
   .probe37(hawk_axi_wr_bus.axi_wdata),//[511:0]probe3;
   .probe38(hawk_axi_wr_bus.axi_wvalid),//[0:0]probe4;
   .probe39(hawk_axi_wr_bus.axi_bid),//[5:0]probe5;
   .probe40(hawk_axi_wr_bus.axi_wstrb),//[63:0]probe6;
   .probe41(hawk_axi_wr_bus.axi_bvalid),//[0:0]probe7;
   .probe42(hawk_axi_wr_bus.axi_bresp),//[1:0]probe8;
   .probe43(hawk_axi_wr_bus.axi_wlast),//[0:0]probe9;

   .probe44(hawk_axi_rd_bus.axi_araddr[39:0]),//[35:0]probe10;
   .probe45(hawk_axi_rd_bus.axi_arvalid),//[0:0]probe11;
   .probe46(hawk_axi_rd_bus.axi_arid),//[5:0]probe12;
   .probe47(hawk_axi_rd_bus.axi_rdata),//[511:0]probe13;
   .probe48(hawk_axi_rd_bus.axi_rvalid),//[0:0]probe14;
   .probe49(hawk_axi_rd_bus.axi_rlast),//[0:0]probe15;
   .probe50(hawk_axi_rd_bus.axi_rresp),//[1:0]probe16;

   //[35:0]probe17;
   //[0:0]probe18;
   //[5:0]probe19;
   //[511:0]probe20;
   //[0:0]probe21;
   //[5:0]probe22;
   //[63:0]probe23;
   //[0:0]probe24;
   //[1:0]probe25;
   //[0:0]probe26;

   //[35:0]probe27;
   //[0:0]probe28;
   //[5:0]probe29;
   //[511:0]probe30;
   //[0:0]probe31;
   //[0:0]probe32;
   //[1:0]probe33;

   //[39:0]probe34;
   //[0:0]probe35;
   //[5:0]probe36;
   //[511:0]probe37;
   //[0:0]probe38;
   //[5:0]probe39;
   //[63:0]probe40;
   //[0:0]probe41;
   //[1:0]probe42;
   //[0:0]probe43;

   //[39:0]probe44;
   //[0:0]probe45;
   //[5:0]probe46;
   //[511:0]probe47;
   //[0:0]probe48;
   //[0:0]probe49;
   //[1:0]probe50;

   .probe51(init_list_done),//(mc_axi_rd_bus.axi_araddr), //[63:0]probe51;
   .probe52(init_att_done),//(mc_axi_wr_bus.axi_awaddr), //[63:0]probe52;
   .probe53('d0), //({mc_axi_wr_bus.axi_bvalid,mc_axi_rd_bus.axi_rvalid,mc_axi_wr_bus.axi_wready,mc_axi_rd_bus.axi_rready,mc_axi_rd_bus.axi_arready,mc_axi_wr_bus.axi_awready,mc_axi_rd_bus.axi_arvalid,mc_axi_wr_bus.axi_awvalid}), //[7:0]probe53;
   .probe54('d0),//({'d0,mc_axi_wr_bus.axi_bresp,mc_axi_rd_bus.axi_rresp,mc_axi_wr_bus.axi_bid,mc_axi_rd_bus.axi_rid,mc_axi_rd_bus.axi_arid,mc_axi_wr_bus.axi_awid,mc_axi_wr_bus.axi_wvalid,mc_axi_rd_bus.axi_rlast}), //[63:0]probe54;
   .probe55('d0), //{'d0,tol_updpkt,debug_cmp_mngr.zsPgCnt}), //[63:0]probe55;
    
   .probe56({'d0,wrfifo_full,wrfifo_empty,debug_wrfifo.wrfifo_wrptr,debug_wrfifo.wrfifo_rdptr,rdfifo_rdptr_rst,rdfifo_wrptr_rst,rdfifo_rdptr,ld_rdfifo_rdptr,rdfifo_full,rdfifo_empty,debug_rdfifo.rdfifo_wrptr,debug_rdfifo.rdfifo_rdptr,debug_cmp_mngr.cmpresn_freeWay,debug_cmp_mngr.cmp_mngr_state,debug_cmp_mngr.cmpresn_done,debug_comp.comp_state,cu_state,pwm_state,prm_state,illegal_hawk_table_access,hawk_sw_ctrl[1]}), //[511:0]probe56; //for all states
   .probe57({'d0,debug_cmpdcmp_mngr.cPage_byteStart,debug_cmpdcmp_mngr.cmpdcmp_mngr_state}),//[511:0]probe60;   //pgwr mangaer->compdecomp manager
   .probe58({'d0,tol_HT.IfLstTail[0],tol_HT.IfLstHead[0],tol_HT.incompListHead,tol_HT.incompListTail}),//[511:0]probe61;
   .probe59({'d0,debug_comp.rd_valid,debug_comp.cacheline_cnt,debug_comp.zero_cline_cntr_curr,debug_comp.zero_chunk_vec}),//[511:0]probe63; //for compressor
   .probe60(debug_comp.rd_data),//[511:0]probe57; 
   .probe61({'d0,iWayORcPagePkt.zsPgMd.page2,iWayORcPagePkt.zsPgMd.page1,iWayORcPagePkt.zsPgMd.page0,iWayORcPagePkt.zsPgMd.way_vld,iWayORcPagePkt.zsPgMd.pg_vld,iWayORcPagePkt.iWay_ptr,iWayORcPagePkt.cpage_size,iWayORcPagePkt.cPage_byteStart,iWayORcPagePkt.update,iWayORcPagePkt.comp_decomp,iWayORcPagePkt.pp_ifl,debug_cmp_mngr.zsPgCnt}),//[511:0]probe58; 
   .probe62('d0),//[0]probe58; 
   .probe63('d0)//[0]probe62;

);

`endif




endmodule



