
/////////////////////////////////////////////////////////////////////////////////
//
// Heap Lab Research
// Block : Hawk Control Unit 
// 
// Author : Raghavendra Srinivas
// Contact : raghavs@vt.edu	
/////////////////////////////////////////////////////////////////////////////////
// Description: Unit to control and manage entire hawk operations.
// 		
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
localparam IDLE		='d0,
	   ACTIVE	='d1,
	   ATT_LKUP	='d2;

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

//fsm combo
always_comb
begin
	n_state=p_state;
	n_hold_hwk_wr=hold_hwk_wr;
	n_hold_cpu=hold_cpu;
	n_init_att=init_att;
	n_init_list=init_list;

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
		ACTIVE:begin
			if(cpu_vld_access) begin
			
			end
		end
	
	endcase

end



endmodule
