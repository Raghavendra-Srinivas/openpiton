/////////////////////////////////////////////////////////////////////////////////
//
// Heap Lab Research
// Block: Hardware Accelerated Compressor Decompressor
// 
// Author : Raghavendra Srinivas
// Contact : raghavs@vt.edu	
/////////////////////////////////////////////////////////////////////////////////
// Description: top level module to encapsulate all module instantiation to
// support hardware accelerated compression/decompression
/////////////////////////////////////////////////////////////////////////////////

module hacd_top #(parameter int NOC_DWIDTH=32, parameter logic [63:0] HacdBase=64'h000000fff5100000, parameter bit          SwapEndianess   =  0)
(
  input cfg_clk_i                    ,
  input cfg_rst_ni                   ,
  input clk_i                    ,
  input rst_ni                   ,
  input uart_boot_en,

    input [1:0] hawk_sw_ctrl,
  output infl_interrupt           ,
  output defl_interrupt           ,
  input [NOC_DWIDTH-1:0] buf_hacd_noc2_data_i     ,
  input buf_hacd_noc2_valid_i    ,
  output hacd_buf_noc2_ready_o    ,
  output [NOC_DWIDTH-1:0] hacd_buf_noc3_data_o     ,
  output hacd_buf_noc3_valid_o    ,
  input buf_hacd_noc3_ready_i   ,

	//CPU<->HACD
        //hacd will observe these for request signals from cpu
        HACD_AXI_WR_BUS.slv cpu_axi_wr_bus,  
        HACD_AXI_RD_BUS.slv cpu_axi_rd_bus,  
        
        //HACD<->MC
        //hacd will act as request master on request singslas to mc 
        HACD_MC_AXI_WR_BUS.mstr mc_axi_wr_bus, 
        HACD_MC_AXI_RD_BUS.mstr mc_axi_rd_bus,

        output wire dump_mem, 
    	output wire alert_oom 

);


  localparam int unsigned AxiIdWidth    =  1;
  localparam int unsigned AxiAddrWidth  = 64;
  localparam int unsigned AxiDataWidth  = 64;
  localparam int unsigned AxiUserWidth  =  1;
  /////////////////////////////
  // HACD
  /////////////////////////////
