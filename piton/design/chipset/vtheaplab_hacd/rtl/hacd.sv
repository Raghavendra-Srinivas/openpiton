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

//FIXME : Move helper moduels to separate files .Currently including helper modules in same file
module hacd_regs (
 
  input clk_i,  
  input rst_ni,
  // Bus Interface
  input  hacd_pkg::reg_intf_req_a32_d32 req_i,
  output hacd_pkg::reg_intf_resp_d32    resp_o,

  //Register Outputs
  output logic [31:0] low_watermark_q,
  output logic [31:0] hacd_ctrl_q
);

logic [31:0] hacd_ctrl;
logic [31:0] low_watermark;
logic low_wm_wen;
logic hacd_ctrl_wen;

always_comb begin
  resp_o.ready = 1'b1;
  resp_o.rdata = '0;
  resp_o.error = '0;
  //regs enables
  low_wm_wen = '0;
 if (req_i.valid) begin
    if (req_i.write) begin
      unique case(req_i.addr)
        32'h0: begin
          hacd_ctrl = req_i.wdata[31:0];
	  hacd_ctrl_wen = 1'b1;
        end
        32'h4: begin
          low_watermark = req_i.wdata[31:0];
	  low_wm_wen = 1'b1;
        end
        default: resp_o.error = 1'b1;
      endcase
    end else begin
      unique case(req_i.addr)
        32'h0: begin
          resp_o.rdata[31:0] = hacd_ctrl_q;
        end
        32'h4: begin
          resp_o.rdata[31:0] = low_watermark_q;
        end
        default: resp_o.error = 1'b1;
      endcase
    end //write
   end //valid
end //always_comb

//Registers
   always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      low_watermark_q <= '0;
      hacd_ctrl_q <= '0;
    end else begin
      low_watermark_q <= low_wm_wen ? low_watermark : low_watermark_q;
      hacd_ctrl_q <= hacd_ctrl_wen ? hacd_ctrl : hacd_ctrl_q;
    end
   end
 
endmodule

module hacd #
(parameter MODE=0
) (
	clk_i,
	rst_ni,
	infl_interrupt,
	defl_interrupt,

	//Reg Bus Interface
	req_i,
	resp_o,

	//CPU<->HACD
        //hacd will observe these for request signals from cpu
        HACD_AXI_WR_BUS.mstr cpu_axi_wr_bus,  
        HACD_AXI_RD_BUS.mstr cpu_axi_rd_bus,  
        
        //HACD<->MC
        //hacd will act as request master on request singslas to mc 
        HACD_MC_AXI_WR_BUS mc_axi_wr_bus, 
        HACD_MC_AXI_RD_BUS mc_axi_rd_bus

);
  input logic clk_i;
  input logic rst_ni;
  output infl_interrupt;
  output defl_interrupt;
  // Bus Interface
  input  hacd_pkg::reg_intf_req_a32_d32 req_i;
  output hacd_pkg::reg_intf_resp_d32    resp_o;

  //Local wires
  wire [31:0] w_hacd_ctrl;
  wire [31:0] w_l_wm;
 //Generate Memory write trigger interrupt for now
 assign infl_interrupt = w_hacd_ctrl[0];
 assign defl_interrupt = w_hacd_ctrl[1];

hacd_regs hacd_regs (
  .rst_ni,
  .clk_i,  
  .req_i,
  .resp_o,

  //Reg Outputs
  .low_watermark_q(w_l_wm),
  .hacd_ctrl_q(w_hacd_ctrl)
);

hacd_core u_hacd_core (
  .rst_ni,
  .clk_i,  

  .cpu_axi_wr_bus,
  .cpu_axi_rd_bus,

  .mc_axi_wr_bus,
  .mc_axi_rd_bus

);

endmodule
