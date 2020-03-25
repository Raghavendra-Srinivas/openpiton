
//CPU Axi bridge with halt logic
//Future enhancements should buffer up the AXI requests to allow parallel
//lookup on ATT table from hawk control unit while current txn may be staled
//due to ATT miss

`include "hacd_define.vh"
//Defaults to values from hacd_define.vh
module hawk_cpu_stall_rd #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = `HACD_AXI4_DATA_WIDTH,
    // Width of address bus in bits
    parameter ADDR_WIDTH = `HACD_AXI4_ADDR_WIDTH,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Width of ID signal
    parameter ID_WIDTH = `HACD_AXI4_ID_WIDTH,
    // Propagate aruser signal
    parameter AWUSER_ENABLE = 1,
    // Width of aruser signal
    parameter AWUSER_WIDTH = `HACD_AXI4_USER_WIDTH,
    // Propagate ruser signal
    parameter WUSER_ENABLE = 1,
    // Width of ruser signal
    parameter WUSER_WIDTH = `HACD_AXI4_USER_WIDTH
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*hawk interface*/
    input hawk_allow_cpu_access,
   
    output hacd_pkg::cpu_wr_reqpkt_t cpu_wr_reqpkt, 

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
    output wire [ID_WIDTH-1:0]      s_axi_rid,
    output wire [DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [1:0]               s_axi_rresp,
    output wire                     s_axi_rlast,
    output wire [WUSER_WIDTH-1:0]   s_axi_ruser,
    output wire                     s_axi_rvalid,
    input  wire                     s_axi_rready,

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
    input  wire [ID_WIDTH-1:0]      m_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [1:0]               m_axi_rresp,
    input  wire                     m_axi_rlast,
    input  wire [WUSER_WIDTH-1:0]   m_axi_ruser,
    input  wire                     m_axi_rvalid,
    output wire                     m_axi_rready
);


logic allow_cpu_access,allow_cpu_access_next;
    reg [ID_WIDTH-1:0] m_axi_awid_reg, m_axi_awid_next;
    reg [ADDR_WIDTH-1:0] m_axi_awaddr_reg, m_axi_awaddr_next;
    reg [7:0] m_axi_awlen_reg , m_axi_awlen_next;
    reg [2:0] m_axi_awsize_reg , m_axi_awsize_next;
    reg [1:0] m_axi_awburst_reg , m_axi_awburst_next;
    reg m_axi_awlock_reg, m_axi_awlock_next;
    reg [3:0] m_axi_awcache_reg , m_axi_awcache_next;
    reg [2:0] m_axi_awprot_reg , m_axi_awprot_next;
    reg [3:0] m_axi_awqos_reg , m_axi_awqos_next;
    reg [3:0] m_axi_awregion_reg , m_axi_awregion_next;
    reg [AWUSER_WIDTH-1:0] m_axi_awuser_reg, m_axi_awuser_next;
    reg m_axi_awvalid_reg, m_axi_awvalid_next;

    reg s_axi_awready_reg , s_axi_awready_next;


    wire s_read_access_vld;	
    assign s_read_access_vld = s_axi_awready & s_axi_awvalid;

always@* begin
	n_state=p_state;

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
        s_axi_awready_next = s_axi_awready_reg;

        case (p_state)
            STATE_IDLE: begin
                s_axi_awready_next = !m_axi_awvalid;

                if (s_read_access_vld) begin
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
                    n_state = STATE_WAIT;
                end 
            end
            STATE_WAIT: begin //Keep waiting till hawk allow me to proceed
                s_axi_awready_next = 1'b0;

                if (!pending_rsp_q && allow_cpu_access) begin
                    m_axi_awvalid_next = 1'b1;
                    n_state = STATE_IDLE;
                end 
            end
        endcase
end

//The below logic is not needed once i add axi crossbar: But making it very
//simple wihout cross bar for intial debug, below make sure along with mux
//between cpu and hawk master, we work in
//lock-step that is only cpu or hawk, anyone can be active at any given
//clock., so we make cpu has got it's pndign response back, beofre we allow
//next req from cpu
always@(posedge clk)
	if (rst) 
              pending_rsp_q = 1'b0;
	else if (m_axi_awvalid_next)
	      pending_rsp_q=1'b1;	
	else if (s_axi_rready && s_axi_rvalid && s_axi_rlast) 
              pending_rsp_q = 1'b0;

//Store the request from CPU 
    always @(posedge clk) begin
        if (rst) begin
            p_state <= STATE_IDLE;
            m_axi_awvalid_reg <= 1'b0;
            s_axi_awready_reg <= 1'b0;
	    allow_cpu_access <=1'b0;
	    s_read_access_vld_reg <=1'b0;
        end else begin
            p_state <= n_state;
            m_axi_awvalid_reg <= m_axi_awvalid_next;
            s_axi_awready_reg <= s_axi_awready_next;
        end

	if(hawk_allow_cpu_access)
	   allow_cpu_access<=1'b1;
	else 
	   allow_cpu_access<=allow_cpu_access_next;

	s_read_access_vld_reg<=s_read_access_vld;
        
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

    //hawk req packet
    assign cpu_wr_reqpkt.hppa  = m_axi_awaddr_reg[59:12]; //4KB aligned
    assign cpu_wr_reqpkt.valid = s_read_access_vld_reg;

endmodule
