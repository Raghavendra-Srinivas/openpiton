
// Copyright (c) 2019 Princeton University
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
`include "mc_define.h"
`include "noc_axi4_bridge_define.vh"

module axi4_zeroer (
    input   clk,
    input   rst_n,

    input   init_calib_complete_in,
    output  init_calib_complete_out,

    // AXI interface in
    input wire  [`HAWK_MC_AXI4_ID_WIDTH     -1:0]     s_axi_awid,
    input wire  [`HAWK_MC_AXI4_ADDR_WIDTH   -1:0]     s_axi_awaddr,
    input wire  [`HAWK_MC_AXI4_LEN_WIDTH    -1:0]     s_axi_awlen,
    input wire  [`HAWK_MC_AXI4_SIZE_WIDTH   -1:0]     s_axi_awsize,
    input wire  [`HAWK_MC_AXI4_BURST_WIDTH  -1:0]     s_axi_awburst,
    input wire                                s_axi_awlock,
    input wire  [`HAWK_MC_AXI4_CACHE_WIDTH  -1:0]     s_axi_awcache,
    input wire  [`HAWK_MC_AXI4_PROT_WIDTH   -1:0]     s_axi_awprot,
    input wire  [`HAWK_MC_AXI4_QOS_WIDTH    -1:0]     s_axi_awqos,
    input wire  [`HAWK_MC_AXI4_REGION_WIDTH -1:0]     s_axi_awregion,
    input wire  [`HAWK_MC_AXI4_USER_WIDTH   -1:0]     s_axi_awuser,
    input wire                                s_axi_awvalid,
    output reg                                s_axi_awready,

    input wire   [`HAWK_MC_AXI4_ID_WIDTH     -1:0]    s_axi_wid,
    input wire   [`HAWK_MC_AXI4_DATA_WIDTH   -1:0]    s_axi_wdata,
    input wire   [`HAWK_MC_AXI4_STRB_WIDTH   -1:0]    s_axi_wstrb,
    input wire                                s_axi_wlast,
    input wire   [`HAWK_MC_AXI4_USER_WIDTH   -1:0]    s_axi_wuser,
    input wire                                s_axi_wvalid,
    output reg                                s_axi_wready,

    input wire   [`HAWK_MC_AXI4_ID_WIDTH     -1:0]    s_axi_arid,
    input wire   [`HAWK_MC_AXI4_ADDR_WIDTH   -1:0]    s_axi_araddr,
    input wire   [`HAWK_MC_AXI4_LEN_WIDTH    -1:0]    s_axi_arlen,
    input wire   [`HAWK_MC_AXI4_SIZE_WIDTH   -1:0]    s_axi_arsize,
    input wire   [`HAWK_MC_AXI4_BURST_WIDTH  -1:0]    s_axi_arburst,
    input wire                                s_axi_arlock,
    input wire   [`HAWK_MC_AXI4_CACHE_WIDTH  -1:0]    s_axi_arcache,
    input wire   [`HAWK_MC_AXI4_PROT_WIDTH   -1:0]    s_axi_arprot,
    input wire   [`HAWK_MC_AXI4_QOS_WIDTH    -1:0]    s_axi_arqos,
    input wire   [`HAWK_MC_AXI4_REGION_WIDTH -1:0]    s_axi_arregion,
    input wire   [`HAWK_MC_AXI4_USER_WIDTH   -1:0]    s_axi_aruser,
    input wire                                s_axi_arvalid,
    output reg                                s_axi_arready,

    output reg  [`HAWK_MC_AXI4_ID_WIDTH     -1:0]     s_axi_rid,
    output reg  [`HAWK_MC_AXI4_DATA_WIDTH   -1:0]     s_axi_rdata,
    output reg  [`HAWK_MC_AXI4_RESP_WIDTH   -1:0]     s_axi_rresp,
    output reg                                s_axi_rlast,
    output reg  [`HAWK_MC_AXI4_USER_WIDTH   -1:0]     s_axi_ruser,
    output reg                                s_axi_rvalid,
    input wire                                s_axi_rready,

    output reg  [`HAWK_MC_AXI4_ID_WIDTH     -1:0]     s_axi_bid,
    output reg  [`HAWK_MC_AXI4_RESP_WIDTH   -1:0]     s_axi_bresp,
    output reg  [`HAWK_MC_AXI4_USER_WIDTH   -1:0]     s_axi_buser,
    output reg                                s_axi_bvalid,
    input wire                                s_axi_bready,    

    // AXI interface out
    output reg  [`HAWK_MC_AXI4_ID_WIDTH     -1:0]     m_axi_awid,
    output reg  [`HAWK_MC_AXI4_ADDR_WIDTH   -1:0]     m_axi_awaddr,
    output reg  [`HAWK_MC_AXI4_LEN_WIDTH    -1:0]     m_axi_awlen,
    output reg  [`HAWK_MC_AXI4_SIZE_WIDTH   -1:0]     m_axi_awsize,
    output reg  [`HAWK_MC_AXI4_BURST_WIDTH  -1:0]     m_axi_awburst,
    output reg                                m_axi_awlock,
    output reg  [`HAWK_MC_AXI4_CACHE_WIDTH  -1:0]     m_axi_awcache,
    output reg  [`HAWK_MC_AXI4_PROT_WIDTH   -1:0]     m_axi_awprot,
    output reg  [`HAWK_MC_AXI4_QOS_WIDTH    -1:0]     m_axi_awqos,
    output reg  [`HAWK_MC_AXI4_REGION_WIDTH -1:0]     m_axi_awregion,
    output reg  [`HAWK_MC_AXI4_USER_WIDTH   -1:0]     m_axi_awuser,
    output reg                                m_axi_awvalid,
    input  wire                               m_axi_awready,

    output reg   [`HAWK_MC_AXI4_ID_WIDTH     -1:0]    m_axi_wid,
    output reg   [`HAWK_MC_AXI4_DATA_WIDTH   -1:0]    m_axi_wdata,
    output reg   [`HAWK_MC_AXI4_STRB_WIDTH   -1:0]    m_axi_wstrb,
    output reg                                m_axi_wlast,
    output reg   [`HAWK_MC_AXI4_USER_WIDTH   -1:0]    m_axi_wuser,
    output reg                                m_axi_wvalid,
    input  wire                               m_axi_wready,

    output reg   [`HAWK_MC_AXI4_ID_WIDTH     -1:0]    m_axi_arid,
    output reg   [`HAWK_MC_AXI4_ADDR_WIDTH   -1:0]    m_axi_araddr,
    output reg   [`HAWK_MC_AXI4_LEN_WIDTH    -1:0]    m_axi_arlen,
    output reg   [`HAWK_MC_AXI4_SIZE_WIDTH   -1:0]    m_axi_arsize,
    output reg   [`HAWK_MC_AXI4_BURST_WIDTH  -1:0]    m_axi_arburst,
    output reg                                m_axi_arlock,
    output reg   [`HAWK_MC_AXI4_CACHE_WIDTH  -1:0]    m_axi_arcache,
    output reg   [`HAWK_MC_AXI4_PROT_WIDTH   -1:0]    m_axi_arprot,
    output reg   [`HAWK_MC_AXI4_QOS_WIDTH    -1:0]    m_axi_arqos,
    output reg   [`HAWK_MC_AXI4_REGION_WIDTH -1:0]    m_axi_arregion,
    output reg   [`HAWK_MC_AXI4_USER_WIDTH   -1:0]    m_axi_aruser,
    output reg                                m_axi_arvalid,
    input  wire                               m_axi_arready,

    input  wire  [`HAWK_MC_AXI4_ID_WIDTH     -1:0]    m_axi_rid,
    input  wire  [`HAWK_MC_AXI4_DATA_WIDTH   -1:0]    m_axi_rdata,
    input  wire  [`HAWK_MC_AXI4_RESP_WIDTH   -1:0]    m_axi_rresp,
    input  wire                               m_axi_rlast,
    input  wire  [`HAWK_MC_AXI4_USER_WIDTH   -1:0]    m_axi_ruser,
    input  wire                               m_axi_rvalid,
    output reg                                m_axi_rready,

    input  wire  [`HAWK_MC_AXI4_ID_WIDTH     -1:0]    m_axi_bid,
    input  wire  [`HAWK_MC_AXI4_RESP_WIDTH   -1:0]    m_axi_bresp,
    input  wire  [`HAWK_MC_AXI4_USER_WIDTH   -1:0]    m_axi_buser,
    input  wire                               m_axi_bvalid,
    output reg                                m_axi_bready
);

