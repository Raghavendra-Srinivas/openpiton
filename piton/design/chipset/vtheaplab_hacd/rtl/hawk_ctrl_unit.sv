/////////////////////////////////////////////////////////////////////////////////
//
// Heap Lab Research
// Block : Hawk Control Unit 
// 
// Author : Raghavendra Srinivas
// Contact : raghavs@vt.edu	
/////////////////////////////////////////////////////////////////////////////////
// Description: Unit to control and manage entire hawk operations.
// 		Architecture plan is to pipeline multiple requests of CPU, and
// 		this unit take care off look up att table (with local att cache as
// 		planned in previous architecture) , find victim page to
// 		compress, or uncompress compressed page. Deliver this
// 		compress/uncompress burst mode to read and write page
// 		managers, while control unit can paralley lookup for pending
// 		requests.
// 		But for bringup, this majority of operations is handled by page
// 		managers itself.
// 		So, control unit here is really light now
/////////////////////////////////////////////////////////////////////////////////
//local defines
`define FSM_WID 4
module hawk_ctrl_unit #()
(

    input clk_i,
    input rst_ni,

    //pg_writer handshake
    input init_att_done,
    input init_list_done,
    
    //cpu master handshake
    input cpu_vld_access,
    
    //to control with hawk_pg_writer
    output logic init_att,
    output logic init_list,
    output logic hold_hwk_wr,
    output logic hold_hwk_rd,
    
    //to control cpu interface
    output logic hold_cpu
);



//local variables
logic n_hold_hwk_wr, n_hold_cpu;
logic n_init_att,n_init_list;
logic [`FSM_WID-1:0] n_state;
logic [`FSM_WID-1:0] p_state;
//states
localparam IDLE			='d0,
	   CHK_RD_ACTIVE 	='d1,
	   CHK_WR_ACTIVE 	='d2,
	   RD_LOOKUP_ALLOCATE	='d3,
	   WR_LOOKUP_ALLOCATE	='d4,
	   TBL_UPDATE_RD	='d5,
	   TBL_UPDATE_WR	='d6;

//state & output register
always_ff@(posedge clk_i or negedge rst_ni) 
begin
	if(!rst_ni) begin
		p_state<=IDLE;

		//output regs
		hold_hwk_wr<=1'b0;
		hold_cpu<=1'b1; //by default, we don't allow cpu to boot/make access to dram
		init_att<=1'b1; //init_att is enabled upon reset
		init_list<=1'b1; //init_att is enabled upon reset
	end
	else begin
		p_state<=n_state;

		//output regs
		hold_hwk_wr<=n_hold_hwk_wr;
		hold_cpu<=n_hold_cpu;
		init_att<=n_init_att;
		init_list<=n_init_list;
	end
end

att_lkup_reqpkt_t lkup_reqpkt;
//fsm combo
always_comb
begin
	n_state=p_state;
	n_init_att=init_att;
	n_init_list=init_list;
	n_allow_cpu_wr_access=0;
	n_allow_cpu_rd_access=0;
	n_lkup_reqpkt='d0
	case(p_state)
		IDLE: begin
			if(init_att_done) begin //wait in same state till table initialiation is done
				n_init_att=1'b0;
			end
			else if (init_list_done) begin
				n_init_list=1'b0;
				n_state=ACTIVE;
			end
		end
		CHK_RD_ACTIVE:begin
			if(cpu_rd_pkt.valid) begin //this can be optimized , if we treat rd and write as separate as 
						 //also, later once we have interncal cache, cu unit itlsef into it, if not
						 //found then only sends to look up att.
				n_lkup_reqpkt.lookup=1'b1;
				n_lkup_reqpkt.hppa=cpu_rd_pkt.hppa;	 
			  	n_state=RD_LOOKUP_ALLOCATE;
			end
			else n_state = CHK_WR_ACTIVE;
			//chk if we need fairness among wries and read later
			//however even if we priotise reads over
			//writes, coherecny should not be breoken, even if read
			//comes on same line as write, which is not yet written. It
			//should be handled at system level /one cache before memory
			//controller
		CHK_WR_ACTIVE: begin
			 if (cpu_wr_pkt.valid) begin
				n_lkup_reqpkt.lookup=1'b1;
				n_lkup_reqpkt.hppa=cpu_wr_pkt.hppa;	 
			  	n_state=WR_LOOKUP_ALLOCATE;
		  	 end
			else n_state = CHK_RD_ACTIVE;
		end
		RD_LOOKUP_ALLOCATE: begin
				if(allow_cpu_access) begin 
					n_allow_cpu_rd_access<=1'b1;
					n_state<=ACTIVE;
				end
				else if (tbl_update) begin
					n_state=RD_TBL_UPDATE;
				end
				//handle inflation later
				//else if (infl)
			end
		end
		WR_LOOKUP_ALLOCATE: begin
				if(allow_cpu_access) begin 
					n_allow_cpu_wr_access<=1'b1;
					n_state<=ACTIVE;
				end
				else if (tbl_update) begin
					n_state=WR_TBL_UPDATE;
				end
				//handle inflation later
				//else if (infl)
			end
		end
		//THe below can be moved hawk_pgrd_manager, but later it helps
		//to pipeline look up for pending operations while update
		//table for pendign 
		TBL_UPDATE_RD:begin
				if(tbl_update_done) begin
					n_allow_cpu_rd_access<=1'b1;
					n_state<=ACTIVE;
				end
		end
		TBL_UPDATE_WR:begin
				if(tbl_update_done) begin
					n_allow_cpu_wr_access<=1'b1;
					n_state<=ACTIVE;
				end
		end
	endcase
end

//Flops/State
//state register/output flops
always @(posedge clk_i or negedge rst_ni)
begin
	if(!rst_ni) begin
		p_state<=IDLE;
		allow_cpu_rd_access<=1'b0;
		allow_cpu_wr_access<=1'b0;
	end
	else begin
		p_state<=n_state;
		allow_cpu_rd_access<=n_allow_cpu_rd_access;
		allow_cpu_wr_access<=n_allow_cpu_wr_access;
	end
end


endmodule
