// Copyright 2015-2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// ============================================================================= //
// Company:        Multitherman Laboratory @ DEIS - University of Bologna        //
//                    Viale Risorgimento 2 40136                                 //
//                    Bologna - fax 0512093785 -                                 //
//                                                                               //
// Engineer:       Igor Loi - igor.loi@unibo.it                                  //
//                                                                               //
//                                                                               //
// Additional contributions by:                                                  //
//                                                                               //
//                                                                               //
//                                                                               //
// Create Date:    02/07/2015                                                    //
// Design Name:    AXI 4 INTERCONNECT                                            //
// Module Name:    axi_size_conv_DOWNSIZE                                        //
// Project Name:   PULP                                                          //
// Language:       SystemVerilog                                                 //
//                                                                               //
// Description:    Used to link 2 AXI domains with different datawidth           //
//                 Slave port eg 128 bit, Master port < 128 bit (eg 64 bit)      //
//                                                                               //
// Revision:                                                                     //
// Revision v0.1 - 02/07/2015 : File Created                                     //
//                 LIMITATIONS : Burst Type is INCR only, SIZE is fixed          //
//                 NO error detection and handling                               //
//                                                                               //
//                                                                               //
//                                                                               //
//                                                                               //
//                                                                               //
// ============================================================================= //

`define OKAY    2'b00
`define EXOKAY  2'b01
`define SLVERR  2'b10
`define DECERR  2'b11


