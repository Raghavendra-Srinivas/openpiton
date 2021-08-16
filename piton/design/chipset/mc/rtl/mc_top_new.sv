`include "define.tmp.h"
`include "mc_define.h"
//`include "noc_axi4_bridge_define.vh"
`define NOC_AXI4_BRIDGE_IN_FLIGHT_LIMIT 2
`define NOC_AXI4_BRIDGE_BUFFER_ADDR_SIZE 1 //log(NOC_AXI4_BRIDGE_IN_FLIGHT_LIMIT)


`define AXI4_DATA_WIDTH  512
`define AXI4_ID_WIDTH    6
`define AXI4_ADDR_WIDTH  64
`define AXI4_LEN_WIDTH   8
`define AXI4_SIZE_WIDTH  3
`define AXI4_STRB_WIDTH  64
`define AXI4_BURST_WIDTH 2
`define AXI4_RESP_WIDTH  2
`define AXI4_CACHE_WIDTH 4
`define AXI4_PROT_WIDTH 3
`define AXI4_QOS_WIDTH 4
`define AXI4_REGION_WIDTH 4
`define AXI4_USER_WIDTH 11

//RAGHAVS///
`define HAWK_SIMS 1
////////////

module mc_top_new (
   //hawk -start
   //addding custom 
   input [1:0] hawk_sw_ctrl,
   input   [`NOC_DATA_WIDTH-1:0] buf_hacd_noc2_data,
   input buf_hacd_noc2_valid,
   output hacd_buf_noc2_ready,
   output   [`NOC_DATA_WIDTH-1:0] hacd_buf_noc3_data,
   output hacd_buf_noc3_valid,
   input buf_hacd_noc3_ready,

   output hacd_infl_interrupt,
   output hacd_defl_interrupt,

   //hawk - end
   output                          mc_ui_clk_sync_rst,
   input                           core_ref_clk,

   input   [`NOC_DATA_WIDTH-1:0]   mc_flit_in_data,
   input                           mc_flit_in_val,
   output                          mc_flit_in_rdy,

   output  [`NOC_DATA_WIDTH-1:0]   mc_flit_out_data,
   output                          mc_flit_out_val,
   input                           mc_flit_out_rdy,

   input                           uart_boot_en,
    
   output                          init_calib_complete_out,
   input                           sys_rst_n
);

reg     [31:0]                      delay_cnt;
reg                                 ui_clk_syn_rst_delayed;
wire                                init_calib_complete;
wire                                afifo_rst_1;
wire                                afifo_rst_2;

// AXI4 interface
wire [`AXI4_ID_WIDTH     -1:0]     m_axi_awid;
wire [`AXI4_ADDR_WIDTH   -1:0]     m_axi_awaddr;
wire [`AXI4_LEN_WIDTH    -1:0]     m_axi_awlen;
wire [`AXI4_SIZE_WIDTH   -1:0]     m_axi_awsize;
wire [`AXI4_BURST_WIDTH  -1:0]     m_axi_awburst;
wire                               m_axi_awlock;
wire [`AXI4_CACHE_WIDTH  -1:0]     m_axi_awcache;
wire [`AXI4_PROT_WIDTH   -1:0]     m_axi_awprot;
wire [`AXI4_QOS_WIDTH    -1:0]     m_axi_awqos;
wire [`AXI4_REGION_WIDTH -1:0]     m_axi_awregion;
wire [`AXI4_USER_WIDTH   -1:0]     m_axi_awuser;
wire                               m_axi_awvalid;
wire                               m_axi_awready;

wire  [`AXI4_ID_WIDTH     -1:0]    m_axi_wid;
wire  [`AXI4_DATA_WIDTH   -1:0]    m_axi_wdata;
wire  [`AXI4_STRB_WIDTH   -1:0]    m_axi_wstrb;
wire                               m_axi_wlast;
wire  [`AXI4_USER_WIDTH   -1:0]    m_axi_wuser;
wire                               m_axi_wvalid;
wire                               m_axi_wready;

wire  [`AXI4_ID_WIDTH     -1:0]    m_axi_arid;
wire  [`AXI4_ADDR_WIDTH   -1:0]    m_axi_araddr;
wire  [`AXI4_LEN_WIDTH    -1:0]    m_axi_arlen;
wire  [`AXI4_SIZE_WIDTH   -1:0]    m_axi_arsize;
wire  [`AXI4_BURST_WIDTH  -1:0]    m_axi_arburst;
wire                               m_axi_arlock;
wire  [`AXI4_CACHE_WIDTH  -1:0]    m_axi_arcache;
wire  [`AXI4_PROT_WIDTH   -1:0]    m_axi_arprot;
wire  [`AXI4_QOS_WIDTH    -1:0]    m_axi_arqos;
wire  [`AXI4_REGION_WIDTH -1:0]    m_axi_arregion;
wire  [`AXI4_USER_WIDTH   -1:0]    m_axi_aruser;
wire                               m_axi_arvalid;
wire                               m_axi_arready;

wire  [`AXI4_ID_WIDTH     -1:0]    m_axi_rid;
wire  [`AXI4_DATA_WIDTH   -1:0]    m_axi_rdata;
wire  [`AXI4_RESP_WIDTH   -1:0]    m_axi_rresp;
wire                               m_axi_rlast;
wire  [`AXI4_USER_WIDTH   -1:0]    m_axi_ruser;
wire                               m_axi_rvalid;
wire                               m_axi_rready;

