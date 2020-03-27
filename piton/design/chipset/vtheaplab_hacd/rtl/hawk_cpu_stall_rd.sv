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
    parameter ARUSER_ENABLE = 1,
    // Width of aruser signal
    parameter ARUSER_WIDTH = `HACD_AXI4_USER_WIDTH,
    // Propagate ruser signal
    parameter RUSER_ENABLE = 1,
    // Width of ruser signal
    parameter RUSER_WIDTH = `HACD_AXI4_USER_WIDTH
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
    input  wire [ID_WIDTH-1:0]      s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [7:0]               s_axi_arlen,
    input  wire [2:0]               s_axi_arsize,
    input  wire [1:0]               s_axi_arburst,
    input  wire                     s_axi_arlock,
    input  wire [3:0]               s_axi_arcache,
    input  wire [2:0]               s_axi_arprot,
    input  wire [3:0]               s_axi_arqos,
    input  wire [3:0]               s_axi_arregion,
    input  wire [ARUSER_WIDTH-1:0]  s_axi_aruser,
    input  wire                     s_axi_arvalid,
    output wire                     s_axi_arready,
    output wire [ID_WIDTH-1:0]      s_axi_rid,
    output wire [DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [1:0]               s_axi_rresp,
    output wire                     s_axi_rlast,
    output wire [RUSER_WIDTH-1:0]   s_axi_ruser,
    output wire                     s_axi_rvalid,
    input  wire                     s_axi_rready,

    /*
     * AXI master interface
     */
    output wire [ID_WIDTH-1:0]      m_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [7:0]               m_axi_arlen,
    output wire [2:0]               m_axi_arsize,
    output wire [1:0]               m_axi_arburst,
    output wire                     m_axi_arlock,
    output wire [3:0]               m_axi_arcache,
    output wire [2:0]               m_axi_arprot,
    output wire [3:0]               m_axi_arqos,
    output wire [3:0]               m_axi_arregion,
    output wire [ARUSER_WIDTH-1:0]  m_axi_aruser,
    output wire                     m_axi_arvalid,
    input  wire                     m_axi_arready,
    input  wire [ID_WIDTH-1:0]      m_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [1:0]               m_axi_rresp,
    input  wire                     m_axi_rlast,
    input  wire [RUSER_WIDTH-1:0]   m_axi_ruser,
    input  wire                     m_axi_rvalid,
    output wire                     m_axi_rready
);

    localparam [1:0]  
        STATE_IDLE = 1'd0,
        STATE_WAIT = 1'd1;

    reg p_state,n_state;

logic allow_cpu_access,allow_cpu_access_next;
    reg [ID_WIDTH-1:0] m_axi_arid_reg, m_axi_arid_next;
    reg [ADDR_WIDTH-1:0] m_axi_araddr_reg, m_axi_araddr_next;
    reg [7:0] m_axi_arlen_reg , m_axi_arlen_next;
    reg [2:0] m_axi_arsize_reg , m_axi_arsize_next;
    reg [1:0] m_axi_arburst_reg , m_axi_arburst_next;
    reg m_axi_arlock_reg, m_axi_arlock_next;
    reg [3:0] m_axi_arcache_reg , m_axi_arcache_next;
    reg [2:0] m_axi_arprot_reg , m_axi_arprot_next;
    reg [3:0] m_axi_arqos_reg , m_axi_arqos_next;
    reg [3:0] m_axi_arregion_reg , m_axi_arregion_next;
    reg [ARUSER_WIDTH-1:0] m_axi_aruser_reg, m_axi_aruser_next;
    reg m_axi_arvalid_reg, m_axi_arvalid_next;

    reg s_axi_arready_reg , s_axi_arready_next;


    wire s_read_access_vld;	
    assign s_read_access_vld = s_axi_arready & s_axi_arvalid;

