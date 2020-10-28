/////////////////////////////////////////////////////////////////////////////////
//
// Heap Lab Research
// Block: Hardware Accelerated Compressor Decompressor
// 
// Author : Raghavendra Srinivas
// Contact : raghavs@vt.edu	
/////////////////////////////////////////////////////////////////////////////////
// Description: module to encapsulate all module instantiation to
// support hardware accelerated compression/decompression
/////////////////////////////////////////////////////////////////////////////////



module hacd #
(parameter MODE=0
) (

  input cfg_clk_i                    ,
  input cfg_rst_ni                   ,
       input logic clk_i,
       input logic rst_ni,
       input uart_boot_en,
       input [1:0] hawk_sw_ctrl,
       output infl_interrupt,
       output defl_interrupt,
       // Bus Interface
       input  hacd_pkg::reg_intf_req_a32_d32 req_i,
       output hacd_pkg::reg_intf_resp_d32    resp_o,

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

  //Local wires
  wire [31:0] w_hacd_ctrl;
  wire [31:0] w_l_wm;
  wire hawk_reg_inactive_ctrl;
 //Generate Memory write trigger interrupt for now
 assign infl_interrupt = w_hacd_ctrl[0];
 assign defl_interrupt = w_hacd_ctrl[1];
 assign hawk_reg_inactive_ctrl =  w_hacd_ctrl[2];

hacd_regs hacd_regs (
  .rst_ni(cfg_rst_ni),
  .clk_i(cfg_clk_i),  
  .req_i,
  .resp_o,

  //Reg Outputs
  .low_watermark_q(w_l_wm),
  .hacd_ctrl_q(w_hacd_ctrl)
);

hacd_core u_hacd_core (
  .rst_ni,
  .clk_i,  
  .uart_boot_en,
  .hawk_sw_ctrl(hawk_sw_ctrl),
  .hawk_reg_inactive_ctrl(hawk_reg_inactive_ctrl),

  .cpu_axi_wr_bus,
  .cpu_axi_rd_bus,

  .mc_axi_wr_bus,
  .mc_axi_rd_bus,

  .dump_mem,
  .alert_oom
);

`ifdef HAWK_FPGA_DBG
	ila_3 ila_3_hawk_reg (
		.clk(clk_i),
		.probe0({req_i.addr,resp_o.rdata}),
		.probe1({req_i.valid,req_i.write,req_i.wstrb,resp_o.error,resp_o.ready,w_l_wm})
	);
`endif


//test_aes_128 u_test_aes_128();

endmodule
