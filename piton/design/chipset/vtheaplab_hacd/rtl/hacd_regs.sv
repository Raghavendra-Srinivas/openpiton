/////////////////////////////////////////////////////////////////////////////////
//
// Heap Lab Research
// Block: Hardware Accelerated Compressor Decompressor
// 
// Author : Raghavendra Srinivas
// Contact : raghavs@vt.edu	
/////////////////////////////////////////////////////////////////////////////////

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
  hacd_ctrl_wen = '0;
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