always@* begin
	n_state=p_state;

        m_axi_arid_next = m_axi_arid_reg;
        m_axi_araddr_next = m_axi_araddr_reg;
        m_axi_arlen_next = m_axi_arlen_reg;
        m_axi_arsize_next = m_axi_arsize_reg;
        m_axi_arburst_next = m_axi_arburst_reg;
        m_axi_arlock_next = m_axi_arlock_reg;
        m_axi_arcache_next = m_axi_arcache_reg;
        m_axi_arprot_next = m_axi_arprot_reg;
        m_axi_arqos_next = m_axi_arqos_reg;
        m_axi_arregion_next = m_axi_arregion_reg;
        m_axi_aruser_next = m_axi_aruser_reg;
        m_axi_arvalid_next = m_axi_arvalid_reg && !m_axi_arready;
        s_axi_arready_next = s_axi_arready_reg;

	allow_cpu_access_next = allow_cpu_access;
        case (p_state)
            STATE_IDLE: begin
                s_axi_arready_next = !m_axi_arvalid;

                if (s_read_access_vld) begin
                    s_axi_arready_next = 1'b0;

                    m_axi_arid_next = s_axi_arid;
                    m_axi_araddr_next = s_axi_araddr;
                    m_axi_arlen_next = s_axi_arlen;
                    m_axi_arsize_next = s_axi_arsize;
                    m_axi_arburst_next = s_axi_arburst;
                    m_axi_arlock_next = s_axi_arlock;
                    m_axi_arcache_next = s_axi_arcache;
                    m_axi_arprot_next = s_axi_arprot;
                    m_axi_arqos_next = s_axi_arqos;
                    m_axi_arregion_next = s_axi_arregion;
                    m_axi_aruser_next = s_axi_aruser;
			
		    allow_cpu_access_next = 1'b0; //upon valid txn, I hold myself, this can be set by only hawk
                    n_state = STATE_WAIT;
                end 
            end
            STATE_WAIT: begin //Keep waiting till hawk allow me to proceed
                s_axi_arready_next = 1'b0;
                if (/*!pending_rsp_q &&*/ (allow_cpu_access || hawk_inactive) ) begin
                    m_axi_arvalid_next = 1'b1;
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
/*
always@(posedge clk)
	if (rst) 
              pending_rsp_q = 1'b0;
	else if (m_axi_arvalid_next)
	      pending_rsp_q=1'b1;	
	else if (m_axi_rready && m_axi_rvalid && m_axi_rlast) 
              pending_rsp_q = 1'b0;
*/
//pass through 
assign m_axi_rready = s_axi_rready;
assign s_axi_rid = m_axi_rid;
assign s_axi_rdata = m_axi_rdata;
assign s_axi_rresp = m_axi_rresp;
assign s_axi_rlast = m_axi_rlast;
assign s_axi_ruser = m_axi_ruser;
assign s_axi_rvalid = m_axi_rvalid;

//Store the request from CPU 
    always @(posedge clk) begin
        if (rst) begin
            p_state <= STATE_IDLE;
            m_axi_arvalid_reg <= 1'b0;
            s_axi_arready_reg <= 1'b0;
	    allow_cpu_access <=1'b0;
	    //s_read_access_vld_reg <=1'b0;
        end else begin
            p_state <= n_state;
            m_axi_arvalid_reg <= m_axi_arvalid_next;
            s_axi_arready_reg <= s_axi_arready_next;
        end

	if(hawk_cpu_ovrd_pkt.allow_access)
	   allow_cpu_access<=1'b1;
	else 
	   allow_cpu_access<=allow_cpu_access_next;

        //if(s_read_access_vld)
	//s_read_access_vld_reg<=1'b1;
	//else if(hawk_cpu_ovrd_pkt.allow_access)
	//s_read_access_vld_reg<=1'b0;
        
	m_axi_arid_reg <= m_axi_arid_next;
        m_axi_araddr_reg <= (hawk_cpu_ovrd_pkt.allow_access & !hawk_inactive) ? {hawk_cpu_ovrd_pkt.ppa[ADDR_WIDTH-1:12],m_axi_araddr_next[11:0]} : m_axi_araddr_next;
        m_axi_arlen_reg <= m_axi_arlen_next;
        m_axi_arsize_reg <= m_axi_arsize_next;
        m_axi_arburst_reg <= m_axi_arburst_next;
        m_axi_arlock_reg <= m_axi_arlock_next;
        m_axi_arcache_reg <= m_axi_arcache_next;
        m_axi_arprot_reg <= m_axi_arprot_next;
        m_axi_arqos_reg <= m_axi_arqos_next;
        m_axi_arregion_reg <= m_axi_arregion_next;
        m_axi_aruser_reg <= m_axi_aruser_next;
    end

    assign m_axi_arid = m_axi_arid_reg;
    assign m_axi_araddr = m_axi_araddr_reg;
    assign m_axi_arlen = m_axi_arlen_reg;
    assign m_axi_arsize = m_axi_arsize_reg;
    assign m_axi_arburst = m_axi_arburst_reg;
    assign m_axi_arlock = m_axi_arlock_reg;
    assign m_axi_arcache = m_axi_arcache_reg;
    assign m_axi_arprot = m_axi_arprot_reg;
    assign m_axi_arqos = m_axi_arqos_reg;
    assign m_axi_arregion = m_axi_arregion_reg;
    assign m_axi_aruser = ARUSER_ENABLE ? m_axi_aruser_reg : {ARUSER_WIDTH{1'b0}};
    assign m_axi_arvalid = m_axi_arvalid_reg;

    assign s_axi_arready = s_axi_arready_reg;

    //hawk req packet
    assign cpu_reqpkt.hppa  = m_axi_araddr_reg[59:12]; //4KB aligned
    assign cpu_reqpkt.valid = (p_state==STATE_WAIT);//s_read_access_vld_reg;

endmodule
