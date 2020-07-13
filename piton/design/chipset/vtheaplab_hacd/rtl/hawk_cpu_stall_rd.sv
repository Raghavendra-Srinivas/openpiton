//CPU Axi bridge with halt logic
//Future enhancements should buffer up the AXI requests to allow parallel
//lookup on ATT table from hawk control unit while current txn may be staled
//due to ATT miss

`include "hacd_define.vh"
import hacd_pkg::*;

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
    output wire                     m_axi_rready,

    //Debug
    output hacd_pkg::stall_debug_bus stall_rd_dbg_bus
	
);

    localparam [1:0]  
        STATE_IDLE = 1'd0,
        STATE_WAIT = 1'd1;

    reg p_state,n_state;

logic allow_cpu_access,allow_cpu_access_next;
    reg [ID_WIDTH-1:0] m_axi_arid_reg, m_axi_arid_next,m_axi_arid_temp;
    reg [ADDR_WIDTH-1:0] m_axi_araddr_reg, m_axi_araddr_next,m_axi_araddr_temp;
    reg [7:0] m_axi_arlen_reg , m_axi_arlen_next,m_axi_arlen_temp;
    reg [2:0] m_axi_arsize_reg , m_axi_arsize_next,m_axi_arsize_temp;
    reg [1:0] m_axi_arburst_reg , m_axi_arburst_next,m_axi_arburst_temp;
    reg m_axi_arlock_reg, m_axi_arlock_next,m_axi_arlock_temp;
    reg [3:0] m_axi_arcache_reg , m_axi_arcache_next,m_axi_arcache_temp;
    reg [2:0] m_axi_arprot_reg , m_axi_arprot_next,m_axi_arprot_temp;
    reg [3:0] m_axi_arqos_reg , m_axi_arqos_next,m_axi_arqos_temp;
    reg [3:0] m_axi_arregion_reg , m_axi_arregion_next,m_axi_arregion_temp;
    reg [ARUSER_WIDTH-1:0] m_axi_aruser_reg, m_axi_aruser_next,m_axi_aruser_temp;
    reg m_axi_arvalid_reg, m_axi_arvalid_next,m_axi_arvalid_temp;

    reg s_axi_arready_reg , s_axi_arready_next,s_axi_arready_temp;


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
 		   //if(hawk_inactive) begin
                    //m_axi_arvalid_next = 1'b1;
                    //n_state = STATE_IDLE;
		   //end else begin	
                    n_state = STATE_WAIT;
		   //end
                end 
            end
            STATE_WAIT: begin //Keep waiting till hawk allow me to proceed
                s_axi_arready_next = 1'b0;
                if (/*!pending_rsp_q &&*/ allow_cpu_access) begin
		    m_axi_araddr_next = {hawk_cpu_ovrd_pkt.ppa[ADDR_WIDTH-1:12],m_axi_araddr_reg[11:0]};
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
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            p_state <= STATE_IDLE;
            m_axi_arvalid_reg <= 1'b0;
            s_axi_arready_reg <= 1'b0;
	    allow_cpu_access <=1'b0;
	    //s_read_access_vld_reg <=1'b0;
        end else begin
            //p_state <= hawk_inactive ? STATE_IDLE : n_state;
            p_state <= n_state;
            m_axi_arvalid_reg <= m_axi_arvalid_next;
            s_axi_arready_reg <= s_axi_arready_next;

	   if(hawk_cpu_ovrd_pkt.allow_access) begin
	      allow_cpu_access<=1'b1;
	   end
	   else begin 
	      allow_cpu_access<=allow_cpu_access_next;
	   end
        end
    end
           
    always @(posedge clk) begin
	   m_axi_arid_reg <= m_axi_arid_next;

           m_axi_araddr_reg <= m_axi_araddr_next;

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



`ifdef HAWK_FPGA
  //Bypass Mux Start
  always@* begin
	if(hawk_inactive) begin
    		m_axi_arid_temp = s_axi_arid;
    		m_axi_araddr_temp = s_axi_araddr;
    		m_axi_arlen_temp = s_axi_arlen;
    		m_axi_arsize_temp = s_axi_arsize;
    		m_axi_arburst_temp = s_axi_arburst;
    		m_axi_arlock_temp = s_axi_arlock;
    		m_axi_arcache_temp = s_axi_arcache;
    		m_axi_arprot_temp = s_axi_arprot;
    		m_axi_arqos_temp = s_axi_arqos;
    		m_axi_arregion_temp = s_axi_arregion;
    		m_axi_aruser_temp = s_axi_aruser;
    		m_axi_arvalid_temp = s_axi_arvalid;

    		s_axi_arready_temp = m_axi_arready;
	end else begin
    		m_axi_arid_temp = m_axi_arid_reg;
    		m_axi_araddr_temp = m_axi_araddr_reg;
    		m_axi_arlen_temp = m_axi_arlen_reg;
    		m_axi_arsize_temp = m_axi_arsize_reg;
    		m_axi_arburst_temp = m_axi_arburst_reg;
    		m_axi_arlock_temp = m_axi_arlock_reg;
    		m_axi_arcache_temp = m_axi_arcache_reg;
    		m_axi_arprot_temp = m_axi_arprot_reg;
    		m_axi_arqos_temp = m_axi_arqos_reg;
    		m_axi_arregion_temp = m_axi_arregion_reg;
    		m_axi_aruser_temp =  m_axi_aruser_reg;
    		m_axi_arvalid_temp = m_axi_arvalid_reg;

    		s_axi_arready_temp = s_axi_arready_reg;	
	end
  end


    assign m_axi_arid = m_axi_arid_temp;
    assign m_axi_araddr = m_axi_araddr_temp;
    assign m_axi_arlen = m_axi_arlen_temp;
    assign m_axi_arsize = m_axi_arsize_temp;
    assign m_axi_arburst = m_axi_arburst_temp;
    assign m_axi_arlock = m_axi_arlock_temp;
    assign m_axi_arcache = m_axi_arcache_temp;
    assign m_axi_arprot = m_axi_arprot_temp;
    assign m_axi_arqos = m_axi_arqos_temp;
    assign m_axi_arregion = m_axi_arregion_temp;
    assign m_axi_aruser = ARUSER_ENABLE ? m_axi_aruser_temp : {ARUSER_WIDTH{1'b0}};
    assign m_axi_arvalid = m_axi_arvalid_temp;

    assign s_axi_arready = s_axi_arready_temp;

    //Muxing End
`else

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

`endif

    //hawk req packet
    assign cpu_reqpkt.hppa  = m_axi_araddr_reg[`HACD_AXI4_ADDR_WIDTH-1:12]; //4KB aligned
    wire lookup;
    assign lookup= (p_state==STATE_WAIT) && !(hawk_cpu_ovrd_pkt.allow_access | allow_cpu_access);
    assign cpu_reqpkt.valid = lookup;

   //Pendign Request Tracker 
   logic [ADDR_WIDTH-1:0] rd_addr0;
   logic [ADDR_WIDTH-1:0] rd_addr1; 

   logic [63:0] req_count0,resp_count0;
   logic [63:0] req_count1,resp_count1;
   logic overflow;
   logic bus_error;

    // we can't get response on same cycle for same id. and same id txn can never appear for second time without response
    always @(posedge clk or posedge rst) begin
        if (rst) begin
		overflow <= 1'b0;
		req_count0 <= 'd0;
		req_count1 <= 'd0;
		resp_count0 <= 'd0;
		resp_count1 <= 'd0;
		rd_addr0<={ADDR_WIDTH{1'b1}};
		rd_addr1<={ADDR_WIDTH{1'b1}};
		bus_error<=1'b0;
	end
	else begin
    		overflow <= overflow || (&req_count0 || &resp_count0 || &req_count1 || &resp_count1) || (s_axi_arid>1) || (s_axi_rid>1);
                if (s_axi_arready & s_axi_arvalid) begin 
			if(s_axi_arid=='d0 ) begin
				rd_addr0<=s_axi_araddr;
				req_count0<=req_count0+1;
			end	
			else if(s_axi_arid=='d1 ) begin
				rd_addr1<=s_axi_araddr;
				req_count1<=req_count1+1;
			end
		end
                if (s_axi_rready && s_axi_rvalid && s_axi_rresp=='d0) begin 
			if  (s_axi_rid=='d0) begin
				resp_count0<=resp_count0+1;
			end
			else if  (s_axi_rid=='d1) begin
				resp_count1<=resp_count1+1;
			end
		end
		else if (s_axi_rready && s_axi_rvalid && s_axi_rresp!='d0) begin
			bus_error<=1'b1;
		end
	end
    end

assign stall_rd_dbg_bus.last_addr0  = rd_addr0;
assign stall_rd_dbg_bus.last_addr1  = rd_addr1;
assign stall_rd_dbg_bus.req_count0  = req_count0;
assign stall_rd_dbg_bus.resp_count0 = resp_count0;
assign stall_rd_dbg_bus.req_count1  = req_count1;
assign stall_rd_dbg_bus.resp_count1 = resp_count1;
assign stall_rd_dbg_bus.overflow    = overflow;
assign stall_rd_dbg_bus.bus_error   = bus_error;
assign stall_rd_dbg_bus.fsm_state=p_state;


endmodule