module axi_size_conv_DOWNSIZE
#(
    parameter  AXI_ADDR_WIDTH     = 32,

    // Slave side
    parameter AXI_DATA_WIDTH_IN   = 128,
    parameter AXI_USER_WIDTH_IN   = 6,
    parameter AXI_ID_WIDTH_IN     = 3,
    parameter AXI_STRB_WIDTH_IN   = AXI_DATA_WIDTH_IN/8,

    //Master side
    parameter AXI_DATA_WIDTH_OUT  = 64,
    parameter AXI_USER_WIDTH_OUT  = 6,
    parameter AXI_ID_WIDTH_OUT    = 3,
    parameter AXI_STRB_WIDTH_OUT  = AXI_DATA_WIDTH_OUT/8,

    parameter RATIO               = AXI_DATA_WIDTH_IN/AXI_DATA_WIDTH_OUT
)
(
    input  logic                      				   clk_i,
    input  logic                      				   rst_ni,

    /////////////////////////////////////////////////////////////////////////////////////////////////
    //                                                                                             //
    //    ███████╗██╗      █████╗ ██╗   ██╗███████╗    ██████╗  ██████╗ ██████╗ ████████╗          //
    //    ██╔════╝██║     ██╔══██╗██║   ██║██╔════╝    ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝          //
    //    ███████╗██║     ███████║██║   ██║█████╗      ██████╔╝██║   ██║██████╔╝   ██║             //
    //    ╚════██║██║     ██╔══██║╚██╗ ██╔╝██╔══╝      ██╔═══╝ ██║   ██║██╔══██╗   ██║             //
    //    ███████║███████╗██║  ██║ ╚████╔╝ ███████╗    ██║     ╚██████╔╝██║  ██║   ██║             //
    //    ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝             //
    /////////////////////////////////////////////////////////////////////////////////////////////////

    // AXI4 SLAVE
    //***************************************
    // WRITE ADDRESS CHANNEL
    input  logic                                       axi_slave_aw_valid_i,
    input  logic [AXI_ADDR_WIDTH-1:0]                  axi_slave_aw_addr_i,
    input  logic [2:0]                                 axi_slave_aw_prot_i,
    input  logic [3:0]                                 axi_slave_aw_region_i,
    input  logic [7:0]                                 axi_slave_aw_len_i,
    input  logic [2:0]                                 axi_slave_aw_size_i,
    input  logic [1:0]                                 axi_slave_aw_burst_i,
    input  logic                                       axi_slave_aw_lock_i,
    input  logic [3:0]                                 axi_slave_aw_cache_i,
    input  logic [3:0]                                 axi_slave_aw_qos_i,
    input  logic [AXI_ID_WIDTH_IN-1:0]                 axi_slave_aw_id_i,
    input  logic [AXI_USER_WIDTH_IN-1:0]               axi_slave_aw_user_i,
    output logic                                       axi_slave_aw_ready_o,

    // READ ADDRESS CHANNEL
    input  logic                                       axi_slave_ar_valid_i,
    input  logic [AXI_ADDR_WIDTH-1:0]                  axi_slave_ar_addr_i,
    input  logic [2:0]                                 axi_slave_ar_prot_i,
    input  logic [3:0]                                 axi_slave_ar_region_i,
    input  logic [7:0]                                 axi_slave_ar_len_i,
    input  logic [2:0]                                 axi_slave_ar_size_i,
    input  logic [1:0]                                 axi_slave_ar_burst_i,
    input  logic                                       axi_slave_ar_lock_i,
    input  logic [3:0]                                 axi_slave_ar_cache_i,
    input  logic [3:0]                                 axi_slave_ar_qos_i,
    input  logic [AXI_ID_WIDTH_IN-1:0]                 axi_slave_ar_id_i,
    input  logic [AXI_USER_WIDTH_IN-1:0]               axi_slave_ar_user_i,
    output logic                                       axi_slave_ar_ready_o,

    // WRITE DATA CHANNEL
    input  logic                                       axi_slave_w_valid_i,
    input  logic [RATIO-1:0][AXI_DATA_WIDTH_OUT-1:0]   axi_slave_w_data_i,
    input  logic [RATIO-1:0][AXI_STRB_WIDTH_OUT-1:0]   axi_slave_w_strb_i,
    input  logic [AXI_USER_WIDTH_IN-1:0]               axi_slave_w_user_i,
    input  logic                                       axi_slave_w_last_i,
    output logic                                       axi_slave_w_ready_o,

    // READ DATA CHANNEL
    output logic                                       axi_slave_r_valid_o,
    output logic [RATIO-1:0][AXI_DATA_WIDTH_OUT-1:0]   axi_slave_r_data_o,
    output logic [1:0]                                 axi_slave_r_resp_o,
    output logic                                       axi_slave_r_last_o,
    output logic [AXI_ID_WIDTH_IN-1:0]                 axi_slave_r_id_o,
    output logic [AXI_USER_WIDTH_IN-1:0]               axi_slave_r_user_o,
    input  logic                                       axi_slave_r_ready_i,

    // WRITE RESPONSE CHANNEL
    output logic                                       axi_slave_b_valid_o,
    output logic [1:0]                                 axi_slave_b_resp_o,
    output logic [AXI_ID_WIDTH_IN-1:0]                 axi_slave_b_id_o,
    output logic [AXI_USER_WIDTH_IN-1:0]               axi_slave_b_user_o,
    input  logic                                       axi_slave_b_ready_i,


    ////////////////////////////////////////////////////////////////////////////////////////////////
    // ███╗   ███╗ █████╗ ███████╗████████╗███████╗██████╗     ██████╗  ██████╗ ██████╗ ████████╗ //
    // ████╗ ████║██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗    ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝ //
    // ██╔████╔██║███████║███████╗   ██║   █████╗  ██████╔╝    ██████╔╝██║   ██║██████╔╝   ██║    //
    // ██║╚██╔╝██║██╔══██║╚════██║   ██║   ██╔══╝  ██╔══██╗    ██╔═══╝ ██║   ██║██╔══██╗   ██║    //
    // ██║ ╚═╝ ██║██║  ██║███████║   ██║   ███████╗██║  ██║    ██║     ╚██████╔╝██║  ██║   ██║    //
    // ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝    //
    ////////////////////////////////////////////////////////////////////////////////////////////////

    //***************************************
    // WRITE ADDRESS CHANNEL
    output logic                                       axi_master_aw_valid_o,
    output logic [AXI_ADDR_WIDTH-1:0]                  axi_master_aw_addr_o,
    output logic [2:0]                                 axi_master_aw_prot_o,
    output logic [3:0]                                 axi_master_aw_region_o,
    output logic [7:0]                                 axi_master_aw_len_o,
    output logic [2:0]                                 axi_master_aw_size_o,
    output logic [1:0]                                 axi_master_aw_burst_o,
    output logic                                       axi_master_aw_lock_o,
    output logic [3:0]                                 axi_master_aw_cache_o,
    output logic [3:0]                                 axi_master_aw_qos_o,
    output logic [AXI_ID_WIDTH_OUT-1:0]                axi_master_aw_id_o,
    output logic [AXI_USER_WIDTH_OUT-1:0]              axi_master_aw_user_o,
    input  logic                                       axi_master_aw_ready_i,

    // READ ADDRESS CHANNEL
    output logic                                       axi_master_ar_valid_o,
    output logic [AXI_ADDR_WIDTH-1:0]                  axi_master_ar_addr_o,
    output logic [2:0]                                 axi_master_ar_prot_o,
    output logic [3:0]                                 axi_master_ar_region_o,
    output logic [7:0]                                 axi_master_ar_len_o,
    output logic [2:0]                                 axi_master_ar_size_o,
    output logic [1:0]                                 axi_master_ar_burst_o,
    output logic                                       axi_master_ar_lock_o,
    output logic [3:0]                                 axi_master_ar_cache_o,
    output logic [3:0]                                 axi_master_ar_qos_o,
    output logic [AXI_ID_WIDTH_OUT-1:0]                axi_master_ar_id_o,
    output logic [AXI_USER_WIDTH_OUT-1:0]              axi_master_ar_user_o,
    input  logic                                       axi_master_ar_ready_i,

    // WRITE DATA CHANNEL
    output logic                                       axi_master_w_valid_o,
    output logic [AXI_DATA_WIDTH_OUT-1:0]              axi_master_w_data_o,
    output logic [AXI_STRB_WIDTH_OUT-1:0]              axi_master_w_strb_o,
    output logic [AXI_USER_WIDTH_OUT-1:0]              axi_master_w_user_o,
    output logic                                       axi_master_w_last_o,
    input  logic                                       axi_master_w_ready_i,

    // READ DATA CHANNEL
    input  logic                                       axi_master_r_valid_i,
    input  logic [AXI_DATA_WIDTH_OUT-1:0]    		   axi_master_r_data_i,
    input  logic [1:0]                                 axi_master_r_resp_i,
    input  logic                                       axi_master_r_last_i,
    input  logic [AXI_ID_WIDTH_OUT-1:0]                axi_master_r_id_i,
    input  logic [AXI_USER_WIDTH_OUT-1:0]              axi_master_r_user_i,
    output logic                                       axi_master_r_ready_o,

    // WRITE RESPONSE CHANNEL
    input  logic                                       axi_master_b_valid_i,
    input  logic [1:0]                                 axi_master_b_resp_i,
    input  logic [AXI_ID_WIDTH_OUT-1:0]                axi_master_b_id_i,
    input  logic [AXI_USER_WIDTH_OUT-1:0]              axi_master_b_user_i,
    output logic                                       axi_master_b_ready_o
);

    localparam   SHIFT             = $clog2(AXI_DATA_WIDTH_IN/AXI_DATA_WIDTH_OUT);
    localparam   WORD_SELECT_SIZE  = $clog2(AXI_DATA_WIDTH_IN/AXI_DATA_WIDTH_OUT);

    enum logic [2:0] { IDLE_W, BURST_W } 													CS_W, NS_W;
    enum logic [1:0] { IDLE_R, BURST_R, DISPATCH_BURST_READ, DISPATCH_LAST_BURST_READ } 	CS_R, NS_R;
    logic [$clog2(RATIO)-1:0]    				W_word_select_CS, W_word_select_NS;
    logic [RATIO-1:0][AXI_DATA_WIDTH_OUT-1:0]	RDATA_REG;
    logic [AXI_USER_WIDTH_OUT-1:0]				USER_REG;
    logic [AXI_ID_WIDTH_OUT-1:0]				ID_REG;

    logic [$clog2(RATIO)-1:0]    				R_word_select_CS, R_word_select_NS;
    logic 										update_RDATA_REG;