//`ifndef SYNTH

  AXI_BUS #(
    .AXI_ID_WIDTH   ( AxiIdWidth   ),
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth ),
    .AXI_USER_WIDTH ( AxiUserWidth )
  ) hacd_master();

  noc_axilite_bridge #(
    // this enables variable width accesses
    // note that the accesses are still 64bit, but the
    // write-enables are generated according to the access size
    .SLAVE_RESP_BYTEWIDTH   ( 0             ),
    .SWAP_ENDIANESS         ( SwapEndianess ),
    // this disables shifting of unaligned read data
    .ALIGN_RDATA            ( 0             )
  ) i_hacd_axilite_bridge (
    .clk                    ( cfg_clk_i                        ),
    .rst                    ( ~cfg_rst_ni                      ),
    // to/from NOC
    .splitter_bridge_val    ( buf_hacd_noc2_valid_i ),
    .splitter_bridge_data   ( buf_hacd_noc2_data_i  ),
    .bridge_splitter_rdy    ( hacd_buf_noc2_ready_o ),
    .bridge_splitter_val    ( hacd_buf_noc3_valid_o ),
    .bridge_splitter_data   ( hacd_buf_noc3_data_o  ),
    .splitter_bridge_rdy    ( buf_hacd_noc3_ready_i ),
    //axi lite signals
    //write address channel
    .m_axi_awaddr           ( hacd_master.aw_addr               ),
    .m_axi_awvalid          ( hacd_master.aw_valid              ),
    .m_axi_awready          ( hacd_master.aw_ready              ),
    //write data channel
    .m_axi_wdata            ( hacd_master.w_data                ),
    .m_axi_wstrb            ( hacd_master.w_strb                ),
    .m_axi_wvalid           ( hacd_master.w_valid               ),
    .m_axi_wready           ( hacd_master.w_ready               ),
    //read address channel
    .m_axi_araddr           ( hacd_master.ar_addr               ),
    .m_axi_arvalid          ( hacd_master.ar_valid              ),
    .m_axi_arready          ( hacd_master.ar_ready              ),
    //read data channel
    .m_axi_rdata            ( hacd_master.r_data                ),
    .m_axi_rresp            ( hacd_master.r_resp                ),
    .m_axi_rvalid           ( hacd_master.r_valid               ),
    .m_axi_rready           ( hacd_master.r_ready               ),
    //write response channel
    .m_axi_bresp            ( hacd_master.b_resp                ),
    .m_axi_bvalid           ( hacd_master.b_valid               ),
    .m_axi_bready           ( hacd_master.b_ready               ),
    // non-axi-lite signals
    .w_reqbuf_size          ( hacd_master.aw_size               ),
    .r_reqbuf_size          ( hacd_master.ar_size               )
  );

  // tie off signals not used by AXI-lite
  assign hacd_master.aw_id     = '0;
  assign hacd_master.aw_len    = '0;
  assign hacd_master.aw_burst  = '0;
  assign hacd_master.aw_lock   = '0;
  assign hacd_master.aw_cache  = '0;
  assign hacd_master.aw_prot   = '0;
  assign hacd_master.aw_qos    = '0;
  assign hacd_master.aw_region = '0;
  assign hacd_master.aw_atop   = '0;
  assign hacd_master.w_last    = 1'b1;
  assign hacd_master.ar_id     = '0;
  assign hacd_master.ar_len    = '0;
  assign hacd_master.ar_burst  = '0;
  assign hacd_master.ar_lock   = '0;
  assign hacd_master.ar_cache  = '0;
  assign hacd_master.ar_prot   = '0;
  assign hacd_master.ar_qos    = '0;
  assign hacd_master.ar_region = '0;


  hacd_pkg::reg_intf_resp_d32 hacd_resp;
  hacd_pkg::reg_intf_req_a32_d32 hacd_req;

  enum logic [2:0] {Idle, WriteSecond, ReadSecond, WriteResp, ReadResp} state_d, state_q;
  logic [31:0] rword_d, rword_q;

  // register read data
  assign rword_d = (hacd_req.valid && !hacd_req.write) ? hacd_resp.rdata : rword_q;
  assign hacd_master.r_data = {hacd_resp.rdata, rword_q};

  always_ff @(posedge cfg_clk_i or negedge cfg_rst_ni) begin : p_hacd_regs
    if (!cfg_rst_ni) begin
      state_q <= Idle;
      rword_q <= '0;
    end else begin
      state_q <= state_d;
      rword_q <= rword_d;
    end
  end

  // this is a simplified AXI statemachine, since the
  // W and AW requests always arrive at the same time here
  always_comb begin : p_hacd_if
    automatic logic [31:0] waddr, raddr;
    // subtract the base offset (truncated to 32 bits)
    waddr = hacd_master.aw_addr[31:0] - 32'(HacdBase) + 32'h000000;
    raddr = hacd_master.ar_addr[31:0] - 32'(HacdBase) + 32'h000000;

    // AXI-lite
    hacd_master.aw_ready = hacd_resp.ready;
    hacd_master.w_ready  = hacd_resp.ready;
    hacd_master.ar_ready = hacd_resp.ready;

    hacd_master.r_valid  = 1'b0;
    hacd_master.r_resp   = '0;
    hacd_master.b_valid  = 1'b0;
    hacd_master.b_resp   = '0;

    // HACD
    hacd_req.valid       = 1'b0;
    hacd_req.wstrb       = '0;
    hacd_req.write       = 1'b0;
    hacd_req.wdata       = hacd_master.w_data[31:0];
    hacd_req.addr        = waddr;

    // default
    state_d              = state_q;

    unique case (state_q)
      Idle: begin
        if (hacd_master.w_valid && hacd_master.aw_valid && hacd_resp.ready) begin
          hacd_req.valid = 1'b1;
          hacd_req.write = hacd_master.w_strb[3:0];
          hacd_req.wstrb = '1;
          // this is a 64bit write, need to write second 32bit chunk in second cycle
          if (hacd_master.aw_size == 3'b11) begin
            state_d = WriteSecond;
          end else begin
            state_d = WriteResp;
          end
        end else if (hacd_master.ar_valid && hacd_resp.ready) begin
          hacd_req.valid = 1'b1;
          hacd_req.addr  = raddr;
          // this is a 64bit read, need to read second 32bit chunk in second cycle
          if (hacd_master.ar_size == 3'b11) begin
            state_d = ReadSecond;
          end else begin
            state_d = ReadResp;
          end
        end
      end
      // write high word
      WriteSecond: begin
        hacd_master.aw_ready = 1'b0;
        hacd_master.w_ready  = 1'b0;
        hacd_master.ar_ready = 1'b0;
        hacd_req.addr        = waddr + 32'h4;
        hacd_req.wdata       = hacd_master.w_data[63:32];
        if (hacd_resp.ready && hacd_master.b_ready) begin
          hacd_req.valid       = 1'b1;
          hacd_req.write       = 1'b1;
          hacd_req.wstrb       = '1;
          hacd_master.b_valid  = 1'b1;
          state_d              = Idle;
        end
      end
      // read high word
      ReadSecond: begin
        hacd_master.aw_ready = 1'b0;
        hacd_master.w_ready  = 1'b0;
        hacd_master.ar_ready = 1'b0;
        hacd_req.addr        = raddr + 32'h4;
        if (hacd_resp.ready && hacd_master.r_ready) begin
          hacd_req.valid      = 1'b1;
          hacd_master.r_valid = 1'b1;
          state_d             = Idle;
        end
      end
      WriteResp: begin
        hacd_master.aw_ready = 1'b0;
        hacd_master.w_ready  = 1'b0;
        hacd_master.ar_ready = 1'b0;
        if (hacd_master.b_ready) begin
          hacd_master.b_valid  = 1'b1;
          state_d              = Idle;
        end
      end
      ReadResp: begin
        hacd_master.aw_ready = 1'b0;
        hacd_master.w_ready  = 1'b0;
        hacd_master.ar_ready = 1'b0;
        if (hacd_master.r_ready) begin
          hacd_master.r_valid = 1'b1;
          state_d             = Idle;
        end
      end
      default: state_d = Idle;
    endcase
  end
//`endif



hacd u_hacd(

  .cfg_clk_i (cfg_clk_i),
  .cfg_rst_ni (cfg_rst_ni),
  .clk_i (clk_i),
  .rst_ni (rst_ni),
  .uart_boot_en(uart_boot_en),
  .hawk_sw_ctrl(hawk_sw_ctrl),
  .infl_interrupt (infl_interrupt),
  .defl_interrupt (defl_interrupt),

//`ifdef SYNTH
//  .req_i ('d0),
//  .resp_o (),
//`else
  .req_i (hacd_req), 
  .resp_o (hacd_resp),
//`endif

  .cpu_axi_wr_bus(cpu_axi_wr_bus),
  .cpu_axi_rd_bus(cpu_axi_rd_bus),

  .mc_axi_wr_bus(mc_axi_wr_bus),
  .mc_axi_rd_bus(mc_axi_rd_bus),
  
  .dump_mem,
  .alert_oom
);


endmodule

