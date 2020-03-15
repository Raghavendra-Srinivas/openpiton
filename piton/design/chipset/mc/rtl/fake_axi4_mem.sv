module  fake_axi4_mem (
    input clk                ,  
    input rst_n              , 
    HACD_MC_AXI_WR_BUS.slv wr_bus, 
    HACD_MC_AXI_RD_BUS.slv rd_bus
   );

typedef bit [63:0] ADDR;
logic [`HACD_MC_AXI4_DATA_WIDTH-1:0] MEM[ADDR]; 
//For Phase one of Hawk, we do not require read and write at same time.
////and also no outstading is supported
//Write
int wr_beat_cnt,rd_beat_cnt,i;
int temp_beat_cnt=0;
initial
begin
	fork 
		begin : MANAGE_WRITE
			//Wait for reset
			@(negedge rst_n);
			  wr_bus.axi_awready <=1;
			  wr_bus.axi_wready <=1;

			forever begin
			  wr_bus.axi_awready <=1;
			  @(posedge clk);
				//hawk design makes sure , we get wvalid only
				//after or alogn with awvalid, so we are safe
				//here
				if(wr_bus.axi_awvalid & wr_bus.axi_awready) begin
			  		wr_bus.axi_awready <=0;
					wr_beat_cnt=wr_bus.axi_awlen;
					for(int i=0;i<=wr_beat_cnt;i=i+1) begin
						@(posedge clk); //add timeput if required later
						if (wr_bus.axi_wvalid && (wr_bus.axi_wstrb!=0)) begin
							MEM[wr_bus.axi_awaddr+i*64'd32]=wr_bus.axi_wdata & wr_bus.axi_wstrb;
						end
					end
				end
			end
		end : MANAGE_WRITE
		begin : MANAGE_READ
			//Wait for reset
			@(negedge rst_n);
			  rd_bus.axi_arready <=1;
			  rd_bus.axi_rvalid<=0;
			  rd_bus.axi_rresp<=0;
			  rd_bus.axi_rdata<='dx;
			  rd_bus.axi_rlast<=0;

			forever begin
			  rd_bus.axi_arready <=1;
			  @(posedge clk);
				//hawk design makes sure , we get wvalid only
				//after or alogn with awvalid, so we are safe
				//here
				if(rd_bus.axi_arvalid & rd_bus.axi_arready) begin
			  		rd_bus.axi_arready <=0;
					rd_beat_cnt=rd_bus.axi_arlen+1;
					temp_beat_cnt=0;
						while(temp_beat_cnt<rd_beat_cnt) begin
						@(posedge clk); //add timeput if required later
						rd_bus.axi_rvalid<=0;
						rd_bus.axi_rdata<='dx;
			  			rd_bus.axi_rresp<='dx;
						rd_bus.axi_rlast<=0;
						if(rd_bus.axi_rready==1'b1) begin
							rd_bus.axi_rvalid<=1; 
			  				rd_bus.axi_rresp<=0;
							rd_bus.axi_rdata<=MEM[rd_bus.axi_araddr+i*64'd32];
							temp_beat_cnt = temp_beat_cnt +1;
							rd_bus.axi_rlast<=temp_beat_cnt==rd_beat_cnt;
							
						end

					end//while
					@(posedge clk);
					rd_bus.axi_rvalid<=0;
					rd_bus.axi_rdata<='dx;
			  		rd_bus.axi_rresp<='dx;
					rd_bus.axi_rlast<=0;
				end
			end
		end: MANAGE_READ
	join
end

//function dump_mem();
//endfunction
endmodule
/*
module  fake_axi4_mem (
    input clk                ,  
    input rst_n              , 
    HACD_MC_AXI_WR_BUS.slv wr_bus, 
    HACD_MC_AXI_RD_BUS.slv rd_bus
   );

 	assign wr_bus.axi_awready =1;
 	assign wr_bus.axi_wready =1;
 	assign rd_bus.axi_arready =1;
	assign rd_bus.axi_rvalid=0;
	assign rd_bus.axi_rresp=0;
	assign rd_bus.axi_rdata='dx;
	assign rd_bus.axi_rlast=0;

endmodule
*/
