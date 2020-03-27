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
    input tbl_update_done,

    //pg_rdmanager
    input pgrd_mngr_ready,
    input hacd_pkg::trnsl_reqpkt_t trnsl_reqpkt,
    input hacd_pkg::tol_updpkt_t tol_updpkt,
    output hacd_pkg::att_lkup_reqpkt_t lkup_reqpkt,
    
    //cpu master handshake
    input hacd_pkg::cpu_reqpkt_t cpu_rd_reqpkt, 
    input hacd_pkg::cpu_reqpkt_t cpu_wr_reqpkt, 
     
    //to control with hawk_pg_writer
    output logic init_att,
    output logic init_list,
    
    //to control cpu interface
    output hacd_pkg::hawk_cpu_ovrd_pkt_t hawk_cpu_ovrd_rdpkt,
    output hacd_pkg::hawk_cpu_ovrd_pkt_t hawk_cpu_ovrd_wrpkt
);



//local variables
att_lkup_reqpkt_t n_lkup_reqpkt;
hacd_pkg::hawk_cpu_ovrd_pkt_t n_hawk_cpu_ovrd_wrpkt,n_hawk_cpu_ovrd_rdpkt;

logic n_init_att,n_init_list;
logic [`FSM_WID-1:0] n_state;
logic [`FSM_WID-1:0] p_state;
//states
localparam [`FSM_WID-1:0] IDLE			='d0,
	      		  CHK_RD_ACTIVE 	='d1,
	      		  CHK_WR_ACTIVE 	='d2,
	      		  RD_LKP_REQ		='d3,
	      		  WR_LKP_REQ		='d4,
	      		  RD_LOOKUP_ALLOCATE	='d5,
	      		  WR_LOOKUP_ALLOCATE	='d6,
	      		  RD_TBL_UPDATE		='d7,
	      		  WR_TBL_UPDATE		='d8;

//fsm
always@* 
begin
	n_state=p_state;
	n_init_att=init_att;
	n_init_list=init_list;
	n_lkup_reqpkt=lkup_reqpkt;//we need to latch lookup request till serviced
	n_hawk_cpu_ovrd_wrpkt.ppa=trnsl_reqpkt.ppa;//we need latch ppa till tbl update is done
	n_hawk_cpu_ovrd_rdpkt.ppa=trnsl_reqpkt.ppa;//we need latch ppa till tbl update is done
	n_hawk_cpu_ovrd_wrpkt.allow_access=1'b0; //this woudl be asserted in diffrent states bsed on case
	n_hawk_cpu_ovrd_rdpkt.allow_access=1'b0; //this woudl be asserted in diffrent states bsed on case
	
	case(p_state)
		IDLE: begin
			if(init_att_done) begin //wait in same state till table initialiation is done
				n_init_att=1'b0;
			end
			if (init_list_done) begin
				n_init_list=1'b0;
				n_state=CHK_RD_ACTIVE;
			end
		end
		CHK_RD_ACTIVE:begin
				if      (cpu_rd_reqpkt.valid) begin 
					n_lkup_reqpkt.hppa=cpu_rd_reqpkt.hppa;	 
				  	n_state=RD_LKP_REQ;
				end
				else if (cpu_wr_reqpkt.valid) begin
					n_lkup_reqpkt.hppa=cpu_wr_reqpkt.hppa;	 
				  	n_state=WR_LKP_REQ;
		  		end
		end
		CHK_WR_ACTIVE:begin
				if      (cpu_wr_reqpkt.valid) begin 
					n_lkup_reqpkt.hppa=cpu_rd_reqpkt.hppa;	 
				  	n_state=WR_LKP_REQ;
				end
				else if (cpu_rd_reqpkt.valid) begin
					n_lkup_reqpkt.hppa=cpu_wr_reqpkt.hppa;	 
				  	n_state=RD_LKP_REQ;
		  		end
		end
		RD_LKP_REQ: begin
			if(pgrd_mngr_ready && !hawk_cpu_ovrd_rdpkt.allow_access) begin
					n_lkup_reqpkt.lookup=1'b1;
				  	n_state=RD_LOOKUP_ALLOCATE;
			end 
		end
		WR_LKP_REQ: begin
			if(pgrd_mngr_ready && !hawk_cpu_ovrd_wrpkt.allow_access) begin
					n_lkup_reqpkt.lookup=1'b1;
				  	n_state=WR_LOOKUP_ALLOCATE;
			end 
		end
		RD_LOOKUP_ALLOCATE: begin
				if(trnsl_reqpkt.allow_access) begin 

				      n_hawk_cpu_ovrd_rdpkt.ppa=trnsl_reqpkt.ppa;
				      n_hawk_cpu_ovrd_rdpkt.allow_access=1'b1;

			              //drop lookup request
				      n_lkup_reqpkt.lookup=1'b0;
			              n_lkup_reqpkt.hppa='d0;
	 
				      n_state<=CHK_WR_ACTIVE;
				end
				else if (tol_updpkt.tbl_update) begin
				      n_hawk_cpu_ovrd_rdpkt.ppa=tol_updpkt.lstEntry.way;
				      n_hawk_cpu_ovrd_rdpkt.allow_access=1'b0;
				      n_state=RD_TBL_UPDATE;
				end
				//handle inflation later
				//else if (infl)
		end
		WR_LOOKUP_ALLOCATE: begin
				if(trnsl_reqpkt.allow_access) begin 
				      n_hawk_cpu_ovrd_wrpkt.ppa=trnsl_reqpkt.ppa;
				      n_hawk_cpu_ovrd_wrpkt.allow_access=1'b1;

			              //drop lookup request
				      n_lkup_reqpkt.lookup=1'b0;
			              n_lkup_reqpkt.hppa='d0;

				      n_state<=CHK_RD_ACTIVE;
				end
				else if (tol_updpkt.tbl_update) begin
				      n_hawk_cpu_ovrd_wrpkt.ppa=tol_updpkt.lstEntry.way;
				      n_hawk_cpu_ovrd_wrpkt.allow_access=1'b0;
				      n_state=WR_TBL_UPDATE;
				end
				//handle inflation later
				//else if (infl)
		end
		//The below can be moved to hawk_pgrd_manager, but later it helps
		//to pipeline : look up for pending transactions can be
		//carried out while update table action is pending, move below to other tiny state machine
		//to pipeline 
		RD_TBL_UPDATE:begin
				if(tbl_update_done) begin
				      	n_hawk_cpu_ovrd_rdpkt.allow_access=1'b1;
					n_state<=CHK_WR_ACTIVE;
				end
		end
		WR_TBL_UPDATE:begin
				if(tbl_update_done) begin
				        n_hawk_cpu_ovrd_wrpkt.allow_access=1'b1;
					n_state<=CHK_RD_ACTIVE;
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
		hawk_cpu_ovrd_wrpkt<='d0;
		hawk_cpu_ovrd_rdpkt<='d0;
		lkup_reqpkt<='d0;
		//output regs
		init_att<=1'b1; //init_att is enabled upon reset
		init_list<=1'b1; //init_att is enabled upon reset
	end
	else begin
		p_state<=n_state;
		hawk_cpu_ovrd_wrpkt<=n_hawk_cpu_ovrd_wrpkt;
		hawk_cpu_ovrd_rdpkt<=n_hawk_cpu_ovrd_rdpkt;
		lkup_reqpkt<=n_lkup_reqpkt;	
		//output regs
		init_att<=n_init_att;
		init_list<=n_init_list;
	end
end


endmodule
