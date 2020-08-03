
// ========== Copyright Header Begin ============================================
// Copyright (c) 2015 Princeton University
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of Princeton University nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY PRINCETON UNIVERSITY "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL PRINCETON UNIVERSITY BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// ========== Copyright Header End ============================================

`include "define.tmp.h"
`include "mc_define.h"
`include "noc_axi4_bridge_define.vh"


import hacd_pkg::*;
module hawk_mc_top (

   //hawk -start
   //addding custom ports
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
    
`ifdef PITONSYS_DDR4
    // directly feed in 250MHz ref clock
    input                           sys_clk_p,
    input                           sys_clk_n,

    output                          ddr_act_n,
    output [`DDR3_BG_WIDTH-1:0]     ddr_bg,
`else // PITONSYS_DDR4
    input                           sys_clk,

    output                          ddr_cas_n,
    output                          ddr_ras_n,
    output                          ddr_we_n,
`endif // PITONSYS_DDR4

    output [`DDR3_ADDR_WIDTH-1:0]   ddr_addr,
    output [`DDR3_BA_WIDTH-1:0]     ddr_ba,
    output [`DDR3_CK_WIDTH-1:0]     ddr_ck_n,
    output [`DDR3_CK_WIDTH-1:0]     ddr_ck_p,
    output [`DDR3_CKE_WIDTH-1:0]    ddr_cke,
    output                          ddr_reset_n,
    inout  [`DDR3_DQ_WIDTH-1:0]     ddr_dq,
    inout  [`DDR3_DQS_WIDTH-1:0]    ddr_dqs_n,
    inout  [`DDR3_DQS_WIDTH-1:0]    ddr_dqs_p,
`ifndef NEXYSVIDEO_BOARD
    output [`DDR3_CS_WIDTH-1:0]     ddr_cs_n,
`endif // endif NEXYSVIDEO_BOARD
`ifdef PITONSYS_DDR4
`ifdef XUPP3R_BOARD
    output                          ddr_parity,
`else
    inout [`DDR3_DM_WIDTH-1:0]      ddr_dm,
`endif // XUPP3R_BOARD
`else // PITONSYS_DDR4
    output [`DDR3_DM_WIDTH-1:0]     ddr_dm,
`endif // PITONSYS_DDR4
    output [`DDR3_ODT_WIDTH-1:0]    ddr_odt,

    output                          init_calib_complete_out,
    input                           sys_rst_n
);
reg     [31:0]                      delay_cnt;
reg                                 ui_clk_syn_rst_delayed;
wire                                init_calib_complete;
wire                                afifo_rst_1;
wire                                afifo_rst_2;


`ifdef HAWK_FPGA
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
`endif




`ifndef PITONSYS_AXI4_MEM
 wire                               app_en;
 wire    [`MIG_APP_CMD_WIDTH-1 :0]  app_cmd;
 wire    [`MIG_APP_ADDR_WIDTH-1:0]  app_addr;
 wire                               app_rdy;
 wire                               app_wdf_wren;
 wire    [`MIG_APP_DATA_WIDTH-1:0]  app_wdf_data;
 wire    [`MIG_APP_MASK_WIDTH-1:0]  app_wdf_mask;
 wire                               app_wdf_rdy;
 wire                               app_wdf_end;
 wire    [`MIG_APP_DATA_WIDTH-1:0]  app_rd_data;
 wire                               app_rd_data_end;
 wire                               app_rd_data_valid;

 wire                               core_app_en;
 wire    [`MIG_APP_CMD_WIDTH-1 :0]  core_app_cmd;
 wire    [`MIG_APP_ADDR_WIDTH-1:0]  core_app_addr;
 wire                               core_app_rdy;
 wire                               core_app_wdf_wren;
 wire    [`MIG_APP_DATA_WIDTH-1:0]  core_app_wdf_data;
 wire    [`MIG_APP_MASK_WIDTH-1:0]  core_app_wdf_mask;
 wire                               core_app_wdf_rdy;
 wire                               core_app_wdf_end;
 wire    [`MIG_APP_DATA_WIDTH-1:0]  core_app_rd_data;
 wire                               core_app_rd_data_end;
 wire                               core_app_rd_data_valid;

`ifdef PITONSYS_MEM_ZEROER
wire                                zero_app_en;
wire    [`MIG_APP_CMD_WIDTH-1 :0]   zero_app_cmd;
wire    [`MIG_APP_ADDR_WIDTH-1:0]   zero_app_addr;
wire                                zero_app_wdf_wren;
wire    [`MIG_APP_DATA_WIDTH-1:0]   zero_app_wdf_data;
wire    [`MIG_APP_MASK_WIDTH-1:0]   zero_app_wdf_mask;
wire                                zero_app_wdf_end;
wire                                init_calib_complete_zero;
`endif

wire                                noc_mig_bridge_rst;
wire                                noc_mig_bridge_init_done;

`else // PITONSYS_AXI4_MEM

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

`endif // PITONSYS_AXI4_MEM

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

`ifndef PITONSYS_AXI4_MEM
	`ifdef PITONSYS_MEM_ZEROER
		assign app_en                   = zero_app_en;
		assign app_cmd                  = zero_app_cmd;
		assign app_addr                 = zero_app_addr;
		assign app_wdf_wren             = zero_app_wdf_wren;
		assign app_wdf_data             = zero_app_wdf_data;
		assign app_wdf_mask             = zero_app_wdf_mask;
		assign app_wdf_end              = zero_app_wdf_end;
		assign noc_mig_bridge_rst       = ui_clk_sync_rst & ~init_calib_complete_zero;
		assign noc_mig_bridge_init_done = init_calib_complete_zero;
		assign init_calib_complete_out  = init_calib_complete_zero & ~ui_clk_syn_rst_delayed;
	`else
		assign app_en                   = core_app_en;
		assign app_cmd                  = core_app_cmd;
		assign app_addr                 = core_app_addr;
		assign app_wdf_wren             = core_app_wdf_wren;
		assign app_wdf_data             = core_app_wdf_data;
		assign app_wdf_mask             = core_app_wdf_mask;
		assign app_wdf_end              = core_app_wdf_end;
		assign noc_mig_bridge_rst       = ui_clk_sync_rst;
		assign noc_mig_bridge_init_done = init_calib_complete;
		assign init_calib_complete_out  = init_calib_complete & ~ui_clk_syn_rst_delayed;
	`endif
	assign core_app_rdy             = app_rdy;
	assign core_app_wdf_rdy         = app_wdf_rdy;
	assign core_app_rd_data_valid   = app_rd_data_valid;
	assign core_app_rd_data_end     = app_rd_data_end;
	assign core_app_rd_data         = app_rd_data;

`else //ifndef PITONSYS_AXI4_MEM
	//assign noc_mig_bridge_rst       = ui_clk_sync_rst;
	//assign noc_mig_bridge_init_done = init_calib_complete;
	//assign init_calib_complete_out  = init_calib_complete & ~ui_clk_syn_rst_delayed;
`endif

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


`ifndef PITONSYS_AXI4_MEM

	`ifdef PITONSYS_MEM_ZEROER
	assign app_en                   = zero_app_en;
	assign app_cmd                  = zero_app_cmd;
	assign app_addr                 = zero_app_addr;
	assign app_wdf_wren             = zero_app_wdf_wren;
	assign app_wdf_data             = zero_app_wdf_data;
	assign app_wdf_mask             = zero_app_wdf_mask;
	assign app_wdf_end              = zero_app_wdf_end;
	assign noc_mig_bridge_rst       = ui_clk_sync_rst & ~init_calib_complete_zero;
	assign noc_mig_bridge_init_done = init_calib_complete_zero;
	assign init_calib_complete_out  = init_calib_complete_zero & ~ui_clk_syn_rst_delayed;
	`else
	assign app_en                   = core_app_en;
	assign app_cmd                  = core_app_cmd;
	assign app_addr                 = core_app_addr;
	assign app_wdf_wren             = core_app_wdf_wren;
	assign app_wdf_data             = core_app_wdf_data;
	assign app_wdf_mask             = core_app_wdf_mask;
	assign app_wdf_end              = core_app_wdf_end;
	assign noc_mig_bridge_rst       = ui_clk_sync_rst;
	assign noc_mig_bridge_init_done = init_calib_complete;
	assign init_calib_complete_out  = init_calib_complete & ~ui_clk_syn_rst_delayed;
	`endif
	assign core_app_rdy             = app_rdy;
	assign core_app_wdf_rdy         = app_wdf_rdy;
	assign core_app_rd_data_valid   = app_rd_data_valid;
	assign core_app_rd_data_end     = app_rd_data_end;
	assign core_app_rd_data         = app_rd_data;
	
	noc_mig_bridge    #  (
	    .MIG_APP_ADDR_WIDTH (`MIG_APP_ADDR_WIDTH        ),
	    .MIG_APP_DATA_WIDTH (`MIG_APP_DATA_WIDTH        )
	)   noc_mig_bridge   (
	    .clk                (ui_clk                     ),  // from MC
	    .rst                (noc_mig_bridge_rst         ),  // from MC
	
	    .uart_boot_en       (uart_boot_en               ),
	
	    .flit_in            (fifo_trans_data            ),
	    .flit_in_val        (fifo_trans_val             ),
	    .flit_in_rdy        (fifo_trans_rdy             ),
	    .flit_out           (trans_fifo_data            ),
	    .flit_out_val       (trans_fifo_val             ),
	    .flit_out_rdy       (trans_fifo_rdy             ),
	
	    .app_rdy            (core_app_rdy               ),
	    .app_wdf_rdy        (core_app_wdf_rdy           ),
	    .app_rd_data        (core_app_rd_data           ),
	    .app_rd_data_end    (core_app_rd_data_end       ),
	    .app_rd_data_valid  (core_app_rd_data_valid     ),
	    .phy_init_done      (noc_mig_bridge_init_done   ),
	
	    .app_wdf_wren_reg   (core_app_wdf_wren          ),
	    .app_wdf_data_out   (core_app_wdf_data          ),
	    .app_wdf_mask_out   (core_app_wdf_mask          ),
	    .app_wdf_end_out    (core_app_wdf_end           ),
	    .app_addr_out       (core_app_addr              ),
	    .app_en_reg         (core_app_en                ),
	    .app_cmd_reg        (core_app_cmd               )
	);
	
	`ifdef PITONSYS_MEM_ZEROER
	memory_zeroer #(
	    .MIG_APP_ADDR_WIDTH (`MIG_APP_ADDR_WIDTH        ),
	    .MIG_APP_DATA_WIDTH (`MIG_APP_DATA_WIDTH        )
	)    memory_zeroer (
	    .clk                        (ui_clk                     ),
	    .rst_n                      (~ui_clk_sync_rst           ),
	
	    .init_calib_complete_in     (init_calib_complete        ),
	    .init_calib_complete_out    (init_calib_complete_zero   ),
	
	    .app_rdy_in                 (core_app_rdy               ),
	    .app_wdf_rdy_in             (core_app_wdf_rdy           ),
	    
	    .app_wdf_wren_in            (core_app_wdf_wren          ),
	    .app_wdf_data_in            (core_app_wdf_data          ),
	    .app_wdf_mask_in            (core_app_wdf_mask          ),
	    .app_wdf_end_in             (core_app_wdf_end           ),
	    .app_addr_in                (core_app_addr              ),
	    .app_en_in                  (core_app_en                ),
	    .app_cmd_in                 (core_app_cmd               ),
	
	    .app_wdf_wren_out           (zero_app_wdf_wren          ),
	    .app_wdf_data_out           (zero_app_wdf_data          ),
	    .app_wdf_mask_out           (zero_app_wdf_mask          ),
	    .app_wdf_end_out            (zero_app_wdf_end           ),
	    .app_addr_out               (zero_app_addr              ),
	    .app_en_out                 (zero_app_en                ),
	    .app_cmd_out                (zero_app_cmd               )
	);
	`endif
	
	`ifdef PITONSYS_DDR4
	
	// reserved, tie to 0
	wire app_hi_pri;
	assign app_hi_pri = 1'b0;
	  
	ddr4_0 i_ddr4_0 (
	  .sys_rst                   ( ~sys_rst_n                ),
	  .c0_sys_clk_p              ( sys_clk_p                 ),
	  .c0_sys_clk_n              ( sys_clk_n                 ),
	  .dbg_clk                   (                           ), // not used 
	  .dbg_bus                   (                           ), // not used
	  .c0_ddr4_ui_clk            ( ui_clk                    ),
	  .c0_ddr4_ui_clk_sync_rst   ( ui_clk_sync_rst           ),
	  
	  .c0_ddr4_act_n             ( ddr_act_n                 ), // cas_n, ras_n and we_n are multiplexed in ddr4
	  .c0_ddr4_adr               ( ddr_addr                  ),
	  .c0_ddr4_ba                ( ddr_ba                    ),
	  .c0_ddr4_bg                ( ddr_bg                    ), // bank group address
	  .c0_ddr4_cke               ( ddr_cke                   ),
	  .c0_ddr4_odt               ( ddr_odt                   ),
	  .c0_ddr4_cs_n              ( ddr_cs_n                  ),
	  .c0_ddr4_ck_t              ( ddr_ck_p                  ),
	  .c0_ddr4_ck_c              ( ddr_ck_n                  ),
	  .c0_ddr4_reset_n           ( ddr_reset_n               ),
	`ifndef XUPP3R_BOARD
	  .c0_ddr4_dm_dbi_n          ( ddr_dm                    ), // dbi_n is a data bus inversion feature that cannot be used simultaneously with dm
	`endif
	  .c0_ddr4_dq                ( ddr_dq                    ), 
	  .c0_ddr4_dqs_c             ( ddr_dqs_n                 ), 
	  .c0_ddr4_dqs_t             ( ddr_dqs_p                 ), 
	  .c0_init_calib_complete    ( init_calib_complete       ),
	  
	  // Application interface ports
	  .c0_ddr4_app_addr          ( app_addr                  ),
	  .c0_ddr4_app_cmd           ( app_cmd                   ),
	  .c0_ddr4_app_en            ( app_en                    ),
	
	  .c0_ddr4_app_hi_pri        ( app_hi_pri                ), // reserved, tie to 0
	  .c0_ddr4_app_wdf_data      ( app_wdf_data              ), 
	  .c0_ddr4_app_wdf_end       ( app_wdf_end               ),
	  .c0_ddr4_app_wdf_mask      ( app_wdf_mask              ), 
	  .c0_ddr4_app_wdf_wren      ( app_wdf_wren              ),
	  .c0_ddr4_app_rd_data       ( app_rd_data               ), 
	  .c0_ddr4_app_rd_data_end   ( app_rd_data_end           ),
	  .c0_ddr4_app_rd_data_valid ( app_rd_data_valid         ),
	  .c0_ddr4_app_rdy           ( app_rdy                   ),
	  .c0_ddr4_app_wdf_rdy       ( app_wdf_rdy               )
	`ifdef XUPP3R_BOARD
	,
	  .c0_ddr4_ecc_err_addr      (                           ),            // output wire [51 : 0] c0_ddr4_ecc_err_addr
	  .c0_ddr4_ecc_single        (                           ),                // output wire [7 : 0] c0_ddr4_ecc_single
	  .c0_ddr4_ecc_multiple      (                           ),            // output wire [7 : 0] c0_ddr4_ecc_multiple
	  .c0_ddr4_app_correct_en_i  ( 1'b1                      ),     // input wire c0_ddr4_app_correct_en_i
	  .c0_ddr4_parity            ( ddr_parity                )                        // output wire c0_ddr4_parity
	`endif
	);
	
	`else // PITONSYS_DDR4
	mig_7series_0   mig_7series_0 (
	    // Memory interface ports
	`ifndef NEXYS4DDR_BOARD
	    .ddr3_addr                      (ddr_addr),
	    .ddr3_ba                        (ddr_ba),
	    .ddr3_cas_n                     (ddr_cas_n),
	    .ddr3_ck_n                      (ddr_ck_n),
	    .ddr3_ck_p                      (ddr_ck_p),
	    .ddr3_cke                       (ddr_cke),
	    .ddr3_ras_n                     (ddr_ras_n),
	    .ddr3_reset_n                   (ddr_reset_n),
	    .ddr3_we_n                      (ddr_we_n),
	    .ddr3_dq                        (ddr_dq),
	    .ddr3_dqs_n                     (ddr_dqs_n),
	    .ddr3_dqs_p                     (ddr_dqs_p),
	`ifndef NEXYSVIDEO_BOARD
	    .ddr3_cs_n                      (ddr_cs_n),
	`endif // endif NEXYSVIDEO_BOARD
	    .ddr3_dm                        (ddr_dm),
	    .ddr3_odt                       (ddr_odt),
	`else // ifdef NEXYS4DDR_BOARD
	    .ddr2_addr                      (ddr_addr),
	    .ddr2_ba                        (ddr_ba),
	    .ddr2_cas_n                     (ddr_cas_n),
	    .ddr2_ck_n                      (ddr_ck_n),
	    .ddr2_ck_p                      (ddr_ck_p),
	    .ddr2_cke                       (ddr_cke),
	    .ddr2_ras_n                     (ddr_ras_n),
	    .ddr2_we_n                      (ddr_we_n),
	    .ddr2_dq                        (ddr_dq),
	    .ddr2_dqs_n                     (ddr_dqs_n),
	    .ddr2_dqs_p                     (ddr_dqs_p),
	    .ddr2_cs_n                      (ddr_cs_n),
	    .ddr2_dm                        (ddr_dm),
	    .ddr2_odt                       (ddr_odt),
	`endif // endif NEXYS4DDR_BOARD
	
	    .init_calib_complete            (init_calib_complete),
	
	    // Application interface ports
	    .app_addr                       (app_addr),
	    .app_cmd                        (app_cmd),
	    .app_en                         (app_en),
	    .app_wdf_data                   (app_wdf_data),
	    .app_wdf_end                    (app_wdf_end),
	    .app_wdf_wren                   (app_wdf_wren),
	    .app_rd_data                    (app_rd_data),
	    .app_rd_data_end                (app_rd_data_end),
	    .app_rd_data_valid              (app_rd_data_valid),
	    .app_rdy                        (app_rdy),
	    .app_wdf_rdy                    (app_wdf_rdy),
	    .app_sr_req                     (app_sr_req),
	    .app_ref_req                    (app_ref_req),
	    .app_zq_req                     (app_zq_req),
	    .app_sr_active                  (app_sr_active),
	    .app_ref_ack                    (app_ref_ack),
	    .app_zq_ack                     (app_zq_ack),
	    .ui_clk                         (ui_clk),
	    .ui_clk_sync_rst                (ui_clk_sync_rst),
	    .app_wdf_mask                   (app_wdf_mask),
	
	    // System Clock Ports
	    .sys_clk_i                      (sys_clk),
	    .sys_rst                        (sys_rst_n)
	);
	
	ila_2 ila_native(
	  .clk(ui_clk), //input clk;
	  .probe0({1'b0,app_addr}), //input [29:0]probe0;
	  .probe1(app_cmd), //input [2:0]probe1;
	  .probe2(app_wdf_data), //input [255:0]probe2;
	  .probe3(app_wdf_mask), //input [31:0]probe3;
	  .probe4(app_rd_data), //input [255:0]probe4;
	  .probe5(10'b0), //input [9:0]probe5;
	  .probe6(app_en), //input [0:0]probe6;
	  .probe7(app_wdf_wren), //input [0:0]probe7;
	  .probe8(app_rd_data_valid), //input [0:0]probe8;
	  .probe9(app_rd_data_end), //input [0:0]probe9;
	  .probe10(app_rdy), //input [0:0]probe10;
	  .probe11(app_wdf_rdy), //input [0:0]probe11;
	  .probe12(1'b0), //input [0:0]probe11;
	  .probe13(1'b0), //input [0:0]probe11;
	  .probe14(1'b0), //input [0:0]probe11;
	  .probe15(1'b0) //input [0:0]probe11;
	);
	
	
	
	`endif // PITONSYS_DDR4

`else // PITONSYS_AXI4_MEM //below for AXI4_MEM enabled

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
	
	`ifdef PITONSYS_DDR4
	
	ddr4_axi4 ddr_axi4 (
	  .sys_rst                   ( ~sys_rst_n                ),
	  .c0_sys_clk_p              ( sys_clk_p                 ),
	  .c0_sys_clk_n              ( sys_clk_n                 ),
	  .dbg_clk                   (                           ), // not used 
	  .dbg_bus                   (                           ), // not used
	  .c0_ddr4_ui_clk            ( ui_clk                    ),
	  .c0_ddr4_ui_clk_sync_rst   ( ui_clk_sync_rst           ),
	  
	  .c0_ddr4_act_n             ( ddr_act_n                 ), // cas_n, ras_n and we_n are multiplexed in ddr4
	  .c0_ddr4_adr               ( ddr_addr                  ),
	  .c0_ddr4_ba                ( ddr_ba                    ),
	  .c0_ddr4_bg                ( ddr_bg                    ), // bank group address
	  .c0_ddr4_cke               ( ddr_cke                   ),
	  .c0_ddr4_odt               ( ddr_odt                   ),
	  .c0_ddr4_cs_n              ( ddr_cs_n                  ),
	  .c0_ddr4_ck_t              ( ddr_ck_p                  ),
	  .c0_ddr4_ck_c              ( ddr_ck_n                  ),
	  .c0_ddr4_reset_n           ( ddr_reset_n               ),
	`ifndef XUPP3R_BOARD
	  .c0_ddr4_dm_dbi_n          ( ddr_dm                    ), // dbi_n is a data bus inversion feature that cannot be used simultaneously with dm
	`endif
	  .c0_ddr4_dq                ( ddr_dq                    ), 
	  .c0_ddr4_dqs_c             ( ddr_dqs_n                 ), 
	  .c0_ddr4_dqs_t             ( ddr_dqs_p                 ), 
	  .c0_init_calib_complete    ( init_calib_complete       ),
	`ifdef XUPP3R_BOARD
	  .c0_ddr4_parity            ( ddr_parity                ),                        // output wire c0_ddr4_parity
	`endif
	  .c0_ddr4_interrupt         (                           ),                    // output wire c0_ddr4_interrupt
	  .c0_ddr4_aresetn           ( sys_rst_n                 ),                        // input wire c0_ddr4_aresetn
	  
	  .c0_ddr4_s_axi_ctrl_awvalid(1'b0                  ),  // input wire c0_ddr4_s_axi_ctrl_awvalid
	  .c0_ddr4_s_axi_ctrl_awready(                      ),  // output wire c0_ddr4_s_axi_ctrl_awready
	  .c0_ddr4_s_axi_ctrl_awaddr (32'b0                 ),    // input wire [31 : 0] c0_ddr4_s_axi_ctrl_awaddr
	  .c0_ddr4_s_axi_ctrl_wvalid (1'b0                  ),    // input wire c0_ddr4_s_axi_ctrl_wvalid
	  .c0_ddr4_s_axi_ctrl_wready (                      ),    // output wire c0_ddr4_s_axi_ctrl_wready
	  .c0_ddr4_s_axi_ctrl_wdata  (32'b0                 ),      // input wire [31 : 0] c0_ddr4_s_axi_ctrl_wdata
	  .c0_ddr4_s_axi_ctrl_bvalid (                      ),    // output wire c0_ddr4_s_axi_ctrl_bvalid
	  .c0_ddr4_s_axi_ctrl_bready (1'b0                  ),    // input wire c0_ddr4_s_axi_ctrl_bready
	  .c0_ddr4_s_axi_ctrl_bresp  (                      ),      // output wire [1 : 0] c0_ddr4_s_axi_ctrl_bresp
	  .c0_ddr4_s_axi_ctrl_arvalid(1'b0                  ),  // input wire c0_ddr4_s_axi_ctrl_arvalid
	  .c0_ddr4_s_axi_ctrl_arready(                      ),  // output wire c0_ddr4_s_axi_ctrl_arready
	  .c0_ddr4_s_axi_ctrl_araddr (32'b0                 ),    // input wire [31 : 0] c0_ddr4_s_axi_ctrl_araddr
	  .c0_ddr4_s_axi_ctrl_rvalid (                      ),    // output wire c0_ddr4_s_axi_ctrl_rvalid
	  .c0_ddr4_s_axi_ctrl_rready (1'b0                  ),    // input wire c0_ddr4_s_axi_ctrl_rready
	  .c0_ddr4_s_axi_ctrl_rdata  (                      ),      // output wire [31 : 0] c0_ddr4_s_axi_ctrl_rdata
	  .c0_ddr4_s_axi_ctrl_rresp  (                      ),      // output wire [1 : 0] c0_ddr4_s_axi_ctrl_rresp
	  
	  .c0_ddr4_s_axi_awid(m_axi_awid),                  // input wire [15 : 0] c0_ddr4_s_axi_awid
	  .c0_ddr4_s_axi_awaddr(m_axi_awaddr),              // input wire [34 : 0] c0_ddr4_s_axi_awaddr
	  .c0_ddr4_s_axi_awlen(m_axi_awlen),                // input wire [7 : 0] c0_ddr4_s_axi_awlen
	  .c0_ddr4_s_axi_awsize(m_axi_awsize),              // input wire [2 : 0] c0_ddr4_s_axi_awsize
	  .c0_ddr4_s_axi_awburst(m_axi_awburst),            // input wire [1 : 0] c0_ddr4_s_axi_awburst
	  .c0_ddr4_s_axi_awlock(m_axi_awlock),              // input wire [0 : 0] c0_ddr4_s_axi_awlock
	  .c0_ddr4_s_axi_awcache(m_axi_awcache),            // input wire [3 : 0] c0_ddr4_s_axi_awcache
	  .c0_ddr4_s_axi_awprot(m_axi_awprot),              // input wire [2 : 0] c0_ddr4_s_axi_awprot
	  .c0_ddr4_s_axi_awqos(m_axi_awqos),                // input wire [3 : 0] c0_ddr4_s_axi_awqos
	  .c0_ddr4_s_axi_awvalid(m_axi_awvalid),            // input wire c0_ddr4_s_axi_awvalid
	  .c0_ddr4_s_axi_awready(m_axi_awready),            // output wire c0_ddr4_s_axi_awready
	  .c0_ddr4_s_axi_wdata(m_axi_wdata),                // input wire [511 : 0] c0_ddr4_s_axi_wdata
	  .c0_ddr4_s_axi_wstrb(m_axi_wstrb),                // input wire [63 : 0] c0_ddr4_s_axi_wstrb
	  .c0_ddr4_s_axi_wlast(m_axi_wlast),                // input wire c0_ddr4_s_axi_wlast
	  .c0_ddr4_s_axi_wvalid(m_axi_wvalid),              // input wire c0_ddr4_s_axi_wvalid
	  .c0_ddr4_s_axi_wready(m_axi_wready),              // output wire c0_ddr4_s_axi_wready
	  .c0_ddr4_s_axi_bready(m_axi_bready),              // input wire c0_ddr4_s_axi_bready
	  .c0_ddr4_s_axi_bid(m_axi_bid),                    // output wire [15 : 0] c0_ddr4_s_axi_bid
	  .c0_ddr4_s_axi_bresp(m_axi_bresp),                // output wire [1 : 0] c0_ddr4_s_axi_bresp
	  .c0_ddr4_s_axi_bvalid(m_axi_bvalid),              // output wire c0_ddr4_s_axi_bvalid
	  .c0_ddr4_s_axi_arid(m_axi_arid),                  // input wire [15 : 0] c0_ddr4_s_axi_arid
	  .c0_ddr4_s_axi_araddr(m_axi_araddr),              // input wire [34 : 0] c0_ddr4_s_axi_araddr
	  .c0_ddr4_s_axi_arlen(m_axi_arlen),                // input wire [7 : 0] c0_ddr4_s_axi_arlen
	  .c0_ddr4_s_axi_arsize(m_axi_arsize),              // input wire [2 : 0] c0_ddr4_s_axi_arsize
	  .c0_ddr4_s_axi_arburst(m_axi_arburst),            // input wire [1 : 0] c0_ddr4_s_axi_arburst
	  .c0_ddr4_s_axi_arlock(m_axi_arlock),              // input wire [0 : 0] c0_ddr4_s_axi_arlock
	  .c0_ddr4_s_axi_arcache(m_axi_arcache),            // input wire [3 : 0] c0_ddr4_s_axi_arcache
	  .c0_ddr4_s_axi_arprot(m_axi_arprot),              // input wire [2 : 0] c0_ddr4_s_axi_arprot
	  .c0_ddr4_s_axi_arqos(m_axi_arqos),                // input wire [3 : 0] c0_ddr4_s_axi_arqos
	  .c0_ddr4_s_axi_arvalid(m_axi_arvalid),            // input wire c0_ddr4_s_axi_arvalid
	  .c0_ddr4_s_axi_arready(m_axi_arready),            // output wire c0_ddr4_s_axi_arready
	  .c0_ddr4_s_axi_rready(m_axi_rready),              // input wire c0_ddr4_s_axi_rready
	  .c0_ddr4_s_axi_rlast(m_axi_rlast),                // output wire c0_ddr4_s_axi_rlast
	  .c0_ddr4_s_axi_rvalid(m_axi_rvalid),              // output wire c0_ddr4_s_axi_rvalid
	  .c0_ddr4_s_axi_rresp(m_axi_rresp),                // output wire [1 : 0] c0_ddr4_s_axi_rresp
	  .c0_ddr4_s_axi_rid(m_axi_rid),                    // output wire [15 : 0] c0_ddr4_s_axi_rid
	  .c0_ddr4_s_axi_rdata(m_axi_rdata)                 // output wire [511 : 0] c0_ddr4_s_axi_rdata
	);
	
	`else // PITONSYS_DDR4
	
	//Custom Design Block - Hacd
	//CUSTOM MODULE
	//START
	//VT HEAP LAB HACD
	   //CPU<->HACD
	    //hacd will observe these for request signals from cpu
	    //HACD_AXI_WR_BUS#() cpu_axi_wr_bus();
	    //HACD_AXI_RD_BUS#() cpu_axi_rd_bus();
	    //
	    ////HACD<->MC
	    ////hacd will act as request master on request singslas to mc 
	    //HACD_MC_AXI_WR_BUS#() mc_axi_wr_bus();
	    //HACD_MC_AXI_RD_BUS#() mc_axi_rd_bus();
	
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
	    .s_axi_awid                     (mc_axi_wr_bus.axi_awid),  // input [15:0]          s_axi_awid
	    .s_axi_awaddr                   (mc_axi_wr_bus.axi_awaddr),  // input [29:0]            s_axi_awaddr
	    .s_axi_awlen                    (mc_axi_wr_bus.axi_awlen),  // input [7:0]          s_axi_awlen
	    .s_axi_awsize                   (mc_axi_wr_bus.axi_awsize),  // input [2:0]         s_axi_awsize
	    .s_axi_awburst                  (mc_axi_wr_bus.axi_awburst),  // input [1:0]            s_axi_awburst
	    .s_axi_awlock                   (mc_axi_wr_bus.axi_awlock),  // input [0:0]         s_axi_awlock
	    .s_axi_awcache                  (mc_axi_wr_bus.axi_awcache),  // input [3:0]            s_axi_awcache
	    .s_axi_awprot                   (mc_axi_wr_bus.axi_awprot),  // input [2:0]         s_axi_awprot
	    .s_axi_awqos                    (mc_axi_wr_bus.axi_awqos),  // input [3:0]          s_axi_awqos
	    .s_axi_awvalid                  (mc_axi_wr_bus.axi_awvalid),  // input          s_axi_awvalid
	    .s_axi_awready                  (mc_axi_wr_bus.axi_awready),  // output         s_axi_awready
	    // Slave Interface Write Data Ports
	    .s_axi_wdata                    (mc_axi_wr_bus.axi_wdata),  // input [511:0]            s_axi_wdata
	    .s_axi_wstrb                    (mc_axi_wr_bus.axi_wstrb),  // input [63:0]         s_axi_wstrb
	    .s_axi_wlast                    (mc_axi_wr_bus.axi_wlast),  // input            s_axi_wlast
	    .s_axi_wvalid                   (mc_axi_wr_bus.axi_wvalid),  // input           s_axi_wvalid
	    .s_axi_wready                   (mc_axi_wr_bus.axi_wready),  // output          s_axi_wready
	    // Slave Interface Write Response Ports
	    .s_axi_bid                      (mc_axi_wr_bus.axi_bid),  // output [15:0]          s_axi_bid
	    .s_axi_bresp                    (mc_axi_wr_bus.axi_bresp),  // output [1:0]         s_axi_bresp
	    .s_axi_bvalid                   (mc_axi_wr_bus.axi_bvalid),  // output          s_axi_bvalid
	    .s_axi_bready                   (mc_axi_wr_bus.axi_bready),  // input           s_axi_bready
	    // Slave Interface Read Address Ports
	    .s_axi_arid                     (mc_axi_rd_bus.axi_arid),  // input [15:0]          s_axi_arid
	    .s_axi_araddr                   (mc_axi_rd_bus.axi_araddr),  // input [29:0]            s_axi_araddr
	    .s_axi_arlen                    (mc_axi_rd_bus.axi_arlen),  // input [7:0]          s_axi_arlen
	    .s_axi_arsize                   (mc_axi_rd_bus.axi_arsize),  // input [2:0]         s_axi_arsize
	    .s_axi_arburst                  (mc_axi_rd_bus.axi_arburst),  // input [1:0]            s_axi_arburst
	    .s_axi_arlock                   (mc_axi_rd_bus.axi_arlock),  // input [0:0]         s_axi_arlock
	    .s_axi_arcache                  (mc_axi_rd_bus.axi_arcache),  // input [3:0]            s_axi_arcache
	    .s_axi_arprot                   (mc_axi_rd_bus.axi_arprot),  // input [2:0]         s_axi_arprot
	    .s_axi_arqos                    (mc_axi_rd_bus.axi_arqos),  // input [3:0]          s_axi_arqos
	    .s_axi_arvalid                  (mc_axi_rd_bus.axi_arvalid),  // input          s_axi_arvalid
	    .s_axi_arready                  (mc_axi_rd_bus.axi_arready),  // output         s_axi_arready
	    // Slave Interface Read Data Ports
	    .s_axi_rid                      (mc_axi_rd_bus.axi_rid),  // output [15:0]          s_axi_rid
	    .s_axi_rdata                    (mc_axi_rd_bus.axi_rdata),  // output [511:0]           s_axi_rdata
	    .s_axi_rresp                    (mc_axi_rd_bus.axi_rresp),  // output [1:0]         s_axi_rresp
	    .s_axi_rlast                    (mc_axi_rd_bus.axi_rlast),  // output           s_axi_rlast
	    .s_axi_rvalid                   (mc_axi_rd_bus.axi_rvalid),  // output          s_axi_rvalid
	    .s_axi_rready                   (mc_axi_rd_bus.axi_rready),  // input           s_axi_rready
	
	    // System Clock Ports
	    .sys_clk_i                      (sys_clk),
	    .sys_rst                        (sys_rst_n) // input sys_rst
	);
	
	`endif // PITONSYS_DDR4
`endif // PITONSYS_AXI4_MEM

`ifdef PITON_PROTO
`ifndef PITON_PROTO_NO_MON
`ifndef PITONSYS_AXI4_MEM

    always @(posedge ui_clk) begin
        if (app_en) begin
            $display("MC_TOP: command to MIG. Addr: 0x%x, cmd: 0x%x at", app_addr, app_cmd, $time);
        end

        if (app_wdf_wren) begin
            $display("MC_TOP: writing data 0x%x to memory at", app_wdf_data, $time);
        end

        if (app_rd_data_valid) begin
            $display("MC_TOP: read data 0x%x from memory at", app_rd_data, $time);
        end
    end

`endif  // PITONSYS_AXI4_MEM
`endif  // PITON_PROTO_NO_MON
`endif  // PITON_PROTO


`ifdef PITONSYS_AXI4_MEM

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

`endif //PITONSYS_AXI4_MEM


`ifdef HAWK_FPGA
wire dump_mem;

hacd_top  #(
	.NOC_DWIDTH(`DATA_WIDTH),
        .HacdBase       ( 64'h000000fff5100000 ),
        .SwapEndianess  (               1 )
) 
u_hacd_top (
        .cfg_clk_i                    ( core_ref_clk),
        .cfg_rst_ni                   ( sys_rst_n),
    	.clk_i              (ui_clk                    ), 

	 `ifdef PITONSYS_AXI4_MEM 
    		.rst_ni              (~noc_axi4_bridge_rst),
	 `else
		.rst_ni              (~noc_mig_bridge_rst),
	 `endif

	.hawk_sw_ctrl(hawk_sw_ctrl),
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

`else

`ifdef PITONSYS_AXI4_MEM

localparam DOWN_RATIO = `HACD_AXI4_DATA_WIDTH/`HACD_MC_AXI4_DATA_WIDTH;
    logic [DOWN_RATIO-1:0][`HACD_MC_AXI4_DATA_WIDTH-1:0]   axi_slave_w_data_i;
    logic [DOWN_RATIO-1:0][`HACD_MC_AXI4_STRB_WIDTH-1:0]   axi_slave_w_strb_i;
genvar i;
generate
for(i=0;i<DOWN_RATIO;i=i+1) begin
assign axi_slave_w_data_i[i] =  cpu_axi_wr_bus.axi_wdata[(`HACD_MC_AXI4_DATA_WIDTH*(i+1)) -1 :`HACD_MC_AXI4_DATA_WIDTH*i];
assign axi_slave_w_strb_i[i] = cpu_axi_wr_bus.axi_wstrb[(`HACD_MC_AXI4_STRB_WIDTH*(i+1)) -1 :`HACD_MC_AXI4_STRB_WIDTH*i];
end
endgenerate

//logic temp_wready,temp_wready_comboloop_fix;
//always @(posedge ui_clk or posedge noc_axi4_bridge_rst) begin
//	if(noc_axi4_bridge_rst) begin
//	   temp_wready <=1'b0;
//	end else begin
//	   temp_wready <=temp_wready_comboloop_fix;
//	end
//end
//assign cpu_axi_wr_bus.axi_wready=temp_wready;

axi_size_conv_DOWNSIZE # 
(
    .AXI_ADDR_WIDTH(`HACD_AXI4_ADDR_WIDTH),
    //slave side
    .AXI_DATA_WIDTH_IN(`HACD_AXI4_DATA_WIDTH),
    .AXI_USER_WIDTH_IN(`HACD_AXI4_USER_WIDTH),
    .AXI_ID_WIDTH_IN(`HACD_AXI4_ID_WIDTH),
    
    //master side
    .AXI_DATA_WIDTH_OUT(`HACD_MC_AXI4_DATA_WIDTH),
    .AXI_USER_WIDTH_OUT(`HACD_MC_AXI4_USER_WIDTH),
    .AXI_ID_WIDTH_OUT(`HACD_MC_AXI4_ID_WIDTH)

) u_axi_size_DOWNSIZE (
    .clk_i              (ui_clk ),  
    .rst_ni              (~noc_axi4_bridge_rst      ),
    // AXI4 SLAVE : for us, it is xbar should drive here
    //***************************************
    // WRITE ADDRESS CHANNEL
    .axi_slave_aw_valid_i(cpu_axi_wr_bus.axi_awvalid),
    .axi_slave_aw_addr_i(cpu_axi_wr_bus.axi_awaddr),
    .axi_slave_aw_prot_i(cpu_axi_wr_bus.axi_awprot),
    .axi_slave_aw_region_i(cpu_axi_wr_bus.axi_awregion),
    .axi_slave_aw_len_i(cpu_axi_wr_bus.axi_awlen),
    .axi_slave_aw_size_i(cpu_axi_wr_bus.axi_awsize),
    .axi_slave_aw_burst_i(cpu_axi_wr_bus.axi_awburst),
    .axi_slave_aw_lock_i(cpu_axi_wr_bus.axi_awlock),
    .axi_slave_aw_cache_i(cpu_axi_wr_bus.axi_awcache),
    .axi_slave_aw_qos_i(cpu_axi_wr_bus.axi_awqos),
    .axi_slave_aw_id_i(cpu_axi_wr_bus.axi_awid),
    .axi_slave_aw_user_i(cpu_axi_wr_bus.axi_awuser),
    .axi_slave_aw_ready_o(cpu_axi_wr_bus.axi_awready),

    // READ ADDRESS CHANNEL
    .axi_slave_ar_valid_i(cpu_axi_rd_bus.axi_arvalid),
    .axi_slave_ar_addr_i(cpu_axi_rd_bus.axi_araddr),
    .axi_slave_ar_prot_i(cpu_axi_rd_bus.axi_arprot),
    .axi_slave_ar_region_i(cpu_axi_rd_bus.axi_arregion),
    .axi_slave_ar_len_i(cpu_axi_rd_bus.axi_arlen),
    .axi_slave_ar_size_i(cpu_axi_rd_bus.axi_arsize),
    .axi_slave_ar_burst_i(cpu_axi_rd_bus.axi_arburst),
    .axi_slave_ar_lock_i(cpu_axi_rd_bus.axi_arlock),
    .axi_slave_ar_cache_i(cpu_axi_rd_bus.axi_arcache),
    .axi_slave_ar_qos_i(cpu_axi_rd_bus.axi_arqos),
    .axi_slave_ar_id_i(cpu_axi_rd_bus.axi_arid),
    .axi_slave_ar_user_i(cpu_axi_rd_bus.axi_aruser),
    .axi_slave_ar_ready_o(cpu_axi_rd_bus.axi_arready),

    // WRITE DATA CHANNEL
    .axi_slave_w_valid_i(cpu_axi_wr_bus.axi_wvalid),
    .axi_slave_w_data_i(axi_slave_w_data_i),
    .axi_slave_w_strb_i(axi_slave_w_strb_i),
    .axi_slave_w_user_i(cpu_axi_wr_bus.axi_wuser),
    .axi_slave_w_last_i(cpu_axi_wr_bus.axi_wlast),
    .axi_slave_w_ready_o(cpu_axi_wr_bus.axi_wready), //(temp_wready_comboloop_fix), //(cpu_axi_wr_bus.axi_wready),


    // READ DATA CHANNEL
    .axi_slave_r_valid_o(cpu_axi_rd_bus.axi_rvalid),
    .axi_slave_r_data_o(cpu_axi_rd_bus.axi_rdata),
    .axi_slave_r_resp_o(cpu_axi_rd_bus.axi_rresp),
    .axi_slave_r_last_o(cpu_axi_rd_bus.axi_rlast),
    .axi_slave_r_id_o(cpu_axi_rd_bus.axi_rid),
    .axi_slave_r_user_o(cpu_axi_rd_bus.axi_ruser),
    .axi_slave_r_ready_i(cpu_axi_rd_bus.axi_rready),

    // WRITE RESPONSE CHANNEL
    .axi_slave_b_valid_o(cpu_axi_wr_bus.axi_bvalid),
    .axi_slave_b_resp_o(cpu_axi_wr_bus.axi_bresp),
    .axi_slave_b_id_o(cpu_axi_wr_bus.axi_bid),
    .axi_slave_b_user_o(cpu_axi_wr_bus.axi_buser),
    .axi_slave_b_ready_i(cpu_axi_wr_bus.axi_bready),

    //master port 
    //axi xbar in our case (size conversion is with respect to
    //master : xbar (512) -> mc (256)
    //***************************************
    // WRITE ADDRESS CHANNEL
    .axi_master_aw_valid_o(mc_axi_wr_bus.axi_awvalid),
    .axi_master_aw_addr_o(mc_axi_wr_bus.axi_awaddr),
    .axi_master_aw_prot_o(mc_axi_wr_bus.axi_awprot),
    .axi_master_aw_region_o(mc_axi_wr_bus.axi_awregion),
    .axi_master_aw_len_o(mc_axi_wr_bus.axi_awlen),
    .axi_master_aw_size_o(mc_axi_wr_bus.axi_awsize),
    .axi_master_aw_burst_o(mc_axi_wr_bus.axi_awburst),
    .axi_master_aw_lock_o(mc_axi_wr_bus.axi_awlock),
    .axi_master_aw_cache_o(mc_axi_wr_bus.axi_awcache),
    .axi_master_aw_qos_o(mc_axi_wr_bus.axi_awqos),
    .axi_master_aw_id_o(mc_axi_wr_bus.axi_awid),
    .axi_master_aw_user_o(mc_axi_wr_bus.axi_awuser),
    .axi_master_aw_ready_i(mc_axi_wr_bus.axi_awready),

    // READ ADDRESS CHANNEL
    .axi_master_ar_valid_o(mc_axi_rd_bus.axi_arvalid),
    .axi_master_ar_addr_o(mc_axi_rd_bus.axi_araddr),
    .axi_master_ar_prot_o(mc_axi_rd_bus.axi_arprot),
    .axi_master_ar_region_o(mc_axi_rd_bus.axi_arregion),
    .axi_master_ar_len_o(mc_axi_rd_bus.axi_arlen),
    .axi_master_ar_size_o(mc_axi_rd_bus.axi_arsize),
    .axi_master_ar_burst_o(mc_axi_rd_bus.axi_arburst),
    .axi_master_ar_lock_o(mc_axi_rd_bus.axi_arlock),
    .axi_master_ar_cache_o(mc_axi_rd_bus.axi_arcache),
    .axi_master_ar_qos_o(mc_axi_rd_bus.axi_arqos),
    .axi_master_ar_id_o(mc_axi_rd_bus.axi_arid),
    .axi_master_ar_user_o(mc_axi_rd_bus.axi_aruser),
    .axi_master_ar_ready_i(mc_axi_rd_bus.axi_arready),

    // WRITE DATA CHANNEL
    .axi_master_w_valid_o(mc_axi_wr_bus.axi_wvalid),
    .axi_master_w_data_o(mc_axi_wr_bus.axi_wdata),
    .axi_master_w_strb_o(mc_axi_wr_bus.axi_wstrb),
    .axi_master_w_user_o(mc_axi_wr_bus.axi_wuser),
    .axi_master_w_last_o(mc_axi_wr_bus.axi_wlast),
    .axi_master_w_ready_i(mc_axi_wr_bus.axi_wready),

    // READ DATA CHANNEL
    .axi_master_r_valid_i(mc_axi_rd_bus.axi_rvalid),
    .axi_master_r_data_i(mc_axi_rd_bus.axi_rdata),
    .axi_master_r_resp_i(mc_axi_rd_bus.axi_rresp),
    .axi_master_r_last_i(mc_axi_rd_bus.axi_rlast),
    .axi_master_r_id_i(mc_axi_rd_bus.axi_rid),
    .axi_master_r_user_i(mc_axi_rd_bus.axi_ruser),
    .axi_master_r_ready_o(mc_axi_rd_bus.axi_rready),

    // WRITE RESPONSE CHANNEL
    .axi_master_b_valid_i(mc_axi_wr_bus.axi_bvalid),
    .axi_master_b_resp_i(mc_axi_wr_bus.axi_bresp),
    .axi_master_b_id_i(mc_axi_wr_bus.axi_bid),
    .axi_master_b_user_i(mc_axi_wr_bus.axi_buser),
    .axi_master_b_ready_o(mc_axi_wr_bus.axi_bready)    
  );		
`endif

`endif


ila_1 debug_hawk_mc 
   (.clk(ui_clk),
    .probe0(1'b0), //(ui_clk),
    .probe40(~noc_axi4_bridge_rst),
    // Slave Interface Write Address Ports
    .probe19                  (mc_axi_wr_bus.axi_awid[6:0]),  // input [5:0]          s_axi_awid
    .probe1                   (mc_axi_wr_bus.axi_awaddr),  // input [29:0]            s_axi_awaddr
    .probe21                  (mc_axi_wr_bus.axi_awlen),  // input [7:0]          s_axi_awlen
    .probe17                   (mc_axi_wr_bus.axi_awsize),  // input [2:0]         s_axi_awsize
    .probe2                  (mc_axi_wr_bus.axi_awburst),  // input [1:0]            s_axi_awburst
    .probe3 (mc_axi_wr_bus.axi_awlock),  // input [0:0]         s_axi_awlock
    .probe31 (mc_axi_wr_bus.axi_awcache),  // input [3:0]            s_axi_awcache
    .probe18 (mc_axi_wr_bus.axi_awprot),  // input [2:0]         s_axi_awprot
    .probe32 (mc_axi_wr_bus.axi_awqos),  // input [3:0]          s_axi_awqos
    .probe4 (mc_axi_wr_bus.axi_awvalid),  // input          s_axi_awvalid
    .probe6 (mc_axi_wr_bus.axi_awready),  // output         s_axi_awready
    // Slave Interface Write Data Ports
    .probe10 (mc_axi_wr_bus.axi_wdata),  // input [255:0]            s_axi_wdata
    .probe15 (mc_axi_wr_bus.axi_wstrb),  // input [31:0]         s_axi_wstrb
    .probe7 (mc_axi_wr_bus.axi_wlast),  // input            s_axi_wlast
    .probe8 (mc_axi_wr_bus.axi_wvalid),  // input           s_axi_wvalid
    .probe9 (mc_axi_wr_bus.axi_wready),  // output          s_axi_wready
    // Slave Interface Write Response Ports
    .probe20 (mc_axi_wr_bus.axi_bid[6:0]),  // output [5:0]          s_axi_bid
    .probe13 (mc_axi_wr_bus.axi_bresp),  // output [1:0]         s_axi_bresp
    .probe11 (mc_axi_wr_bus.axi_bvalid),  // output          s_axi_bvalid
    .probe12 (mc_axi_wr_bus.axi_bready),  // input           s_axi_bready
    // Slave Interface Read Address Ports
    .probe25 (mc_axi_rd_bus.axi_arid[6:0]),  // input [5:0]          s_axi_arid
    .probe5 (mc_axi_rd_bus.axi_araddr),  // input [29:0]            s_axi_araddr
    .probe27 (mc_axi_rd_bus.axi_arlen),  // input [7:0]          s_axi_arlen
    .probe23	(mc_axi_rd_bus.axi_arsize),  // input [2:0]         s_axi_arsize
    .probe24 (mc_axi_rd_bus.axi_arburst),  // input [1:0]            s_axi_arburst
    .probe22 (mc_axi_rd_bus.axi_arlock),  // input [0:0]         s_axi_arlock
    .probe33 (mc_axi_rd_bus.axi_arcache),  // input [3:0]            s_axi_arcache
    .probe28 (mc_axi_rd_bus.axi_arprot),  // input [2:0]         s_axi_arprot
    .probe34 (mc_axi_rd_bus.axi_arqos),  // input [3:0]          s_axi_arqos
    .probe16 (mc_axi_rd_bus.axi_arvalid),  // input          s_axi_arvalid
    .probe26 (mc_axi_rd_bus.axi_arready),  // output         s_axi_arready
    // Slave Interface Read Data Ports
    .probe38 (mc_axi_rd_bus.axi_rid[6:0]),  // output [5:0]          s_axi_rid
    .probe14 (mc_axi_rd_bus.axi_rdata),  // output [255:0]           s_axi_rdata
    .probe29 (mc_axi_rd_bus.axi_rresp),  // output [1:0]         s_axi_rresp
    .probe30(mc_axi_rd_bus.axi_rlast),  // output           s_axi_rlast
    .probe35 (mc_axi_rd_bus.axi_rvalid),  // output          s_axi_rvalid
    .probe39 (mc_axi_rd_bus.axi_rready),  // input           s_axi_rready

    .probe41 ('d0), //ddr_we_n),
    .probe42 ('d0),
    .probe43 ('d0),

    .probe36 ('d0),
    .probe37 ('d0)

);

/*

ila_0 debug_hawk_noc_axi 
   (.clk(ui_clk),
    .probe0(1'b0), //(ui_clk),
    .probe40(~noc_axi4_bridge_rst),
    // Slave Interface Write Address Ports
    .probe19                  (cpu_axi_wr_bus.axi_awid),  // input [5:0]          s_axi_awid
    .probe1                   (cpu_axi_wr_bus.axi_awaddr),  // input [29:0]            s_axi_awaddr
    .probe21                  (cpu_axi_wr_bus.axi_awlen),  // input [7:0]          s_axi_awlen
    .probe17                   (cpu_axi_wr_bus.axi_awsize),  // input [2:0]         s_axi_awsize
    .probe2                  (cpu_axi_wr_bus.axi_awburst),  // input [1:0]            s_axi_awburst
    .probe3 (cpu_axi_wr_bus.axi_awlock),  // input [0:0]         s_axi_awlock
    .probe31 (cpu_axi_wr_bus.axi_awcache),  // input [3:0]            s_axi_awcache
    .probe18 (cpu_axi_wr_bus.axi_awprot),  // input [2:0]         s_axi_awprot
    .probe32 (cpu_axi_wr_bus.axi_awqos),  // input [3:0]          s_axi_awqos
    .probe4 (cpu_axi_wr_bus.axi_awvalid),  // input          s_axi_awvalid
    .probe6 (cpu_axi_wr_bus.axi_awready),  // output         s_axi_awready
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
    .probe5 (cpu_axi_rd_bus.axi_araddr),  // input [29:0]            s_axi_araddr
    .probe27 (cpu_axi_rd_bus.axi_arlen),  // input [7:0]          s_axi_arlen
    .probe23	(cpu_axi_rd_bus.axi_arsize),  // input [2:0]         s_axi_arsize
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

    .probe41 ('d0), //ddr_we_n),
    .probe42 ('d0),
    .probe43 ('d0),

    .probe36 ('d0),
    .probe37 ('d0)

);

*/

/*
  input clk;
  input [0:0]probe0;//
  input [63:0]probe1;//
  input [1:0]probe2;//
  input [0:0]probe3;//
  input [0:0]probe4;//
  input [63:0]probe5; //
  input [0:0]probe6; //
  input [0:0]probe7; //
  input [0:0]probe8;//
  input [0:0]probe9;//
  input [255:0]probe10; //
  input [0:0]probe11; //
  input [0:0]probe12;//
  input [1:0]probe13; //
  input [255:0]probe14;//
  input [31:0]probe15;//
  input [0:0]probe16; //
  input [2:0]probe17;//
  input [2:0]probe18;//
  input [5:0]probe19;//
  input [5:0]probe20;//
  input [7:0]probe21;//
  input [0:0]probe22; //
  input [2:0]probe23; //
  input [1:0]probe24; //
  input [5:0]probe25;//
  input [0:0]probe26;//
  input [7:0]probe27; //
  input [2:0]probe28; //
  input [1:0]probe29;  //
  input [0:0]probe30;//
  input [3:0]probe31;//
  input [3:0]probe32;//
  input [3:0]probe33;// 
  input [3:0]probe34;//
  input [0:0]probe35; //
  input [3:0]probe36; //UNUSED
  input [3:0]probe37; //UNUSED
  input [5:0]probe38;//
  input [0:0]probe39; //
  input [0:0]probe40;//
  input [0:0]probe41; //UNUSED
  input [0:0]probe42; //UNUSED
  input [0:0]probe43; //UNUSED
*/

endmodule 