wire  [`AXI4_ID_WIDTH     -1:0]    m_axi_bid;
wire  [`AXI4_RESP_WIDTH   -1:0]    m_axi_bresp;
wire  [`AXI4_USER_WIDTH   -1:0]    m_axi_buser;
wire                               m_axi_bvalid;
wire                               m_axi_bready;

wire [`AXI4_ID_WIDTH     -1:0]     core_axi_awid;
wire [`AXI4_ADDR_WIDTH   -1:0]     core_axi_awaddr;
wire [`AXI4_LEN_WIDTH    -1:0]     core_axi_awlen;
wire [`AXI4_SIZE_WIDTH   -1:0]     core_axi_awsize;
wire [`AXI4_BURST_WIDTH  -1:0]     core_axi_awburst;
wire                               core_axi_awlock;
wire [`AXI4_CACHE_WIDTH  -1:0]     core_axi_awcache;
wire [`AXI4_PROT_WIDTH   -1:0]     core_axi_awprot;
wire [`AXI4_QOS_WIDTH    -1:0]     core_axi_awqos;
wire [`AXI4_REGION_WIDTH -1:0]     core_axi_awregion;
wire [`AXI4_USER_WIDTH   -1:0]     core_axi_awuser;
wire                               core_axi_awvalid;
wire                               core_axi_awready;

wire  [`AXI4_ID_WIDTH     -1:0]    core_axi_wid;
wire  [`AXI4_DATA_WIDTH   -1:0]    core_axi_wdata;
wire  [`AXI4_STRB_WIDTH   -1:0]    core_axi_wstrb;
wire                               core_axi_wlast;
wire  [`AXI4_USER_WIDTH   -1:0]    core_axi_wuser;
wire                               core_axi_wvalid;
wire                               core_axi_wready;

wire  [`AXI4_ID_WIDTH     -1:0]    core_axi_arid;
wire  [`AXI4_ADDR_WIDTH   -1:0]    core_axi_araddr;
wire  [`AXI4_LEN_WIDTH    -1:0]    core_axi_arlen;
wire  [`AXI4_SIZE_WIDTH   -1:0]    core_axi_arsize;
wire  [`AXI4_BURST_WIDTH  -1:0]    core_axi_arburst;
wire                               core_axi_arlock;
wire  [`AXI4_CACHE_WIDTH  -1:0]    core_axi_arcache;
wire  [`AXI4_PROT_WIDTH   -1:0]    core_axi_arprot;
wire  [`AXI4_QOS_WIDTH    -1:0]    core_axi_arqos;
wire  [`AXI4_REGION_WIDTH -1:0]    core_axi_arregion;
wire  [`AXI4_USER_WIDTH   -1:0]    core_axi_aruser;
wire                               core_axi_arvalid;
wire                               core_axi_arready;

wire  [`AXI4_ID_WIDTH     -1:0]    core_axi_rid;
wire  [`AXI4_DATA_WIDTH   -1:0]    core_axi_rdata;
wire  [`AXI4_RESP_WIDTH   -1:0]    core_axi_rresp;
wire                               core_axi_rlast;
wire  [`AXI4_USER_WIDTH   -1:0]    core_axi_ruser;
wire                               core_axi_rvalid;
wire                               core_axi_rready;

wire  [`AXI4_ID_WIDTH     -1:0]    core_axi_bid;
wire  [`AXI4_RESP_WIDTH   -1:0]    core_axi_bresp;
wire  [`AXI4_USER_WIDTH   -1:0]    core_axi_buser;
wire                               core_axi_bvalid;
wire                               core_axi_bready;

`ifdef PITONSYS_MEM_ZEROER
wire [`AXI4_ID_WIDTH     -1:0]     zeroer_axi_awid;
wire [`AXI4_ADDR_WIDTH   -1:0]     zeroer_axi_awaddr;
wire [`AXI4_LEN_WIDTH    -1:0]     zeroer_axi_awlen;
wire [`AXI4_SIZE_WIDTH   -1:0]     zeroer_axi_awsize;
wire [`AXI4_BURST_WIDTH  -1:0]     zeroer_axi_awburst;
wire                               zeroer_axi_awlock;
wire [`AXI4_CACHE_WIDTH  -1:0]     zeroer_axi_awcache;
wire [`AXI4_PROT_WIDTH   -1:0]     zeroer_axi_awprot;
wire [`AXI4_QOS_WIDTH    -1:0]     zeroer_axi_awqos;
wire [`AXI4_REGION_WIDTH -1:0]     zeroer_axi_awregion;
wire [`AXI4_USER_WIDTH   -1:0]     zeroer_axi_awuser;
wire                               zeroer_axi_awvalid;
wire                               zeroer_axi_awready;

wire  [`AXI4_ID_WIDTH     -1:0]    zeroer_axi_wid;
wire  [`AXI4_DATA_WIDTH   -1:0]    zeroer_axi_wdata;
wire  [`AXI4_STRB_WIDTH   -1:0]    zeroer_axi_wstrb;
wire                               zeroer_axi_wlast;
wire  [`AXI4_USER_WIDTH   -1:0]    zeroer_axi_wuser;
wire                               zeroer_axi_wvalid;
wire                               zeroer_axi_wready;

wire  [`AXI4_ID_WIDTH     -1:0]    zeroer_axi_arid;
wire  [`AXI4_ADDR_WIDTH   -1:0]    zeroer_axi_araddr;
wire  [`AXI4_LEN_WIDTH    -1:0]    zeroer_axi_arlen;
wire  [`AXI4_SIZE_WIDTH   -1:0]    zeroer_axi_arsize;
wire  [`AXI4_BURST_WIDTH  -1:0]    zeroer_axi_arburst;
wire                               zeroer_axi_arlock;
wire  [`AXI4_CACHE_WIDTH  -1:0]    zeroer_axi_arcache;
wire  [`AXI4_PROT_WIDTH   -1:0]    zeroer_axi_arprot;
wire  [`AXI4_QOS_WIDTH    -1:0]    zeroer_axi_arqos;
wire  [`AXI4_REGION_WIDTH -1:0]    zeroer_axi_arregion;
wire  [`AXI4_USER_WIDTH   -1:0]    zeroer_axi_aruser;
wire                               zeroer_axi_arvalid;
wire                               zeroer_axi_arready;

wire  [`AXI4_ID_WIDTH     -1:0]    zeroer_axi_rid;
wire  [`AXI4_DATA_WIDTH   -1:0]    zeroer_axi_rdata;
wire  [`AXI4_RESP_WIDTH   -1:0]    zeroer_axi_rresp;
wire                               zeroer_axi_rlast;
wire  [`AXI4_USER_WIDTH   -1:0]    zeroer_axi_ruser;
wire                               zeroer_axi_rvalid;
wire                               zeroer_axi_rready;

wire  [`AXI4_ID_WIDTH     -1:0]    zeroer_axi_bid;
wire  [`AXI4_RESP_WIDTH   -1:0]    zeroer_axi_bresp;
wire  [`AXI4_USER_WIDTH   -1:0]    zeroer_axi_buser;
wire                               zeroer_axi_bvalid;
wire                               zeroer_axi_bready;

