
import hacd_pkg::*; 
module  fake_axi4_mem (
    input clk                ,  
    input rst_n              , 
    HACD_MC_AXI_WR_BUS.slv wr_bus, 
    HACD_MC_AXI_RD_BUS.slv rd_bus,

    input wire dump_mem
   );


//typedef struct packed{
//	bit [5:0] id;
//} axi_wr_req_t;

//axi_wr_req_t wrreq_queue[$];
bit [5:0] wrreq_queue[$];

typedef bit [63:0] ADDR;
logic [`HACD_MC_AXI4_DATA_WIDTH-1:0] MEM[ADDR][2]; 
//For Phase one of Hawk, we do not require read and write at same time.
////and also no outstading is supported
//Write
int wr_beat_cnt,rd_beat_cnt,i;
int temp_beat_cnt=0;
int bt_cnt_wr=0;
wire [`HACD_MC_AXI4_DATA_WIDTH-1:0] mask;
genvar g;
generate
for(g=0;g<32;g=g+1) begin
	assign mask[g*8+:8]= {8{wr_bus.axi_wstrb[g]}};
end
endgenerate

initial
begin
	logic [5:0] bid;
	fork 
		begin : MANAGE_WRITE
			bit [63:0] capt_addr;
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
				        //save id to push request on to queue
				        //to help drive response after storing
				        //all wdata in memory
				        bid=wr_bus.axi_awid;
					//wrreq_queue.push_back(wr_bus.axi_awid);
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
					  if(wr_bus.axi_wvalid==1'b1) begin //change below simple logic using mask to supprot byte level wdata control 

						//MEM[capt_addr][bt_cnt_wr]= MEM[capt_addr][bt_cnt_wr] | (wr_bus.axi_wdata & mask);
						for(int b=0;b<32;b++) begin
						  if(wr_bus.axi_wstrb[b]) MEM[capt_addr][bt_cnt_wr][8*b+:8] = wr_bus.axi_wdata[8*b+:8];
						end
					  	$display("AXI4_MEM:Observed WR TXN: ADDR:%h,DATA:%h,mask:%h",capt_addr,wr_bus.axi_wdata,wr_bus.axi_wstrb);
						
					

					        bt_cnt_wr = bt_cnt_wr + 1;
					 end//if
					end //while
					wrreq_queue.push_back(bid);
				end //if
			end
		end : MANAGE_WRITE
		begin : MANAGE_READ
			bit [63:0] capt_addr;
			logic [5:0] capt_id;
			//Wait for reset
			@(negedge rst_n);
			forever begin
			  rd_bus.axi_arready <=1;
			  rd_bus.axi_rvalid<=0;
			  rd_bus.axi_rresp<='dx;
			  rd_bus.axi_ruser<='dx;
			  rd_bus.axi_rdata<='dx;
			  rd_bus.axi_rlast<=0;
			  rd_bus.axi_rid<='dx;
			  @(posedge clk);
				//hawk design makes sure , we get wvalid only
				//after or alogn with awvalid, so we are safe
				//here
				if(rd_bus.axi_arvalid & rd_bus.axi_arready) begin
					capt_addr = rd_bus.axi_araddr;
					capt_id=rd_bus.axi_arid;
					if(!MEM.exists(capt_addr)) begin
					    MEM[capt_addr][0] ='d0;	
					    MEM[capt_addr][1] ='d0;	
					end
			  		rd_bus.axi_arready <=0;
					rd_beat_cnt=rd_bus.axi_arlen+1;
					$display("AXI4_MEM:Observed RD TXN: ADDR:%h, ARlen =; %d",capt_addr,rd_beat_cnt);
					temp_beat_cnt=0;
					while(temp_beat_cnt<rd_beat_cnt) begin
						@(posedge clk); //add timeput if required later
						rd_bus.axi_rvalid<=0;
						rd_bus.axi_rdata<='d0;
			  			rd_bus.axi_rresp<='d0;
			  			rd_bus.axi_ruser<='d0;
						rd_bus.axi_rlast<=0;
			  			rd_bus.axi_rid<='d0;
						if(rd_bus.axi_rready==1'b1) begin
							$display("AXI4_MEM:Observed RREADY for : ADDR:%h,",capt_addr);
							rd_bus.axi_rvalid<=1; 
			  				rd_bus.axi_rresp<=0;
			  				rd_bus.axi_ruser<='d0;
			  				rd_bus.axi_rid<=capt_id;
							rd_bus.axi_rdata<=MEM[capt_addr][temp_beat_cnt];
							temp_beat_cnt = temp_beat_cnt +1;
							rd_bus.axi_rlast<=temp_beat_cnt==rd_beat_cnt;
						end

					end//while
					@(posedge clk);
					rd_bus.axi_rvalid<=0;
					rd_bus.axi_rdata<='d0;
			  		rd_bus.axi_rresp<='d0;
			  		rd_bus.axi_ruser<='d0;
			  		rd_bus.axi_rid<='d0;
					rd_bus.axi_rlast<=0;
				end
			end
		end: MANAGE_READ
	join
end

//Manage Write Response
initial begin
	//bit [5:0] bid;
	fork 
	 begin :MANAGE_BRESP
		forever begin
		      //@(posedge clk);
				wr_bus.axi_bvalid<=1'b0;
				wr_bus.axi_buser<='d0;
		      wait(wrreq_queue.size()>0);
			//Have random delay here for robusting later	
			@(posedge clk);
				   $display("AXI4 FAKE MEM : Sending Bresp  =%t",$time);
				   wr_bus.axi_bid<=wrreq_queue.pop_front();	
				   wr_bus.axi_bresp<='d0;
				   wr_bus.axi_buser<='d0;
				   wr_bus.axi_bvalid<=1'b1;
				  //we should remain asserted till we see
				  //bready high on posedge from master
				  while(wr_bus.axi_bready!==1'b1) begin
		      			@(posedge clk);
				  end
		end
	 end : MANAGE_BRESP
	join 
end


function bit [255:0] get_unswapped_line;
	input bit [255:0] line;
	integer i,j;
	bit [63:0] eightByte,swappedEightByte;

  	for(i=0;i<4;i=i+1) begin //4*8bytes = 32bytes per half cacheline
		//Take first 8byte
		eightByte = line[(64*i)+:64];
		//within 8byte swap bytes
		for(j=0;j<8;j=j+1) begin //byteswap in each 8bytes 
			swappedEightByte[8*j+:8] = eightByte[(63-8*j)-:8];
		end
		get_unswapped_line[(64*i)+:64]=swappedEightByte;
	end
endfunction

`define SIZE1 64
`define SIZE2 128
`define SIZE3 192
`define LSTSIZE1 128
function automatic bit dump_mem_func();
input int cnt;
input [17:0] freeListHead;
input [17:0] freeListTail;
input [17:0] uncompListHead;
input [17:0] uncompListTail;

bit [255:0] cacheline,reverseswap;
AttEntry attentry[4];
ListEntry lstentry[2];
int att_cnt=cnt,lst_enry_id=cnt;

string listentry_name;
bit [17:0] prev_free_next,prev_uncomp_next;

//Print Current Head and Tail of lists
$display("--------------------------ToL Head and Tails----------------------------------------------------");
$display("  FreeList HEAD : %0d" ,freeListHead);
$display("  FreeList TAIL : %0d" ,freeListTail);
$display("UncompList HEAD : %0d" ,uncompListHead);
$display("UncompList TAIL : %0d" ,uncompListTail);
$display("------------------------------------------------------------------------------------------------");
foreach(MEM[addr]) begin
  $display("--------------------------cache line boundary ----------------------------------------------------");
  if( addr >= HAWK_ATT_START && addr < HAWK_LIST_START) 
  begin
    for (int i=0;i<2;i++) begin
       cacheline=MEM[addr][i];
       //8byteSwap within 8byte word
       //reverseswap=MEM[addr][i];
       //cacheline=get_unswapped_line(reverseswap);	

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
        case(attentry[j].sts)
 	2'b00: listentry_name="FREE     ";
 	2'b01: listentry_name="UCMP     ";
 	2'b10: listentry_name="COMP     ";
 	2'b11: listentry_name="ICMP     ";
	endcase
       $display("CACHE/DRAM ADDR: %h ATT_ENTRY->%s: %0d || zpd_cnt:%0h || way:%0h || sts:%0h", addr,listentry_name,att_cnt/*4*i+j*/,attentry[j].zpd_cnt,attentry[j].way,attentry[j].sts); //cacheline[(i+1)*64-1:i*64]); 
	att_cnt = att_cnt + 1;
     end //for
    end //for
  end//if
  else if ( addr >= HAWK_LIST_START && addr < HAWK_PPA_START) begin
     for (int i=0;i<2;i++) begin
       cacheline=MEM[addr][i];
       //reverseswap=MEM[addr][i];
       //cacheline=get_unswapped_line(reverseswap);	
       //$display("Half cache line: ADDR:%h: DATA:%h",addr,cacheline);	
       lstentry[0].rsvd=cacheline[127:114];
       lstentry[0].way=cacheline[113:64];
       lstentry[0].prev=cacheline[63:32];
       lstentry[0].next=cacheline[31:0];
       lstentry[1].rsvd=cacheline[`LSTSIZE1+127:`LSTSIZE1+114];
       lstentry[1].way=cacheline[`LSTSIZE1+113:`LSTSIZE1+64];
       lstentry[1].prev=cacheline[`LSTSIZE1+63:`LSTSIZE1+32];
       lstentry[1].next=cacheline[`LSTSIZE1+31:`LSTSIZE1+0];
     for (int j=0;j<2;j++) begin

	///Initialize 
        if (freeListHead==lst_enry_id) begin
	   prev_free_next=lstentry[j].next;
	end else if (uncompListHead==lst_enry_id) begin
	   prev_uncomp_next=lstentry[j].next;
	end
	//detect head/tails or head-tail or middle entries
	if(lstentry[j].prev=='d0 && lstentry[j].next=='d0) begin
        	if (freeListHead==lst_enry_id) begin
			listentry_name="FREE_HEAL";
		end else if  (uncompListHead==lst_enry_id) begin
			listentry_name="UCMP_HEAL";
		end
	end
	else if(lstentry[j].prev=='d0) begin
        	if (freeListHead==lst_enry_id) begin
			listentry_name="FREE_HEAD";
		        prev_free_next=lstentry[j].next;
		end else if  (uncompListHead==lst_enry_id) begin
			listentry_name="UCMP_HEAD";
		        prev_uncomp_next=lstentry[j].next;
		end
        end 
	else if (lstentry[j].next=='d0) begin
		if  (freeListTail==lst_enry_id) begin
			listentry_name="FREE_TAIL";
		end else if  (uncompListTail==lst_enry_id) begin
			listentry_name="UCMP_TAIL";
		end
        end
        else begin //middle entries
		if(prev_free_next==lst_enry_id) begin
			listentry_name="FREE     ";
	   		prev_free_next=lstentry[j].next; //update my next
		end else if(prev_uncomp_next==lst_enry_id) begin
			listentry_name="UCMP     ";
	   		prev_uncomp_next=lstentry[j].next; //update my next
		end
	end

	 		
       $display("CACHE/DRAM ADDR: %h LST_ENTRY->%s: %0d || way:%0h || prev: %0d || next:%0d", addr,listentry_name,lst_enry_id,lstentry[j].way,lstentry[j].prev,lstentry[j].next); //cacheline[(i+1)*64-1:i*64]); 

	lst_enry_id = lst_enry_id + 1;
     end //for
   end //for 
  end //if
  else begin //normal data
    //for (int i=0;i<2;i++) begin
      //cacheline=MEM[addr][i];
      $display("CACHE/DRAM ADDR: %0h , Data=%0h", addr, {MEM[addr][1], MEM[addr][0]});
  end
end //foreach
  return 1;
endfunction
logic dump_mem_dly;
always@(posedge clk) 
	dump_mem_dly <= dump_mem;

wire [17:0] freeListHead;
wire [17:0] freeListTail;
wire [17:0] uncompListHead;
wire [17:0] uncompListTail;

assign freeListHead=cmp_top.system.chipset.chipset_impl.u_mc_top_new.u_hacd_top.u_hacd.u_hacd_core.u_hawk_pgwr_mngr.freeListHead[17:0];
assign freeListTail=cmp_top.system.chipset.chipset_impl.u_mc_top_new.u_hacd_top.u_hacd.u_hacd_core.u_hawk_pgwr_mngr.freeListTail[17:0];
assign uncompListHead=cmp_top.system.chipset.chipset_impl.u_mc_top_new.u_hacd_top.u_hacd.u_hacd_core.u_hawk_pgwr_mngr.uncompListHead[17:0];
assign uncompListTail=cmp_top.system.chipset.chipset_impl.u_mc_top_new.u_hacd_top.u_hacd.u_hacd_core.u_hawk_pgwr_mngr.uncompListTail[17:0];


initial
begin
forever begin
	@(posedge clk);
		if(!dump_mem_dly && dump_mem) dump_mem_func(1,freeListHead,freeListTail,uncompListHead,uncompListTail);
end

end



final begin
  $display("FINAL STATE of DRAM");
  dump_mem_func(1,freeListHead,freeListTail,uncompListHead,uncompListTail);
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

	/*
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
						*/