localparam reg [63:0] BOARD_MEM_SIZE_MB = `BOARD_MEM_SIZE_MB;
localparam reg [`HAWK_MC_AXI4_ADDR_WIDTH-1:0] MAX_MEM_ADDR      = (BOARD_MEM_SIZE_MB * 2**20);
localparam REQUESTS_NEEDED  = MAX_MEM_ADDR / `HAWK_MC_AXI4_STRB_WIDTH; // basically max addr divided by size of one request
localparam MAX_OUTSTANDING = 16;

wire zeroer_req_val;
wire zeroer_wdata_val; //raghav
wire zeroer_resp_rdy;
wire req_go;
wire resp_go;
reg [`HAWK_MC_AXI4_ADDR_WIDTH-1:0] req_sent;
reg [`HAWK_MC_AXI4_ADDR_WIDTH-1:0] resp_got;
reg [3:0] outstanding;
wire [`HAWK_MC_AXI4_ADDR_WIDTH-1:0] zeroer_addr;
wire zeroer_wlast;

assign zeroer_req_val = init_calib_complete_in 
                      & (req_sent < REQUESTS_NEEDED) 
                      & (outstanding != MAX_OUTSTANDING-1) 
                      /*& m_axi_awready
                        & m_axi_wready //raghav*/
                      & rst_n;