wire                               init_calib_complete_zero;
`endif

wire                               noc_axi4_bridge_rst;
wire                               noc_axi4_bridge_init_done;


wire                                app_sr_req;
wire                                app_ref_req;
wire                                app_zq_req;
wire                                app_sr_active;
wire                                app_ref_ack;
wire                                app_zq_ack;
wire                                ui_clk;
wire                                ui_clk_sync_rst;


wire                                trans_fifo_val;
wire    [`NOC_DATA_WIDTH-1:0]       trans_fifo_data;
wire                                trans_fifo_rdy;

wire                                fifo_trans_val;
wire    [`NOC_DATA_WIDTH-1:0]       fifo_trans_data;
wire                                fifo_trans_rdy;

reg                                 afifo_ui_rst_r;
reg                                 afifo_ui_rst_r_r;

reg                                 ui_clk_sync_rst_r;
reg                                 ui_clk_sync_rst_r_r;

// needed for correct rst of async fifo
always @(posedge core_ref_clk) begin
    if (~sys_rst_n)
        delay_cnt <= 32'h1ff;
    else begin
        delay_cnt <= (delay_cnt != 0) & ~ui_clk_sync_rst_r_r ? delay_cnt - 1 : delay_cnt;
    end
end

always @(posedge core_ref_clk) begin
    if (ui_clk_sync_rst)
        ui_clk_syn_rst_delayed <= 1'b1;
    else begin
        ui_clk_syn_rst_delayed <= delay_cnt != 0;
    end
end

assign mc_ui_clk_sync_rst   = ui_clk_syn_rst_delayed;

assign afifo_rst_1 = ui_clk_syn_rst_delayed;


always @(posedge ui_clk) begin
    afifo_ui_rst_r <= afifo_rst_1;
    afifo_ui_rst_r_r <= afifo_ui_rst_r;
end


always @(posedge core_ref_clk) begin
    ui_clk_sync_rst_r   <= ui_clk_sync_rst;
    ui_clk_sync_rst_r_r <= ui_clk_sync_rst_r;
end

assign afifo_rst_2 = afifo_ui_rst_r_r | ui_clk_sync_rst;

// TODO: zeroed based on example simulation of MIG7
// not used for DDR4 MIG
assign app_ref_req = 1'b0;
assign app_sr_req = 1'b0;
assign app_zq_req = 1'b0;

assign noc_mig_bridge_rst       = ui_clk_sync_rst;
assign noc_mig_bridge_init_done = init_calib_complete;
assign init_calib_complete_out  = init_calib_complete & ~ui_clk_syn_rst_delayed;


`ifndef HAWK_SIMS
//This fifo has dependency on on xilinx IP cores and can't compile with
//verilator
noc_bidir_afifo  mig_afifo  (
    .clk_1           (core_ref_clk      ),
    .rst_1           (afifo_rst_1       ),

    .clk_2           (ui_clk            ),
    .rst_2           (afifo_rst_2       ),

    // CPU --> MIG
    .flit_in_val_1   (mc_flit_in_val    ),
    .flit_in_data_1  (mc_flit_in_data   ),
    .flit_in_rdy_1   (mc_flit_in_rdy    ),

    .flit_out_val_2  (fifo_trans_val    ),
    .flit_out_data_2 (fifo_trans_data   ),
    .flit_out_rdy_2  (fifo_trans_rdy    ),

    // MIG --> CPU
    .flit_in_val_2   (trans_fifo_val    ),
    .flit_in_data_2  (trans_fifo_data   ),
    .flit_in_rdy_2   (trans_fifo_rdy    ),

    .flit_out_val_1  (mc_flit_out_val   ),
    .flit_out_data_1 (mc_flit_out_data  ),
    .flit_out_rdy_1  (mc_flit_out_rdy   )
);
`else
 //CPU --> MIG
 assign fifo_trans_val = mc_flit_in_val;
 assign fifo_trans_data = mc_flit_in_data;
 assign mc_flit_in_rdy = fifo_trans_rdy;

 assign mc_flit_out_val =  trans_fifo_val;
 assign mc_flit_out_data = trans_fifo_data;
 assign trans_fifo_rdy = mc_flit_out_rdy;
`endif
//
//

`ifdef PITONSYS_MEM_ZEROER
assign m_axi_awid = zeroer_axi_awid;
assign m_axi_awaddr = zeroer_axi_awaddr;
assign m_axi_awlen = zeroer_axi_awlen;
assign m_axi_awsize = zeroer_axi_awsize;
assign m_axi_awburst = zeroer_axi_awburst;
assign m_axi_awlock = zeroer_axi_awlock;
assign m_axi_awcache = zeroer_axi_awcache;
assign m_axi_awprot = zeroer_axi_awprot;
assign m_axi_awqos = zeroer_axi_awqos;
assign m_axi_awregion = zeroer_axi_awregion;
assign m_axi_awuser = zeroer_axi_awuser;
assign m_axi_awvalid = zeroer_axi_awvalid;
assign zeroer_axi_awready = m_axi_awready;

assign m_axi_wid = zeroer_axi_wid;
assign m_axi_wdata = zeroer_axi_wdata;
assign m_axi_wstrb = zeroer_axi_wstrb;
assign m_axi_wlast = zeroer_axi_wlast;
assign m_axi_wuser = zeroer_axi_wuser;
assign m_axi_wvalid = zeroer_axi_wvalid;
assign zeroer_axi_wready = m_axi_wready;

assign m_axi_arid = zeroer_axi_arid;
assign m_axi_araddr = zeroer_axi_araddr;
assign m_axi_arlen = zeroer_axi_arlen;
assign m_axi_arsize = zeroer_axi_arsize;
assign m_axi_arburst = zeroer_axi_arburst;
assign m_axi_arlock = zeroer_axi_arlock;
assign m_axi_arcache = zeroer_axi_arcache;
assign m_axi_arprot = zeroer_axi_arprot;
assign m_axi_arqos = zeroer_axi_arqos;
assign m_axi_arregion = zeroer_axi_arregion;
assign m_axi_aruser = zeroer_axi_aruser;
assign m_axi_arvalid = zeroer_axi_arvalid;
assign zeroer_axi_arready = m_axi_arready;

assign zeroer_axi_rid = m_axi_rid;
assign zeroer_axi_rdata = m_axi_rdata;
assign zeroer_axi_rresp = m_axi_rresp;
assign zeroer_axi_rlast = m_axi_rlast;
assign zeroer_axi_ruser = m_axi_ruser;
assign zeroer_axi_rvalid = m_axi_rvalid;
assign m_axi_rready = zeroer_axi_rready;

assign zeroer_axi_bid = m_axi_bid;
assign zeroer_axi_bresp = m_axi_bresp;
assign zeroer_axi_buser = m_axi_buser;
assign zeroer_axi_bvalid = m_axi_bvalid;
assign m_axi_bready = zeroer_axi_bready;

assign noc_axi4_bridge_rst       = ui_clk_sync_rst & ~init_calib_complete_zero;
assign noc_axi4_bridge_init_done = init_calib_complete_zero;
assign init_calib_complete_out  = init_calib_complete_zero & ~ui_clk_syn_rst_delayed;
`else // PITONSYS_MEM_ZEROER

assign m_axi_awid = core_axi_awid;
assign m_axi_awaddr = core_axi_awaddr;
assign m_axi_awlen = core_axi_awlen;
assign m_axi_awsize = core_axi_awsize;
assign m_axi_awburst = core_axi_awburst;
assign m_axi_awlock = core_axi_awlock;
assign m_axi_awcache = core_axi_awcache;
assign m_axi_awprot = core_axi_awprot;
assign m_axi_awqos = core_axi_awqos;
assign m_axi_awregion = core_axi_awregion;
assign m_axi_awuser = core_axi_awuser;
assign m_axi_awvalid = core_axi_awvalid;
assign core_axi_awready = m_axi_awready;

assign m_axi_wid = core_axi_wid;
assign m_axi_wdata = core_axi_wdata;
assign m_axi_wstrb = core_axi_wstrb;
assign m_axi_wlast = core_axi_wlast;
assign m_axi_wuser = core_axi_wuser;
assign m_axi_wvalid = core_axi_wvalid;
assign core_axi_wready = m_axi_wready;

assign m_axi_arid = core_axi_arid;
assign m_axi_araddr = core_axi_araddr;
assign m_axi_arlen = core_axi_arlen;
assign m_axi_arsize = core_axi_arsize;
assign m_axi_arburst = core_axi_arburst;
assign m_axi_arlock = core_axi_arlock;
assign m_axi_arcache = core_axi_arcache;
assign m_axi_arprot = core_axi_arprot;
assign m_axi_arqos = core_axi_arqos;
assign m_axi_arregion = core_axi_arregion;
assign m_axi_aruser = core_axi_aruser;
assign m_axi_arvalid = core_axi_arvalid;
assign core_axi_arready = m_axi_arready;

assign core_axi_rid = m_axi_rid;
assign core_axi_rdata = m_axi_rdata;
assign core_axi_rresp = m_axi_rresp;
assign core_axi_rlast = m_axi_rlast;
assign core_axi_ruser = m_axi_ruser;
assign core_axi_rvalid = m_axi_rvalid;
assign m_axi_rready = core_axi_rready;

assign core_axi_bid = m_axi_bid;
assign core_axi_bresp = m_axi_bresp;
assign core_axi_buser = m_axi_buser;
assign core_axi_bvalid = m_axi_bvalid;
assign m_axi_bready = core_axi_bready;

assign noc_axi4_bridge_rst       = ui_clk_sync_rst;
assign noc_axi4_bridge_init_done = init_calib_complete;
assign init_calib_complete_out  = init_calib_complete & ~ui_clk_syn_rst_delayed;
`endif // PITONSYS_MEM_ZEROER


noc_axi4_bridge noc_axi4_bridge  (
    .clk                (ui_clk                    ),  
    .rst_n              (~noc_axi4_bridge_rst      ), 
    .uart_boot_en       (uart_boot_en              ),
    .phy_init_done      (noc_axi4_bridge_init_done ),

    .src_bridge_vr_noc2_val(fifo_trans_val),
    .src_bridge_vr_noc2_dat(fifo_trans_data),
    .src_bridge_vr_noc2_rdy(fifo_trans_rdy),

    .bridge_dst_vr_noc3_val(trans_fifo_val),
    .bridge_dst_vr_noc3_dat(trans_fifo_data),
    .bridge_dst_vr_noc3_rdy(trans_fifo_rdy),

    .m_axi_awid(core_axi_awid),
    .m_axi_awaddr(core_axi_awaddr),
    .m_axi_awlen(core_axi_awlen),
    .m_axi_awsize(core_axi_awsize),
    .m_axi_awburst(core_axi_awburst),
    .m_axi_awlock(core_axi_awlock),
    .m_axi_awcache(core_axi_awcache),
    .m_axi_awprot(core_axi_awprot),
    .m_axi_awqos(core_axi_awqos),
    .m_axi_awregion(core_axi_awregion),
    .m_axi_awuser(core_axi_awuser),
    .m_axi_awvalid(core_axi_awvalid),
    .m_axi_awready(core_axi_awready),

    .m_axi_wid(core_axi_wid),
    .m_axi_wdata(core_axi_wdata),
    .m_axi_wstrb(core_axi_wstrb),
    .m_axi_wlast(core_axi_wlast),
    .m_axi_wuser(core_axi_wuser),
    .m_axi_wvalid(core_axi_wvalid),
    .m_axi_wready(core_axi_wready),

    .m_axi_bid(core_axi_bid),
    .m_axi_bresp(core_axi_bresp),
    .m_axi_buser(core_axi_buser),
    .m_axi_bvalid(core_axi_bvalid),
    .m_axi_bready(core_axi_bready),

    .m_axi_arid(core_axi_arid),
    .m_axi_araddr(core_axi_araddr),
    .m_axi_arlen(core_axi_arlen),
    .m_axi_arsize(core_axi_arsize),
    .m_axi_arburst(core_axi_arburst),
    .m_axi_arlock(core_axi_arlock),
    .m_axi_arcache(core_axi_arcache),
    .m_axi_arprot(core_axi_arprot),
    .m_axi_arqos(core_axi_arqos),
    .m_axi_arregion(core_axi_arregion),
    .m_axi_aruser(core_axi_aruser),
    .m_axi_arvalid(core_axi_arvalid),
    .m_axi_arready(core_axi_arready),

    .m_axi_rid(core_axi_rid),
    .m_axi_rdata(core_axi_rdata),
    .m_axi_rresp(core_axi_rresp),
    .m_axi_rlast(core_axi_rlast),
    .m_axi_ruser(core_axi_ruser),
    .m_axi_rvalid(core_axi_rvalid),
    .m_axi_rready(core_axi_rready)

);

`ifdef PITONSYS_MEM_ZEROER
axi4_zeroer axi4_zeroer(
  .clk                    (ui_clk),
  .rst_n                  (~ui_clk_sync_rst),
  .init_calib_complete_in (init_calib_complete),
  .init_calib_complete_out(init_calib_complete_zero),

  .s_axi_awid             (core_axi_awid),
  .s_axi_awaddr           (core_axi_awaddr),
  .s_axi_awlen            (core_axi_awlen),
  .s_axi_awsize           (core_axi_awsize),
  .s_axi_awburst          (core_axi_awburst),
  .s_axi_awlock           (core_axi_awlock),
  .s_axi_awcache          (core_axi_awcache),
  .s_axi_awprot           (core_axi_awprot),
  .s_axi_awqos            (core_axi_awqos),
  .s_axi_awregion         (core_axi_awregion),
  .s_axi_awuser           (core_axi_awuser),
  .s_axi_awvalid          (core_axi_awvalid),
  .s_axi_awready          (core_axi_awready),

  .s_axi_wid              (core_axi_wid),
  .s_axi_wdata            (core_axi_wdata),
  .s_axi_wstrb            (core_axi_wstrb),
  .s_axi_wlast            (core_axi_wlast),
  .s_axi_wuser            (core_axi_wuser),
  .s_axi_wvalid           (core_axi_wvalid),
  .s_axi_wready           (core_axi_wready),

  .s_axi_arid             (core_axi_arid),
  .s_axi_araddr           (core_axi_araddr),
  .s_axi_arlen            (core_axi_arlen),
  .s_axi_arsize           (core_axi_arsize),
  .s_axi_arburst          (core_axi_arburst),
  .s_axi_arlock           (core_axi_arlock),
  .s_axi_arcache          (core_axi_arcache),
  .s_axi_arprot           (core_axi_arprot),
  .s_axi_arqos            (core_axi_arqos),
  .s_axi_arregion         (core_axi_arregion),
  .s_axi_aruser           (core_axi_aruser),
  .s_axi_arvalid          (core_axi_arvalid),
  .s_axi_arready          (core_axi_arready),

  .s_axi_rid              (core_axi_rid),
  .s_axi_rdata            (core_axi_rdata),
  .s_axi_rresp            (core_axi_rresp),
  .s_axi_rlast            (core_axi_rlast),
  .s_axi_ruser            (core_axi_ruser),
  .s_axi_rvalid           (core_axi_rvalid),
  .s_axi_rready           (core_axi_rready),

  .s_axi_bid              (core_axi_bid),
  .s_axi_bresp            (core_axi_bresp),
  .s_axi_buser            (core_axi_buser),
  .s_axi_bvalid           (core_axi_bvalid),
  .s_axi_bready           (core_axi_bready),


  .m_axi_awid             (zeroer_axi_awid),
  .m_axi_awaddr           (zeroer_axi_awaddr),
  .m_axi_awlen            (zeroer_axi_awlen),
  .m_axi_awsize           (zeroer_axi_awsize),
  .m_axi_awburst          (zeroer_axi_awburst),
  .m_axi_awlock           (zeroer_axi_awlock),
  .m_axi_awcache          (zeroer_axi_awcache),
  .m_axi_awprot           (zeroer_axi_awprot),
  .m_axi_awqos            (zeroer_axi_awqos),
  .m_axi_awregion         (zeroer_axi_awregion),
  .m_axi_awuser           (zeroer_axi_awuser),
  .m_axi_awvalid          (zeroer_axi_awvalid),
  .m_axi_awready          (zeroer_axi_awready),

  .m_axi_wid              (zeroer_axi_wid),
  .m_axi_wdata            (zeroer_axi_wdata),
  .m_axi_wstrb            (zeroer_axi_wstrb),
  .m_axi_wlast            (zeroer_axi_wlast),
  .m_axi_wuser            (zeroer_axi_wuser),
  .m_axi_wvalid           (zeroer_axi_wvalid),
  .m_axi_wready           (zeroer_axi_wready),

  .m_axi_arid             (zeroer_axi_arid),
  .m_axi_araddr           (zeroer_axi_araddr),
  .m_axi_arlen            (zeroer_axi_arlen),
  .m_axi_arsize           (zeroer_axi_arsize),
  .m_axi_arburst          (zeroer_axi_arburst),
  .m_axi_arlock           (zeroer_axi_arlock),
  .m_axi_arcache          (zeroer_axi_arcache),
  .m_axi_arprot           (zeroer_axi_arprot),
  .m_axi_arqos            (zeroer_axi_arqos),
  .m_axi_arregion         (zeroer_axi_arregion),
  .m_axi_aruser           (zeroer_axi_aruser),
  .m_axi_arvalid          (zeroer_axi_arvalid),
  .m_axi_arready          (zeroer_axi_arready),

  .m_axi_rid              (zeroer_axi_rid),
  .m_axi_rdata            (zeroer_axi_rdata),
  .m_axi_rresp            (zeroer_axi_rresp),
  .m_axi_rlast            (zeroer_axi_rlast),
  .m_axi_ruser            (zeroer_axi_ruser),
  .m_axi_rvalid           (zeroer_axi_rvalid),
  .m_axi_rready           (zeroer_axi_rready),

  .m_axi_bid              (zeroer_axi_bid),
  .m_axi_bresp            (zeroer_axi_bresp),
  .m_axi_buser            (zeroer_axi_buser),
  .m_axi_bvalid           (zeroer_axi_bvalid),
  .m_axi_bready           (zeroer_axi_bready)
);
`endif // PITONSYS_MEM_ZEROER

//Comment for simulations
`ifndef HAWK_SIMS
mig_7series_axi4 u_mig_7series_axi4 (

    // Memory interface ports
    .ddr3_addr                      (ddr_addr),  // output [13:0]      ddr3_addr
    .ddr3_ba                        (ddr_ba),  // output [2:0]     ddr3_ba
    .ddr3_cas_n                     (ddr_cas_n),  // output            ddr3_cas_n
    .ddr3_ck_n                      (ddr_ck_n),  // output [0:0]       ddr3_ck_n
    .ddr3_ck_p                      (ddr_ck_p),  // output [0:0]       ddr3_ck_p
    .ddr3_cke                       (ddr_cke),  // output [0:0]        ddr3_cke
    .ddr3_ras_n                     (ddr_ras_n),  // output            ddr3_ras_n
    .ddr3_reset_n                   (ddr_reset_n),  // output          ddr3_reset_n
    .ddr3_we_n                      (ddr_we_n),  // output         ddr3_we_n
    .ddr3_dq                        (ddr_dq),  // inout [63:0]     ddr3_dq
    .ddr3_dqs_n                     (ddr_dqs_n),  // inout [7:0]       ddr3_dqs_n
    .ddr3_dqs_p                     (ddr_dqs_p),  // inout [7:0]       ddr3_dqs_p
    .init_calib_complete            (init_calib_complete),  // output           init_calib_complete
      
    .ddr3_cs_n                      (ddr_cs_n),  // output [0:0]       ddr3_cs_n
    .ddr3_dm                        (ddr_dm),  // output [7:0]     ddr3_dm
    .ddr3_odt                       (ddr_odt),  // output [0:0]        ddr3_odt

    // Application interface ports
    .ui_clk                         (ui_clk),  // output            ui_clk
    .ui_clk_sync_rst                (ui_clk_sync_rst),  // output           ui_clk_sync_rst
    .mmcm_locked                    (),  // output           mmcm_locked
    .aresetn                        (sys_rst_n),  // input            aresetn
    .app_sr_req                     (app_sr_req),  // input         app_sr_req
    .app_ref_req                    (app_ref_req),  // input            app_ref_req
    .app_zq_req                     (app_zq_req),  // input         app_zq_req
    .app_sr_active                  (app_sr_active),  // output         app_sr_active
    .app_ref_ack                    (app_ref_ack),  // output           app_ref_ack
    .app_zq_ack                     (app_zq_ack),  // output            app_zq_ack

    // Slave Interface Write Address Ports
    .s_axi_awid                     (mc_axi_wr_bus.slv.axi_awid),  // input [15:0]          s_axi_awid
    .s_axi_awaddr                   (mc_axi_wr_bus.slv.axi_awaddr),  // input [29:0]            s_axi_awaddr
    .s_axi_awlen                    (mc_axi_wr_bus.slv.axi_awlen),  // input [7:0]          s_axi_awlen
    .s_axi_awsize                   (mc_axi_wr_bus.slv.axi_awsize),  // input [2:0]         s_axi_awsize
    .s_axi_awburst                  (mc_axi_wr_bus.slv.axi_awburst),  // input [1:0]            s_axi_awburst
    .s_axi_awlock                   (mc_axi_wr_bus.slv.axi_awlock),  // input [0:0]         s_axi_awlock
    .s_axi_awcache                  (mc_axi_wr_bus.slv.axi_awcache),  // input [3:0]            s_axi_awcache
    .s_axi_awprot                   (mc_axi_wr_bus.slv.axi_awprot),  // input [2:0]         s_axi_awprot
    .s_axi_awqos                    (mc_axi_wr_bus.slv.axi_awqos),  // input [3:0]          s_axi_awqos
    .s_axi_awvalid                  (mc_axi_wr_bus.slv.axi_awvalid),  // input          s_axi_awvalid
    .s_axi_awready                  (mc_axi_wr_bus.slv.axi_awready),  // output         s_axi_awready
    // Slave Interface Write Data Ports
    .s_axi_wdata                    (mc_axi_wr_bus.slv.axi_wdata),  // input [511:0]            s_axi_wdata
    .s_axi_wstrb                    (mc_axi_wr_bus.slv.axi_wstrb),  // input [63:0]         s_axi_wstrb
    .s_axi_wlast                    (mc_axi_wr_bus.slv.axi_wlast),  // input            s_axi_wlast
    .s_axi_wvalid                   (mc_axi_wr_bus.slv.axi_wvalid),  // input           s_axi_wvalid
    .s_axi_wready                   (mc_axi_wr_bus.slv.axi_wready),  // output          s_axi_wready
    // Slave Interface Write Response Ports
    .s_axi_bid                      (mc_axi_wr_bus.slv.axi_bid),  // output [15:0]          s_axi_bid
    .s_axi_bresp                    (mc_axi_wr_bus.slv.axi_bresp),  // output [1:0]         s_axi_bresp
    .s_axi_bvalid                   (mc_axi_wr_bus.slv.axi_bvalid),  // output          s_axi_bvalid
    .s_axi_bready                   (mc_axi_wr_bus.slv.axi_bready),  // input           s_axi_bready
    // Slave Interface Read Address Ports
    .s_axi_arid                     (mc_axi_rd_bus.slv.axi_arid),  // input [15:0]          s_axi_arid
    .s_axi_araddr                   (mc_axi_rd_bus.slv.axi_araddr),  // input [29:0]            s_axi_araddr
    .s_axi_arlen                    (mc_axi_rd_bus.slv.axi_arlen),  // input [7:0]          s_axi_arlen
    .s_axi_arsize                   (mc_axi_rd_bus.slv.axi_arsize),  // input [2:0]         s_axi_arsize
    .s_axi_arburst                  (mc_axi_rd_bus.slv.axi_arburst),  // input [1:0]            s_axi_arburst
    .s_axi_arlock                   (mc_axi_rd_bus.slv.axi_arlock),  // input [0:0]         s_axi_arlock
    .s_axi_arcache                  (mc_axi_rd_bus.slv.axi_arcache),  // input [3:0]            s_axi_arcache
    .s_axi_arprot                   (mc_axi_rd_bus.slv.axi_arprot),  // input [2:0]         s_axi_arprot
    .s_axi_arqos                    (mc_axi_rd_bus.slv.axi_arqos),  // input [3:0]          s_axi_arqos
    .s_axi_arvalid                  (mc_axi_rd_bus.slv.axi_arvalid),  // input          s_axi_arvalid
    .s_axi_arready                  (mc_axi_rd_bus.slv.axi_arready),  // output         s_axi_arready
    // Slave Interface Read Data Ports
    .s_axi_rid                      (mc_axi_rd_bus.slv.axi_rid),  // output [15:0]          s_axi_rid
    .s_axi_rdata                    (mc_axi_rd_bus.slv.axi_rdata),  // output [511:0]           s_axi_rdata
    .s_axi_rresp                    (mc_axi_rd_bus.slv.axi_rresp),  // output [1:0]         s_axi_rresp
    .s_axi_rlast                    (mc_axi_rd_bus.slv.axi_rlast),  // output           s_axi_rlast
    .s_axi_rvalid                   (mc_axi_rd_bus.slv.axi_rvalid),  // output          s_axi_rvalid
    .s_axi_rready                   (mc_axi_rd_bus.slv.axi_rready),  // input           s_axi_rready

    // System Clock Ports
    .sys_clk_i                      (sys_clk),
    .sys_rst                        (sys_rst_n) // input sys_rst
);
`else


  assign ui_clk=core_ref_clk;
  assign ui_clk_sync_rst=!sys_rst_n;
  assign init_calib_complete = 1'b1;
 
  `define FAKE_MEM_HAWK 1
  wire dump_mem;
 `ifdef FAKE_MEM_HAWK
  
  fake_axi4_mem u_fake_aximem (
    .clk                (ui_clk                    ),  
    .rst_n              (~noc_axi4_bridge_rst      ), 
    .wr_bus(mc_axi_wr_bus.slv),
    .rd_bus(mc_axi_rd_bus.slv),
    .dump_mem (dump_mem)
  );


  `else
  //From memory controller
  //Tie off hand shake and response
  //WR CHANNEL
  assign mc_axi_wr_bus.slv.axi_awready=1'b1;
  assign mc_axi_wr_bus.slv.axi_wready=1'b1;
  
  //WR Respn from mc tie -off
  assign mc_axi_wr_bus.slv.axi_bid = 'd0;
  assign mc_axi_wr_bus.slv.axi_bresp = 'd0;
  assign mc_axi_wr_bus.slv.axi_buser ='d0;
  assign mc_axi_wr_bus.slv.axi_bvalid = 1'b1;
  
  //RD from MC
  assign mc_axi_rd_bus.slv.axi_rid ='d0;
  assign mc_axi_rd_bus.slv.axi_rdata ='d0;
  assign mc_axi_rd_bus.slv.axi_rresp ='d0;
  assign mc_axi_rd_bus.slv.axi_rlast ='d1;
  assign mc_axi_rd_bus.slv.axi_rid ='d0;
  assign mc_axi_rd_bus.slv.axi_ruser ='d0;
  assign mc_axi_rd_bus.slv.axi_rvalid ='d1;
  `endif
`endif

//Custom Design Block - Hacd
//CUSTOM MODULE
//START
//VT HEAP LAB HACD
   //CPU<->HACD
    //hacd will observe these for request signals from cpu
    HACD_AXI_WR_BUS#() cpu_axi_wr_bus();
    HACD_AXI_RD_BUS#() cpu_axi_rd_bus();
    
    //HACD<->MC
    //hacd will act as request master on request singslas to mc 
    HACD_MC_AXI_WR_BUS#() mc_axi_wr_bus();
    HACD_MC_AXI_RD_BUS#() mc_axi_rd_bus();

//wire hacd_infl_interrupt,hacd_defl_interrupt;
//connect NOC signals to hawk
//AW
assign cpu_axi_wr_bus.axi_awid = m_axi_awid; //'d0;
assign cpu_axi_wr_bus.axi_awaddr =m_axi_awaddr; //'d0;
assign cpu_axi_wr_bus.axi_awlen = m_axi_awlen;//'d0;
assign cpu_axi_wr_bus.axi_awsize =m_axi_awsize;//'d0;
assign cpu_axi_wr_bus.axi_awburst =m_axi_awburst;//'d0;
assign cpu_axi_wr_bus.axi_awlock=m_axi_awlock;//'d0;
assign cpu_axi_wr_bus.axi_awcache=m_axi_awcache;//'d0;
assign cpu_axi_wr_bus.axi_awprot=m_axi_awprot;//'d0;
assign cpu_axi_wr_bus.axi_awqos=m_axi_awqos;//'d0;
assign cpu_axi_wr_bus.axi_awregion=m_axi_awregion;//'d0;
assign cpu_axi_wr_bus.axi_awuser=m_axi_awuser;//'d0;
assign cpu_axi_wr_bus.axi_awvalid=m_axi_awvalid;//'d0;
assign m_axi_awready = cpu_axi_wr_bus.axi_awready;
//W
//assign cpu_axi_wr_bus.axi_wid=m_axi_wid;//'d0;
assign cpu_axi_wr_bus.axi_wdata=m_axi_wdata;//'d0;
assign cpu_axi_wr_bus.axi_wstrb=m_axi_wstrb;//'d0;
assign cpu_axi_wr_bus.axi_wlast=m_axi_wlast;//'d0;
assign cpu_axi_wr_bus.axi_wuser=m_axi_wuser;//'d0;
assign cpu_axi_wr_bus.axi_wvalid=m_axi_wvalid;//'d0;
assign m_axi_wready = cpu_axi_wr_bus.axi_wready;

//BRESP
assign m_axi_bid=cpu_axi_wr_bus.axi_bid;
assign m_axi_bresp=cpu_axi_wr_bus.axi_bresp;
assign m_axi_buser=cpu_axi_wr_bus.axi_buser;
assign m_axi_bvalid=cpu_axi_wr_bus.axi_bvalid;
assign cpu_axi_wr_bus.axi_bready = m_axi_bready ; //'d0;

//AR
assign cpu_axi_rd_bus.axi_arid = m_axi_arid; //'d0;
assign cpu_axi_rd_bus.axi_araddr =m_axi_araddr; //'d0;
assign cpu_axi_rd_bus.axi_arlen = m_axi_arlen;//'d0;
assign cpu_axi_rd_bus.axi_arsize =m_axi_arsize;//'d0;
assign cpu_axi_rd_bus.axi_arburst =m_axi_arburst;//'d0;
assign cpu_axi_rd_bus.axi_arlock=m_axi_arlock;//'d0;
assign cpu_axi_rd_bus.axi_arcache=m_axi_arcache;//'d0;
assign cpu_axi_rd_bus.axi_arprot=m_axi_arprot;//'d0;
assign cpu_axi_rd_bus.axi_arqos=m_axi_arqos;//'d0;
assign cpu_axi_rd_bus.axi_arregion=m_axi_arregion;//'d0;
assign cpu_axi_rd_bus.axi_aruser=m_axi_aruser;//'d0;
assign cpu_axi_rd_bus.axi_arvalid=m_axi_arvalid;//'d0;
assign m_axi_arready = cpu_axi_rd_bus.axi_arready;


//RD RESP
assign m_axi_rid = cpu_axi_rd_bus.axi_rid;
assign m_axi_rdata= cpu_axi_rd_bus.axi_rdata;
assign m_axi_rresp= cpu_axi_rd_bus.axi_rresp;
assign m_axi_rlast= cpu_axi_rd_bus.axi_rlast;
assign m_axi_ruser= cpu_axi_rd_bus.axi_ruser;
assign m_axi_rvalid= cpu_axi_rd_bus.axi_rvalid;
assign cpu_axi_rd_bus.axi_rready =m_axi_rready;

hacd_top  #(
	.NOC_DWIDTH(`DATA_WIDTH),
        .HacdBase       ( 64'h000000fff5100000 ),
        .SwapEndianess  (               1 )
) 
u_hacd_top (
        .cfg_clk_i                    ( core_ref_clk),
        .cfg_rst_ni                   ( sys_rst_n),
        .clk_i                    ( core_ref_clk), //ui_clk is given by ddr in fpga that should be connecte here
        .rst_ni                   ( sys_rst_n),    // this should be noc_axi_birdge reset in fpga
	.hawk_sw_ctrl 		  (2'b00) ,        //(hawk_sw_ctrl),
	.infl_interrupt           ( hacd_infl_interrupt),
	.defl_interrupt           ( hacd_defl_interrupt),
        .buf_hacd_noc2_data_i     ( buf_hacd_noc2_data     ),
        .buf_hacd_noc2_valid_i    ( buf_hacd_noc2_valid    ),
        .hacd_buf_noc2_ready_o    ( hacd_buf_noc2_ready    ),
        .hacd_buf_noc3_data_o     ( hacd_buf_noc3_data     ),
        .hacd_buf_noc3_valid_o    ( hacd_buf_noc3_valid    ),
        .buf_hacd_noc3_ready_i    ( buf_hacd_noc3_ready    ),

	//AXI
        .cpu_axi_wr_bus(cpu_axi_wr_bus.slv),
        .cpu_axi_rd_bus(cpu_axi_rd_bus.slv),

        .mc_axi_wr_bus(mc_axi_wr_bus.mstr),
        .mc_axi_rd_bus(mc_axi_rd_bus.mstr),
	
	.dump_mem(dump_mem)
);
//END

endmodule 
