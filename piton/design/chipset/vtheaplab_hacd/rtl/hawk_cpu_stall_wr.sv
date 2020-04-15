

// File: hawk_cpu_stall_wr.sv
// Author : Raghavendra-Srinivas
// 	    raghavs@vt.edu
// Description
// FIFO + AXI Master
// FIFO Write should be from other master if there is space in fifo; should
// honor full condition
// AXI master gets triggered as soon as at-least one burst of data is avaiable
// in FIFO and trasfers till FIFO ges emoty
//

`include "hacd_define.vh"
//Defaults to values from hacd_define.vh
module hawk_cpu_stall_wr #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = `HACD_AXI4_DATA_WIDTH,
    // Width of address bus in bits
    parameter ADDR_WIDTH = `HACD_AXI4_ADDR_WIDTH,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Width of ID signal
    parameter ID_WIDTH = `HACD_AXI4_ID_WIDTH,
    // Propagate awuser signal
    parameter AWUSER_ENABLE = 1,
    // Width of awuser signal
    parameter AWUSER_WIDTH = `HACD_AXI4_USER_WIDTH,
    // Propagate wuser signal
    parameter WUSER_ENABLE = 1,
    // Width of wuser signal
    parameter WUSER_WIDTH = `HACD_AXI4_USER_WIDTH,
    // Propagate buser signal
    parameter BUSER_ENABLE = 1,
    // Width of buser signal
    parameter BUSER_WIDTH = `HACD_AXI4_USER_WIDTH,
    //
    parameter [2:0] BURST_SIZE=`HACD_AXI4_BURST_SIZE,
    //  
    parameter [1:0] BURST_TYPE=`HACD_AXI4_BURST_TYPE

)
(
    input  wire                     clk,
    input  wire                     rst,

    /*hawk interface*/
    input hacd_pkg::hawk_cpu_ovrd_pkt_t hawk_cpu_ovrd_pkt,
    output hacd_pkg::cpu_reqpkt_t cpu_reqpkt,
    input hawk_inactive,
 
    /*
     * AXI slave interface
     */
    input  wire [ID_WIDTH-1:0]      s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [7:0]               s_axi_awlen,
    input  wire [2:0]               s_axi_awsize,
    input  wire [1:0]               s_axi_awburst,
    input  wire                     s_axi_awlock,
    input  wire [3:0]               s_axi_awcache,
    input  wire [2:0]               s_axi_awprot,
    input  wire [3:0]               s_axi_awqos,
    input  wire [3:0]               s_axi_awregion,
    input  wire [AWUSER_WIDTH-1:0]  s_axi_awuser,
    input  wire                     s_axi_awvalid,
    output wire                     s_axi_awready,
    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire                     s_axi_wlast,
    input  wire [WUSER_WIDTH-1:0]   s_axi_wuser,
    input  wire                     s_axi_wvalid,
    output wire                     s_axi_wready,
    output wire [ID_WIDTH-1:0]      s_axi_bid,
    output wire [1:0]               s_axi_bresp,
    output wire [BUSER_WIDTH-1:0]   s_axi_buser,
    output wire                     s_axi_bvalid,
    input  wire                     s_axi_bready,

    /*
     * AXI master interface
     */
    output wire [ID_WIDTH-1:0]      m_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [7:0]               m_axi_awlen,
    output wire [2:0]               m_axi_awsize,
    output wire [1:0]               m_axi_awburst,
    output wire                     m_axi_awlock,
    output wire [3:0]               m_axi_awcache,
    output wire [2:0]               m_axi_awprot,
    output wire [3:0]               m_axi_awqos,
    output wire [3:0]               m_axi_awregion,
    output wire [AWUSER_WIDTH-1:0]  m_axi_awuser,
    output wire                     m_axi_awvalid,
    input  wire                     m_axi_awready,
    output wire [DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [STRB_WIDTH-1:0]    m_axi_wstrb,
    output wire                     m_axi_wlast,
    output wire [WUSER_WIDTH-1:0]   m_axi_wuser,
    output wire                     m_axi_wvalid,
    input  wire                     m_axi_wready,
    input  wire [ID_WIDTH-1:0]      m_axi_bid,
    input  wire [1:0]               m_axi_bresp,
    input  wire [BUSER_WIDTH-1:0]   m_axi_buser,
    input  wire                     m_axi_bvalid,
    output wire                     m_axi_bready
);


    localparam [1:0]
        IDLE = 2'd0,
        WAIT_DATA = 2'd1,
        WAIT_HAWK= 2'd2;

    reg [1:0] p_state , n_state;

logic allow_cpu_access,allow_cpu_access_next;
    reg [ID_WIDTH-1:0] m_axi_awid_reg, m_axi_awid_next;
    reg [ADDR_WIDTH-1:0] m_axi_awaddr_reg, m_axi_awaddr_next;
    reg [7:0] m_axi_awlen_reg, m_axi_awlen_next;
    reg [2:0] m_axi_awsize_reg, m_axi_awsize_next;
    reg [1:0] m_axi_awburst_reg, m_axi_awburst_next;
    reg m_axi_awlock_reg, m_axi_awlock_next;
    reg [3:0] m_axi_awcache_reg, m_axi_awcache_next;
    reg [2:0] m_axi_awprot_reg, m_axi_awprot_next;
    reg [3:0] m_axi_awqos_reg, m_axi_awqos_next;
    reg [3:0] m_axi_awregion_reg, m_axi_awregion_next;
    reg [AWUSER_WIDTH-1:0] m_axi_awuser_reg, m_axi_awuser_next;
    reg m_axi_awvalid_reg , m_axi_awvalid_next;

    reg s_axi_awready_reg, s_axi_awready_next;
    reg s_axi_wready_reg, s_axi_wready_next;

    reg m_axi_wvalid_reg, m_axi_wvalid_next;
    reg [DATA_WIDTH-1:0] m_axi_wdata_reg,m_axi_wdata_next;
    reg	[STRB_WIDTH-1:0] m_axi_wstrb_reg,m_axi_wstrb_next;
    reg	m_axi_wlast_reg,m_axi_wlast_next;
    
    always @* begin
        n_state = p_state;

        m_axi_awid_next = m_axi_awid_reg;
        m_axi_awaddr_next = m_axi_awaddr_reg;
        m_axi_awlen_next = m_axi_awlen_reg;
        m_axi_awsize_next = m_axi_awsize_reg;
        m_axi_awburst_next = m_axi_awburst_reg;
        m_axi_awlock_next = m_axi_awlock_reg;
        m_axi_awcache_next = m_axi_awcache_reg;
        m_axi_awprot_next = m_axi_awprot_reg;
        m_axi_awqos_next = m_axi_awqos_reg;
        m_axi_awregion_next = m_axi_awregion_reg;
        m_axi_awuser_next = m_axi_awuser_reg;
        m_axi_awvalid_next = m_axi_awvalid_reg && !m_axi_awready;
	m_axi_wvalid_next = m_axi_wvalid_reg && !m_axi_wready;
        s_axi_awready_next = s_axi_awready_reg;

	allow_cpu_access_next = allow_cpu_access;

        case (p_state)
            IDLE: begin
                s_axi_awready_next = !m_axi_awvalid;
                s_axi_wready_next = 1'b0;

                if (s_axi_awready & s_axi_awvalid) begin
                    s_axi_awready_next = 1'b0;

                    m_axi_awid_next = s_axi_awid;
                    m_axi_awaddr_next = s_axi_awaddr;
                    m_axi_awlen_next = s_axi_awlen;
                    m_axi_awsize_next = s_axi_awsize;
                    m_axi_awburst_next = s_axi_awburst;
                    m_axi_awlock_next = s_axi_awlock;
                    m_axi_awcache_next = s_axi_awcache;
                    m_axi_awprot_next = s_axi_awprot;
                    m_axi_awqos_next = s_axi_awqos;
                    m_axi_awregion_next = s_axi_awregion;
                    m_axi_awuser_next = s_axi_awuser;

		    allow_cpu_access_next = 1'b0; //upon valid txn, I hold myself, this can be set by only hawk
                    n_state = WAIT_DATA;
                end 
            end
	   WAIT_DATA:begin
                s_axi_awready_next = 1'b0;
                s_axi_wready_next = !m_axi_wvalid;

                if (s_axi_wready & s_axi_wvalid) begin
                    s_axi_wready_next = 1'b0;

    		    m_axi_wdata_next = s_axi_wdata;
		    m_axi_wstrb_next = s_axi_wstrb;
    		    m_axi_wlast_next = s_axi_wlast;
		
		    allow_cpu_access_next = 1'b0; //upon valid txn, I hold myself, this can be set by only hawk
                    n_state = WAIT_HAWK;
                end		  
	   end
	   WAIT_HAWK:begin
                s_axi_awready_next = 1'b0;
                s_axi_wready_next = 1'b0;
                if (/*!pending_rsp_q &&*/ (allow_cpu_access || hawk_inactive) ) begin
		    m_axi_awaddr_next = {hawk_cpu_ovrd_pkt.ppa[ADDR_WIDTH-1:12],m_axi_awaddr_reg[11:0]};
                    m_axi_awvalid_next = 1'b1;
                    m_axi_wvalid_next = 1'b1;
                    n_state = IDLE;
                end 
	   end
        endcase
    end

 
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            p_state <= IDLE;
            m_axi_awvalid_reg <= 1'b0;
            s_axi_awready_reg <= 1'b0;

            m_axi_wvalid_reg <= 1'b0;
            s_axi_awready_reg <= 1'b0;

	    allow_cpu_access <=1'b0;
        end else begin
            p_state <= n_state;
            m_axi_awvalid_reg <= m_axi_awvalid_next;
            s_axi_awready_reg <= s_axi_awready_next;
            
	    m_axi_wvalid_reg <= m_axi_wvalid_next;
            s_axi_wready_reg <= s_axi_wready_next;

		if(hawk_cpu_ovrd_pkt.allow_access) begin
		   allow_cpu_access<=1'b1;
		end else begin 
	   	   allow_cpu_access<=allow_cpu_access_next;
		end
        end
    end

    always @(posedge clk) begin
        m_axi_awid_reg <= m_axi_awid_next;
        m_axi_awaddr_reg <= m_axi_awaddr_next;
        m_axi_awlen_reg <= m_axi_awlen_next;
        m_axi_awsize_reg <= m_axi_awsize_next;
        m_axi_awburst_reg <= m_axi_awburst_next;
        m_axi_awlock_reg <= m_axi_awlock_next;
        m_axi_awcache_reg <= m_axi_awcache_next;
        m_axi_awprot_reg <= m_axi_awprot_next;
        m_axi_awqos_reg <= m_axi_awqos_next;
        m_axi_awregion_reg <= m_axi_awregion_next;
        m_axi_awuser_reg <= m_axi_awuser_next;
    		    
        m_axi_wdata_reg <= m_axi_wdata_next;
	m_axi_wstrb_reg <= m_axi_wstrb_next;
    	m_axi_wlast_reg <= m_axi_wlast_next;
    end

   assign m_axi_awid = m_axi_awid_reg;
   assign m_axi_awaddr = m_axi_awaddr_reg;
   assign m_axi_awlen = m_axi_awlen_reg;
   assign m_axi_awsize = m_axi_awsize_reg;
   assign m_axi_awburst = m_axi_awburst_reg;
   assign m_axi_awlock = m_axi_awlock_reg;
   assign m_axi_awcache = m_axi_awcache_reg;
   assign m_axi_awprot = m_axi_awprot_reg;
   assign m_axi_awqos = m_axi_awqos_reg;
   assign m_axi_awregion = m_axi_awregion_reg;
   assign m_axi_awuser = AWUSER_ENABLE ? m_axi_awuser_reg : {AWUSER_WIDTH{1'b0}};
   assign m_axi_awvalid = m_axi_awvalid_reg;

   assign s_axi_awready = s_axi_awready_reg;

   // bypass B channel
   assign s_axi_bid = m_axi_bid;
   assign s_axi_bresp = m_axi_bresp;
   assign s_axi_buser = BUSER_ENABLE ? m_axi_buser : {BUSER_WIDTH{1'b0}};
   assign s_axi_bvalid = m_axi_bvalid;
   assign m_axi_bready = s_axi_bready;
   //
   //Write Channel 
   assign m_axi_wvalid = m_axi_wvalid_reg;
   assign s_axi_wready = s_axi_wready_reg; 
   assign m_axi_wdata = m_axi_wdata_reg;
   assign m_axi_wstrb = m_axi_wstrb_reg;
   assign m_axi_wlast = m_axi_wlast_reg;
   assign m_axi_wuser = (WUSER_ENABLE) ? s_axi_wuser : {WUSER_WIDTH{1'b0}};

   //hawk req packet
   assign cpu_reqpkt.hppa  = m_axi_awaddr_reg[`HACD_AXI4_ADDR_WIDTH-1:12]; //4KB aligned
   wire lookup;
   assign lookup= (p_state==WAIT_HAWK) && !(hawk_cpu_ovrd_pkt.allow_access | allow_cpu_access);
   assign cpu_reqpkt.valid = lookup;
   assign cpu_reqpkt.zeroBlkWr= (p_state==WAIT_HAWK) && (&m_axi_wstrb_reg && ~(|m_axi_wdata_reg));

endmodule