// ██████╗ ███████╗ █████╗ ██████╗
// ██╔══██╗██╔════╝██╔══██╗██╔══██╗
// ██████╔╝█████╗  ███████║██║  ██║
// ██╔══██╗██╔══╝  ██╔══██║██║  ██║
// ██║  ██║███████╗██║  ██║██████╔╝
// ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝


    // Address READ
    always_comb
    begin
        axi_master_ar_len_o      = ((axi_slave_ar_len_i) << ($clog2(AXI_DATA_WIDTH_IN/AXI_DATA_WIDTH_OUT))) + 1'b1;
        axi_master_ar_valid_o    = axi_slave_ar_valid_i;
        axi_slave_ar_ready_o     = axi_master_ar_ready_i;

        case(AXI_DATA_WIDTH_OUT/8) // FIXME --> Should use the real bit lane usage
            1:    axi_master_ar_size_o     =  3'b000;
            2:    axi_master_ar_size_o     =  3'b001;
            4:    axi_master_ar_size_o     =  3'b010;
            8:    axi_master_ar_size_o     =  3'b011;
            16:   axi_master_ar_size_o     =  3'b100;
            32:   axi_master_ar_size_o     =  3'b101;
            64:   axi_master_ar_size_o     =  3'b110;
            128:  axi_master_ar_size_o     =  3'b111;
        endcase // AXI_DATA_WIDTH_OUT

        case(AXI_DATA_WIDTH_OUT)
            32:   axi_master_ar_addr_o     = {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:2],     2'b00}   ;
            64:   axi_master_ar_addr_o     = {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:3],    3'b000}   ;
            128:  axi_master_ar_addr_o     = {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:4],   4'b0000}   ;
            256:  axi_master_ar_addr_o     = {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:5],  5'b00000}   ;
            512:  axi_master_ar_addr_o     = {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:6], 6'b000000}   ;
            1024: axi_master_ar_addr_o     = {axi_slave_ar_addr_i[AXI_ADDR_WIDTH-1:7],7'b0000000}   ;
        endcase

        axi_master_ar_burst_o    = axi_slave_ar_burst_i  ;


        axi_master_ar_id_o       = axi_slave_ar_id_i     ;
        axi_master_ar_user_o     = axi_slave_ar_user_i   ;

        // Useless signals
        axi_master_ar_prot_o     = axi_slave_ar_prot_i   ;
        axi_master_ar_region_o   = axi_slave_ar_region_i ;
        axi_master_ar_lock_o     = axi_slave_ar_lock_i   ;
        axi_master_ar_cache_o    = axi_slave_ar_cache_i  ;
        axi_master_ar_qos_o      = axi_slave_ar_qos_i    ;
    end


    always_ff @(posedge clk_i, negedge rst_ni)
    begin
    	if(~rst_ni)
    	begin
    		 CS_R              <= IDLE_R;
    		 R_word_select_CS  <= '0;
    		 RDATA_REG         <= '0;
    		 USER_REG          <= '0;
    		 ID_REG 		   <= '0;

    	end
    	else
    	begin
    		 CS_R                        <= NS_R;
    		 R_word_select_CS            <= R_word_select_NS;
    		 if(update_RDATA_REG)
    		 begin
    		 	RDATA_REG[R_word_select_CS] <= axi_master_r_data_i;
    		 	USER_REG 					<= axi_master_r_user_i;
    		 	ID_REG						<= axi_master_r_id_i;
    		 end

    	end
    end


    always_comb
    begin
    	//defaults:
    	R_word_select_NS    = R_word_select_CS;
    	update_RDATA_REG    = 1'b0;

    	axi_slave_r_data_o  = RDATA_REG;
    	axi_slave_r_resp_o  = `OKAY;
    	axi_slave_r_valid_o = 1'b0;
    	axi_slave_r_last_o  = 1'b0;
    	axi_slave_r_user_o  = USER_REG;
    	axi_slave_r_id_o    = ID_REG;

    	axi_master_r_ready_o = 1'b0;


    	case(CS_R)
    		IDLE_R:
    		begin : _IDLE_R_
    			axi_master_r_ready_o = 1'b1;

    			if(axi_master_r_valid_i)
    			begin
    				NS_R = BURST_R;
    				update_RDATA_REG = 1'b1;
    				R_word_select_NS = 1;
    			end
    			else
    			begin
    				NS_R = IDLE_R;
    			end
    		end //~IDLE_R



    		BURST_R:
    		begin : _BURST_R_

    			axi_master_r_ready_o = 1'b1;

    			update_RDATA_REG = axi_master_r_valid_i;

    			if(axi_master_r_valid_i)
    			begin

    				if(&R_word_select_CS) //last chunck in the master_r_data packet
    				begin
    					R_word_select_NS = '0;
    					if(axi_master_r_last_i)
    						NS_R = DISPATCH_LAST_BURST_READ;
    					else
    						NS_R = DISPATCH_BURST_READ;
    				end
    				else
    				begin
    					NS_R = BURST_R;
    					R_word_select_NS = R_word_select_CS + 1'b1;
    				end

    			end
    			else //~if(axi_master_r_valid_i)
    			begin
    					NS_R = BURST_R;
    			end
    		end //~BURST_R



    		DISPATCH_BURST_READ:
    		begin
    			axi_slave_r_valid_o = 1'b1;
    			axi_master_r_ready_o = axi_slave_r_ready_i;

    			if(axi_slave_r_ready_i)
    			begin
    					NS_R = BURST_R;

		    			if(axi_master_r_valid_i)
		    			begin
		    				update_RDATA_REG = 1'b1;
		    				R_word_select_NS = 1;
		    			end
		    			else
		    			begin
		    				R_word_select_NS = 0;
		    			end

    			end
    			else
    			begin
    					NS_R = DISPATCH_BURST_READ;
    			end
    		end //~DISPATCH_BURST_READ



    		DISPATCH_LAST_BURST_READ:
    		begin
    			axi_slave_r_valid_o = 1'b1;
    			axi_master_r_ready_o = axi_slave_r_ready_i;
    			axi_slave_r_last_o   = 1'b1;

    			if(axi_slave_r_ready_i)
    			begin


		    			if(axi_master_r_valid_i)
		    			begin
		    				update_RDATA_REG = 1'b1;
		    				R_word_select_NS = 1;
		    				NS_R = BURST_R;
		    			end
		    			else
		    			begin
		    				R_word_select_NS = 0;
		    				NS_R = IDLE_R;
		    			end

    			end
    			else
    			begin
    					NS_R = DISPATCH_LAST_BURST_READ;
    			end
    		end //~DISPATCH_LAST_BURST_READ


    	endcase // CS_R
    end







	// ██╗    ██╗██████╗ ██╗████████╗███████╗
	// ██║    ██║██╔══██╗██║╚══██╔══╝██╔════╝
	// ██║ █╗ ██║██████╔╝██║   ██║   █████╗
	// ██║███╗██║██╔══██╗██║   ██║   ██╔══╝
	// ╚███╔███╔╝██║  ██║██║   ██║   ███████╗
	//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝   ╚═╝   ╚══════╝
	assign axi_master_b_ready_o = axi_slave_b_ready_i;
	assign axi_slave_b_resp_o   = axi_master_b_resp_i;
	assign axi_slave_b_user_o   = axi_master_b_user_i;
	assign axi_slave_b_id_o     = axi_master_b_id_i;
	assign axi_slave_b_valid_o  = axi_master_b_valid_i;

    // Address WRITE
    always_comb
    begin
        axi_master_aw_len_o      = (axi_slave_aw_len_i  << $clog2(AXI_DATA_WIDTH_IN/AXI_DATA_WIDTH_OUT) )+ 1'b1;
        axi_master_aw_valid_o    = axi_slave_aw_valid_i;
        axi_slave_aw_ready_o     = axi_master_aw_ready_i;

        case(AXI_DATA_WIDTH_OUT/8) // FIXME --> Should use the real bit lane usage
            1:    axi_master_aw_size_o     =  3'b000;
            2:    axi_master_aw_size_o     =  3'b001;
            4:    axi_master_aw_size_o     =  3'b010;
            8:    axi_master_aw_size_o     =  3'b011;
            16:   axi_master_aw_size_o     =  3'b100;
            32:   axi_master_aw_size_o     =  3'b101;
            64:   axi_master_aw_size_o     =  3'b110;
            128:  axi_master_aw_size_o     =  3'b111;
        endcase // AXI_DATA_WIDTH_OUT

        case(AXI_DATA_WIDTH_OUT)
            32:   axi_master_aw_addr_o     = {axi_slave_aw_addr_i[AXI_ADDR_WIDTH-1:2],     2'b00}   ;
            64:   axi_master_aw_addr_o     = {axi_slave_aw_addr_i[AXI_ADDR_WIDTH-1:3],    3'b000}   ;
            128:  axi_master_aw_addr_o     = {axi_slave_aw_addr_i[AXI_ADDR_WIDTH-1:4],   4'b0000}   ;
            256:  axi_master_aw_addr_o     = {axi_slave_aw_addr_i[AXI_ADDR_WIDTH-1:5],  5'b00000}   ;
            512:  axi_master_aw_addr_o     = {axi_slave_aw_addr_i[AXI_ADDR_WIDTH-1:6], 6'b000000}   ;
            1024: axi_master_aw_addr_o     = {axi_slave_aw_addr_i[AXI_ADDR_WIDTH-1:7],7'b0000000}   ;
        endcase

        axi_master_aw_burst_o    = axi_slave_aw_burst_i  ;

        axi_master_aw_id_o       = axi_slave_aw_id_i     ;
        axi_master_aw_user_o     = axi_slave_aw_user_i   ;

        // Useless signals
        axi_master_aw_prot_o     = axi_slave_aw_prot_i   ;
        axi_master_aw_region_o   = axi_slave_aw_region_i ;
        axi_master_aw_lock_o     = axi_slave_aw_lock_i   ;
        axi_master_aw_cache_o    = axi_slave_aw_cache_i  ;
        axi_master_aw_qos_o      = axi_slave_aw_qos_i    ;
    end



    always_ff @(posedge clk_i, negedge rst_ni)
    begin
    	if(~rst_ni)
    	begin
    		 CS_W <= IDLE_W;
    		 W_word_select_CS          <= '0;
    	end
    	else
    	begin
    		 CS_W <= NS_W;
    		 W_word_select_CS          <= W_word_select_NS;
    	end
    end



    always_comb
    begin
		NS_W = CS_W;
		axi_slave_w_ready_o       = 1'b0;

		axi_master_w_valid_o      = 1'b0;
		axi_master_w_user_o       = axi_slave_w_user_i;
		axi_master_w_last_o       = 1'b0;
		axi_master_w_data_o       = axi_slave_w_data_i[W_word_select_CS];
		axi_master_w_strb_o       = axi_slave_w_strb_i[W_word_select_CS];

		W_word_select_NS          = W_word_select_CS;


    	case(CS_W)
    		IDLE_W:
    		begin
    			axi_slave_w_ready_o = 1'b0;
				axi_master_w_valid_o = axi_slave_w_valid_i;

				if(axi_slave_w_valid_i)
				begin
					// hold the data and then dispatch
					if(axi_master_w_ready_i)
					begin
						W_word_select_NS = 1;
						NS_W = BURST_W;
					end
					else
					begin
						NS_W = IDLE_W;
					end
				end

    		end



    		BURST_W:
    		begin
   				axi_master_w_valid_o = axi_slave_w_valid_i;

    			if(axi_slave_w_valid_i)
    			begin
    				if(&W_word_select_CS)
    				begin
    					if(axi_master_w_ready_i)
    					begin
								W_word_select_NS = '0;
	    						axi_slave_w_ready_o = 1'b1;

	    						if(axi_slave_w_last_i)
		    					begin
		    						NS_W = IDLE_W;
		    						axi_master_w_last_o = 1'b0;
		    					end
		    					else
		    					begin
		    						NS_W = BURST_W;
		    					end
    					end
    					else // master not ready
    					begin
    							NS_W = BURST_W;
    					end

    				end
    				else
    				begin
    					NS_W = BURST_W;
    					if(axi_master_w_ready_i)
    					begin
    						W_word_select_NS = W_word_select_CS + 1'b1;
    					end
    					else
    					begin
    						W_word_select_NS = W_word_select_CS;
    					end
    				end
    			end
    			else //else(axi_slave_w_valid_i)
    			begin
    				NS_W = BURST_W;
    			end
    		end

    		default :
    		begin
    			NS_W = IDLE_W;
    		end

    	endcase // CS_W

    end


endmodule // axi_size_conv_DOWNSIZE