assign zeroer_resp_rdy = init_calib_complete_in 
                       & (resp_got < REQUESTS_NEEDED) 
                       & rst_n;


localparam IDLE=0,ADDR_PHASE=1,DATA_PHASE=2;
logic [1:0] p_state,n_state;
logic m_axi_awvalid_reg,m_axi_awvalid_next;
logic m_axi_wvalid_reg,m_axi_wvalid_next;

assign req_go = m_axi_awready && m_axi_awvalid_reg; //zeroer_req_val;
assign resp_go = zeroer_resp_rdy & m_axi_bvalid;

always@* begin
	n_state=p_state;	       //be in same state unless fsm decides to jump
 	m_axi_awvalid_next=m_axi_awvalid_reg && !m_axi_awready;	
 	m_axi_wvalid_next=m_axi_wvalid_reg && !m_axi_wready;
	
	case(p_state)
		IDLE: begin
			if(zeroer_req_val) begin
				     n_state = ADDR_PHASE;
			end
		end
		ADDR_PHASE:begin
			  if(!m_axi_awvalid_reg && zeroer_req_val) begin
				m_axi_awvalid_next=1'b1;	
			  end 
			  if(init_calib_complete_out) begin
				     n_state = IDLE;
			  end		
			  else if(m_axi_awready && m_axi_awvalid_reg) begin
				     n_state = DATA_PHASE;
			  end 
		end	
		DATA_PHASE: begin //we can hve multipel beats, but for simplicity I maintin only one beat transaction per INCR type of burst on entire datapath of hawk
			  if(!m_axi_wvalid_reg) begin //data has been already set, in prev state, just assert wvalid
				     m_axi_wvalid_next = 1'b1;
			  end
			  if(m_axi_wready && m_axi_wvalid_reg) begin
				     n_state = ADDR_PHASE;
			  end 
		end
	endcase
end

