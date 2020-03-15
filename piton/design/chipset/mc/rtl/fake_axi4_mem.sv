
import hacd_pkg::*; 
module  fake_axi4_mem (
    input clk                ,  
    input rst_n              , 
    HACD_MC_AXI_WR_BUS.slv wr_bus, 
    HACD_MC_AXI_RD_BUS.slv rd_bus
   );

typedef bit [63:0] ADDR;
logic [`HACD_MC_AXI4_DATA_WIDTH-1:0] MEM[ADDR][2]; 
//For Phase one of Hawk, we do not require read and write at same time.
////and also no outstading is supported
//Write
int wr_beat_cnt,rd_beat_cnt,i;
int temp_beat_cnt=0;
int bt_cnt_wr=0;
bit [63:0] capt_addr;
wire [`HACD_MC_AXI4_DATA_WIDTH-1:0] mask;
genvar g;
generate
for(g=0;g<32;g=g+1) begin
	assign mask[g*8+:8]= {8{wr_bus.axi_wstrb[g]}};
end
endgenerate

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
					wr_beat_cnt=wr_bus.axi_awlen+1;
					capt_addr = wr_bus.axi_awaddr;
					if(!MEM.exists(capt_addr)) begin
					    MEM[capt_addr][0] ='d0;	
					    MEM[capt_addr][1] ='d0;	
					end
					bt_cnt_wr=0;
					while(bt_cnt_wr<wr_beat_cnt) begin
			  		@(posedge clk);
					  if(wr_bus.axi_wvalid==1'b1) begin
					  	if(wr_bus.axi_wstrb==32'h0000FFFF) begin//fr now we control only 16ibts of wstr at a time, this logic should be enough
					  		MEM[capt_addr][bt_cnt_wr]= {MEM[capt_addr][bt_cnt_wr][255:128] , wr_bus.axi_wdata[127:0]}; 
					  		$display("Observed WR TXN: ADDR:%h,DATA:%h,mask:%h",capt_addr,wr_bus.axi_wdata,wr_bus.axi_wstrb);
					  	end
					  	if(wr_bus.axi_wstrb==32'hFFFF0000) begin//fr now we control only 16ibts of wstr at a time, this logic should be enough
					  		MEM[capt_addr][bt_cnt_wr]={wr_bus.axi_wdata[255:128],MEM[capt_addr][bt_cnt_wr][127:0]} ; 
					  		$display("Observed WR TXN: ADDR:%h,DATA:%h,mask:%h",capt_addr,wr_bus.axi_wdata,wr_bus.axi_wstrb);
					  	end
					  	if(wr_bus.axi_wstrb==32'hFFFFFFFF) begin//fr now we control only 16ibts of wstr at a time, this logic should be enough
					  		MEM[capt_addr][bt_cnt_wr]=wr_bus.axi_wdata; 
					  		$display("Observed WR TXN: ADDR:%h,DATA:%h,mask:%h",capt_addr,wr_bus.axi_wdata,wr_bus.axi_wstrb);
					  	end
					        bt_cnt_wr = bt_cnt_wr + 1;
					 end//if
					end //while
				end //if
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
							rd_bus.axi_rdata<=MEM[rd_bus.axi_araddr][temp_beat_cnt];
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

`define SIZE1 64
`define SIZE2 128
`define SIZE3 192
`define LSTSIZE1 128
function dump_mem();
bit [256:0] cacheline;
AttEntry attentry[4];
ListEntry lstentry[2];
int att_cnt=0,lst_cnt=0;
foreach(MEM[addr]) begin
  $display("--------------------------cache line boundary ----------------------------------------------------");
  if( addr >= HAWK_ATT_START && addr < HAWK_LIST_START) 
  begin
    for (int i=0;i<2;i++) begin
       cacheline=MEM[addr][i];
       attentry[0].zpd_cnt=cacheline[63:57];
       attentry[0].way=cacheline[56:2];
       attentry[0].sts=cacheline[1:0];
       attentry[1].zpd_cnt=cacheline[`SIZE1+63:`SIZE1+57];
       attentry[1].way=cacheline[`SIZE1+56:`SIZE1+2];
       attentry[1].sts=cacheline[`SIZE1+1:`SIZE1+0];
       attentry[2].zpd_cnt=cacheline[`SIZE2+63:`SIZE2+57];
       attentry[2].way=cacheline[`SIZE2+56:`SIZE2+2];
       attentry[2].sts=cacheline[`SIZE2+1:`SIZE2+0];
       attentry[3].zpd_cnt=cacheline[`SIZE3+63:`SIZE3+57];
       attentry[3].way=cacheline[`SIZE3+56:`SIZE3+2];
       attentry[3].sts=cacheline[`SIZE3+1:`SIZE3+0];
     for (int j=0;j<4;j++) begin
       $display("CACHE/DRAM ADDR: %h ATT_%d || zpd_cnt:%h || way:%h || sts:%h", addr,att_cnt/*4*i+j*/,attentry[j].zpd_cnt,attentry[j].way,attentry[j].sts); //cacheline[(i+1)*64-1:i*64]); 
	att_cnt = att_cnt + 1;
     end //for
    end //for
  end//if
  else if ( addr >= HAWK_LIST_START && addr < HAWK_PPA_START) begin
     for (int i=0;i<2;i++) begin
       cacheline=MEM[addr][i];
       //$display("Half cache line: ADDR:%h: DATA:%h",addr,cacheline);	
       lstentry[0].rsvd=cacheline[127:104];
       lstentry[0].way=cacheline[103:54];
       lstentry[0].prev=cacheline[53:28];
       lstentry[0].next=cacheline[27:0];
       lstentry[1].rsvd=cacheline[`LSTSIZE1+127:`LSTSIZE1+104];
       lstentry[1].way=cacheline[`LSTSIZE1+103:`LSTSIZE1+54];
       lstentry[1].prev=cacheline[`LSTSIZE1+53:`LSTSIZE1+28];
       lstentry[1].next=cacheline[`LSTSIZE1+27:`LSTSIZE1+0];
     for (int j=0;j<2;j++) begin
       $display("CACHE/DRAM ADDR: %h LST_%d || way:%h || prev:%d || next:%d", addr,lst_cnt,lstentry[j].way,lstentry[j].prev,lstentry[j].next); //cacheline[(i+1)*64-1:i*64]); 
	lst_cnt = lst_cnt + 1;
     end //for
   end //for 
  end //if

end //foreach
endfunction

final begin
  dump_mem();
end


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