always@(posedge clk or negedge rst_n) begin

    if(~rst_n) begin
	p_state<=IDLE;
	m_axi_awvalid_reg<=1'b0;
	m_axi_wvalid_reg<=1'b0;
    end
    else begin
	p_state<=n_state;
	m_axi_awvalid_reg<=m_axi_awvalid_next;
	m_axi_wvalid_reg<=m_axi_wvalid_next;
    end
end


always @(posedge clk) begin
    if(~rst_n) begin
        req_sent <= 0;
        resp_got <= 0;
        outstanding <= 0;
    end 
    else begin
        req_sent <= req_sent + req_go;
        resp_got <= resp_got + resp_go;
        outstanding <= req_go & resp_go ? outstanding 
                     : req_go           ? outstanding + 1 
                     : resp_go          ? outstanding - 1 
                     :                    outstanding;
    end
end

assign init_calib_complete_out = (req_sent == REQUESTS_NEEDED) & 
                                 (resp_got == REQUESTS_NEEDED);

assign zeroer_addr = req_sent * `HAWK_MC_AXI4_STRB_WIDTH;
//assign zeroer_wlast = zeroer_req_val;
assign zeroer_wlast =  m_axi_wvalid_reg ; //zeroer_wdata_val; //raghav

always @(*) begin
    if (~init_calib_complete_out) begin
        m_axi_awid = `HAWK_MC_AXI4_ID_WIDTH'b0;
        m_axi_awaddr = zeroer_addr;
        m_axi_awlen = `HAWK_MC_AXI4_LEN_WIDTH'b0;
        m_axi_awsize = `HAWK_MC_AXI4_SIZE_WIDTH'b110;
        m_axi_awburst = `HAWK_MC_AXI4_BURST_WIDTH'b01;
        m_axi_awlock = 1'b0;
        m_axi_awcache = `HAWK_MC_AXI4_CACHE_WIDTH'b11;
        m_axi_awprot = `HAWK_MC_AXI4_PROT_WIDTH'b10;
        m_axi_awqos = `HAWK_MC_AXI4_QOS_WIDTH'b0;
        m_axi_awregion = `HAWK_MC_AXI4_REGION_WIDTH'b0;
        m_axi_awuser = `HAWK_MC_AXI4_USER_WIDTH'b0;
        m_axi_awvalid = m_axi_awvalid_reg; //zeroer_req_val;

        m_axi_wid = `HAWK_MC_AXI4_ID_WIDTH'b0;
        //m_axi_wdata = (zeroer_addr >= 'h04000000) ? {`HAWK_MC_AXI4_DATA_WIDTH{1'b0}} : {`HAWK_MC_AXI4_DATA_WIDTH{1'b1}};
        m_axi_wdata = {`HAWK_MC_AXI4_DATA_WIDTH{1'b0}};
        m_axi_wstrb = {`HAWK_MC_AXI4_STRB_WIDTH{1'b1}};
        m_axi_wlast = zeroer_wlast;
        m_axi_wuser = `HAWK_MC_AXI4_USER_WIDTH'b0;
        m_axi_wvalid = m_axi_wvalid_reg ; //zeroer_wdata_val; //zeroer_req_val; //raghav

        m_axi_arid = `HAWK_MC_AXI4_ID_WIDTH'b0;
        m_axi_araddr = `HAWK_MC_AXI4_ADDR_WIDTH'b0;
        m_axi_arlen = `HAWK_MC_AXI4_LEN_WIDTH'b0;
        m_axi_arsize = `HAWK_MC_AXI4_SIZE_WIDTH'b110;
        m_axi_arburst = `HAWK_MC_AXI4_BURST_WIDTH'b01;
        m_axi_arlock = 1'b0;
        m_axi_arcache = `HAWK_MC_AXI4_CACHE_WIDTH'b11;
        m_axi_arprot = `HAWK_MC_AXI4_PROT_WIDTH'b10;
        m_axi_arqos = `HAWK_MC_AXI4_QOS_WIDTH'b0;
        m_axi_arregion = `HAWK_MC_AXI4_REGION_WIDTH'b0;
        m_axi_aruser = `HAWK_MC_AXI4_USER_WIDTH'b0;
        m_axi_arvalid = 1'b0;

        m_axi_rready = 1'b0;
        m_axi_bready = zeroer_resp_rdy;

        s_axi_awready = 1'b0;
        s_axi_wready = 1'b0;
        s_axi_arready = 1'b0;
        s_axi_rid = `HAWK_MC_AXI4_ID_WIDTH'b0;
        s_axi_rdata = `HAWK_MC_AXI4_DATA_WIDTH'b0;
        s_axi_rresp = `HAWK_MC_AXI4_RESP_WIDTH'b0;
        s_axi_rlast = 1'b0;
        s_axi_ruser = `HAWK_MC_AXI4_USER_WIDTH'b0;
        s_axi_rvalid = 1'b0;
        s_axi_bid = `HAWK_MC_AXI4_ID_WIDTH'b0;
        s_axi_bresp = `HAWK_MC_AXI4_RESP_WIDTH'b0;
        s_axi_buser = `HAWK_MC_AXI4_USER_WIDTH'b0;
        s_axi_bvalid = 1'b0;
    end

    else begin
        m_axi_awid = s_axi_awid;
        m_axi_awaddr = s_axi_awaddr;
        m_axi_awlen = s_axi_awlen;
        m_axi_awsize = s_axi_awsize;
        m_axi_awburst = s_axi_awburst;
        m_axi_awlock = s_axi_awlock;
        m_axi_awcache = s_axi_awcache;
        m_axi_awprot = s_axi_awprot;
        m_axi_awqos = s_axi_awqos;
        m_axi_awregion = s_axi_awregion;
        m_axi_awuser = s_axi_awuser;
        m_axi_awvalid = s_axi_awvalid;
        s_axi_awready = m_axi_awready;

        m_axi_wid = s_axi_wid;
        m_axi_wdata = s_axi_wdata;
        m_axi_wstrb = s_axi_wstrb;
        m_axi_wlast = s_axi_wlast;
        m_axi_wuser = s_axi_wuser;
        m_axi_wvalid = s_axi_wvalid;
        s_axi_wready = m_axi_wready;

        m_axi_arid = s_axi_arid;
        m_axi_araddr = s_axi_araddr;
        m_axi_arlen = s_axi_arlen;
        m_axi_arsize = s_axi_arsize;
        m_axi_arburst = s_axi_arburst;
        m_axi_arlock = s_axi_arlock;
        m_axi_arcache = s_axi_arcache;
        m_axi_arprot = s_axi_arprot;
        m_axi_arqos = s_axi_arqos;
        m_axi_arregion = s_axi_arregion;
        m_axi_aruser = s_axi_aruser;
        m_axi_arvalid = s_axi_arvalid;
        s_axi_arready = m_axi_arready;

        s_axi_rid = m_axi_rid;
        s_axi_rdata = m_axi_rdata;
        s_axi_rresp = m_axi_rresp;
        s_axi_rlast = m_axi_rlast;
        s_axi_ruser = m_axi_ruser;
        s_axi_rvalid = m_axi_rvalid;
        m_axi_rready = s_axi_rready;

        s_axi_bid = m_axi_bid;
        s_axi_bresp = m_axi_bresp;
        s_axi_buser = m_axi_buser;
        s_axi_bvalid = m_axi_bvalid;
        m_axi_bready = s_axi_bready;
    end

end

/*
ila_3 zeroer_debug (
		.clk(clk),
		.probe0({'d0,m_axi_wlast,m_axi_wvalid,m_axi_awvalid,p_state}),
		.probe1({'d0,m_axi_awaddr}),
		.probe2({'d0,req_go,req_sent}),
		.probe3({'d0,resp_go,resp_got}),
		.probe4({'d0,zeroer_req_val,init_calib_complete_in,init_calib_complete_out,outstanding}),
		.probe5('d0),
		.probe6('d0),
		.probe7('d0),
		.probe8('d0),
		.probe9('d0),
		.probe10('d0),
		.probe11('d0)
);
*/

endmodule
