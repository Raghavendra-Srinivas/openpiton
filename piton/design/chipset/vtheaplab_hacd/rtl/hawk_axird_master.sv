//AXI4 Bridge with FIFO

`include "hacd_define.vh"
//Defaults to values from hacd_define.vh
module hawk_axird_master #
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
    parameter ARUSER_ENABLE = 0,
    // Width of aruser signal
    parameter ARUSER_WIDTH = `HACD_AXI4_USER_WIDTH,
    // Propagate ruser signal
    parameter RUSER_ENABLE = 0,
    // Width of ruser signal
    parameter RUSER_WIDTH = `HACD_AXI4_USER_WIDTH,
    // Read data FIFO depth (cycles)
    parameter FIFO_DEPTH = `HACD_AXI_MASTER_FIFO_DEPTH, //64,
    // Hold read address until space available in FIFO for data, if possible
    parameter FIFO_DELAY = 1
)
(
    input  wire                     clk,
    input  wire                     rst,

    //compressor control on FIFO	
    input wire rdfifo_rdptr_rst, //this would reset read pointer to zero
    input wire rdfifo_wrptr_rst, //this would reset read pointer to zero
    output wire rdfifo_empty,
    output wire rdfifo_full,
    input wire [`FIFO_PTR_WIDTH-1:0] rdfifo_rdptr,
    input wire ld_rdfifo_rdptr,
   
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

parameter LAST_OFFSET  = DATA_WIDTH;
parameter ID_OFFSET    = LAST_OFFSET + 1;
parameter RESP_OFFSET  = ID_OFFSET + ID_WIDTH;
parameter RUSER_OFFSET = RESP_OFFSET + 2;
parameter RWIDTH       = RUSER_OFFSET + (RUSER_ENABLE ? RUSER_WIDTH : 0);

parameter FIFO_ADDR_WIDTH = $clog2(FIFO_DEPTH); //+1;

reg [FIFO_ADDR_WIDTH:0] wr_ptr_reg = {FIFO_ADDR_WIDTH+1{1'b0}}, wr_ptr_next;
reg [FIFO_ADDR_WIDTH:0] wr_addr_reg = {FIFO_ADDR_WIDTH+1{1'b0}};
reg [FIFO_ADDR_WIDTH:0] rd_ptr_reg = {FIFO_ADDR_WIDTH+1{1'b0}}, rd_ptr_next;
reg [FIFO_ADDR_WIDTH:0] rd_addr_reg = {FIFO_ADDR_WIDTH+1{1'b0}};

reg [RWIDTH-1:0] mem[(2**FIFO_ADDR_WIDTH)-1:0];
reg [RWIDTH-1:0] mem_read_data_reg;
reg mem_read_data_valid_reg = 1'b0, mem_read_data_valid_next;

wire [RWIDTH-1:0] m_axi_r;

reg [RWIDTH-1:0] s_axi_r_reg;
reg s_axi_rvalid_reg = 1'b0, s_axi_rvalid_next;

// rdfifo_full when first MSB different but rest same
assign rdfifo_full = ((wr_ptr_reg[FIFO_ADDR_WIDTH] != rd_ptr_reg[FIFO_ADDR_WIDTH]) &&
             (wr_ptr_reg[FIFO_ADDR_WIDTH-1:0] == rd_ptr_reg[FIFO_ADDR_WIDTH-1:0]));
// rdfifo_empty when pointers match exactly
assign rdfifo_empty = wr_ptr_reg == rd_ptr_reg;

// control signals
reg write;
reg read;
reg store_output;

assign m_axi_rready = !rdfifo_full;

generate
    assign m_axi_r[DATA_WIDTH-1:0] = m_axi_rdata;
    assign m_axi_r[LAST_OFFSET] = m_axi_rlast;
    assign m_axi_r[ID_OFFSET +: ID_WIDTH] = m_axi_rid;
    assign m_axi_r[RESP_OFFSET +: 2] = m_axi_rresp;
    if (RUSER_ENABLE) assign m_axi_r[RUSER_OFFSET +: RUSER_WIDTH] = m_axi_ruser;
endgenerate

generate

if (FIFO_DELAY) begin
    // store AR channel value until there is enough space to store R channel burst in FIFO or FIFO is rdfifo_empty

    localparam COUNT_WIDTH = (FIFO_ADDR_WIDTH > 8 ? FIFO_ADDR_WIDTH : 8) + 1;

    localparam [1:0]
        STATE_IDLE = 1'd0,
        STATE_WAIT = 1'd1;

    reg [1:0] state_reg = STATE_IDLE, state_next;

    reg [COUNT_WIDTH-1:0] count_reg, count_next;

    reg [ID_WIDTH-1:0] m_axi_arid_reg = {ID_WIDTH{1'b0}}, m_axi_arid_next;
    reg [ADDR_WIDTH-1:0] m_axi_araddr_reg = {ADDR_WIDTH{1'b0}}, m_axi_araddr_next;
    reg [7:0] m_axi_arlen_reg = 8'd0, m_axi_arlen_next;
    reg [2:0] m_axi_arsize_reg = 3'd0, m_axi_arsize_next;
    reg [1:0] m_axi_arburst_reg = 2'd0, m_axi_arburst_next;
    reg m_axi_arlock_reg = 1'b0, m_axi_arlock_next;
    reg [3:0] m_axi_arcache_reg = 4'd0, m_axi_arcache_next;
    reg [2:0] m_axi_arprot_reg = 3'd0, m_axi_arprot_next;
    reg [3:0] m_axi_arqos_reg = 4'd0, m_axi_arqos_next;
    reg [3:0] m_axi_arregion_reg = 4'd0, m_axi_arregion_next;
    reg [ARUSER_WIDTH-1:0] m_axi_aruser_reg = {ARUSER_WIDTH{1'b0}}, m_axi_aruser_next;
    reg m_axi_arvalid_reg = 1'b0, m_axi_arvalid_next;

    reg s_axi_arready_reg = 1'b0, s_axi_arready_next;

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

    always @* begin
        state_next = STATE_IDLE;

        count_next = count_reg;

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

        case (state_reg)
            STATE_IDLE: begin
                s_axi_arready_next = !m_axi_arvalid;

                if (s_axi_arready & s_axi_arvalid) begin
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

                    if (count_reg == 0 || count_reg + m_axi_arlen_next + 1 <= 2**FIFO_ADDR_WIDTH) begin
                        count_next = count_reg + m_axi_arlen_next + 1;
                        m_axi_arvalid_next = 1'b1;
                        s_axi_arready_next = 1'b0;
                        state_next = STATE_IDLE;
                    end else begin
                        s_axi_arready_next = 1'b0;
                        state_next = STATE_WAIT;
                    end
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_WAIT: begin
                s_axi_arready_next = 1'b0;

                if (count_reg == 0 || count_reg + m_axi_arlen_reg + 1 <= 2**FIFO_ADDR_WIDTH) begin
                    count_next = count_reg + m_axi_arlen_reg + 1;
                    m_axi_arvalid_next = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_WAIT;
                end
            end
        endcase

        if (s_axi_rready && s_axi_rvalid) begin
            count_next = count_next - 1;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state_reg <= STATE_IDLE;
            m_axi_arvalid_reg <= 1'b0;
            s_axi_arready_reg <= 1'b0;
            count_reg <= 'd0;
        end else begin
            state_reg <= state_next;
            m_axi_arvalid_reg <= m_axi_arvalid_next;
            s_axi_arready_reg <= s_axi_arready_next;
            count_reg <= count_next;
        end


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
end else begin
    // bypass AR channel
    assign m_axi_arid = s_axi_arid;
    assign m_axi_araddr = s_axi_araddr;
    assign m_axi_arlen = s_axi_arlen;
    assign m_axi_arsize = s_axi_arsize;
    assign m_axi_arburst = s_axi_arburst;
    assign m_axi_arlock = s_axi_arlock;
    assign m_axi_arcache = s_axi_arcache;
    assign m_axi_arprot = s_axi_arprot;
    assign m_axi_arqos = s_axi_arqos;
    assign m_axi_arregion = s_axi_arregion;
    assign m_axi_aruser = ARUSER_ENABLE ? s_axi_aruser : {ARUSER_WIDTH{1'b0}};
    assign m_axi_arvalid = s_axi_arvalid;
    assign s_axi_arready = m_axi_arready;
end

endgenerate

assign s_axi_rvalid = s_axi_rvalid_reg;

assign s_axi_rdata = s_axi_r_reg[DATA_WIDTH-1:0];
assign s_axi_rlast = s_axi_r_reg[LAST_OFFSET];
assign s_axi_rid   = s_axi_r_reg[ID_OFFSET +: ID_WIDTH];
assign s_axi_rresp = s_axi_r_reg[RESP_OFFSET +: 2];
assign s_axi_ruser = RUSER_ENABLE ? s_axi_r_reg[RUSER_OFFSET +: RUSER_WIDTH] : {RUSER_WIDTH{1'b0}};

// Write logic
always @* begin
    write = 1'b0;

    wr_ptr_next = wr_ptr_reg;

    if (m_axi_rvalid) begin
        // input data valid
        if (!rdfifo_full) begin
            // not rdfifo_full, perform write
            write = 1'b1;
            wr_ptr_next = wr_ptr_reg + 1;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        wr_ptr_reg <= {FIFO_ADDR_WIDTH+1{1'b0}}; 
    end else if (rdfifo_wrptr_rst) begin
        wr_ptr_reg <= {FIFO_ADDR_WIDTH+1{1'b0}}; 
    end else begin
        wr_ptr_reg <= wr_ptr_next;
    end

    wr_addr_reg <= wr_ptr_next;

    if (write) begin
        mem[wr_addr_reg[FIFO_ADDR_WIDTH-1:0]] <= m_axi_r;
    end
end

// Read logic
always @* begin
    read = 1'b0;

    rd_ptr_next = rd_ptr_reg;

    mem_read_data_valid_next = mem_read_data_valid_reg;

    if (store_output) begin // || !mem_read_data_valid_reg) begin
    //if (store_output && !mem_read_data_valid_reg) begin
        // output data not valid OR currently being transferred
        if (!rdfifo_empty) begin
            // not rdfifo_empty, perform read
            read = 1'b1;
            mem_read_data_valid_next = 1'b1;
            rd_ptr_next = rd_ptr_reg + 1;
        end else begin
            // rdfifo_empty, invalidate
            mem_read_data_valid_next = 1'b0;
        end
    end
    else begin
            mem_read_data_valid_next = 1'b0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        rd_ptr_reg <= {FIFO_ADDR_WIDTH+1{1'b0}};
        mem_read_data_valid_reg <= 1'b0;
    end else if (rdfifo_rdptr_rst) begin //this is required for compressor unit
        rd_ptr_reg <= {FIFO_ADDR_WIDTH+1{1'b0}};
        mem_read_data_valid_reg <= 1'b0;
    end else if (ld_rdfifo_rdptr) begin //this support just for naive compression , can combine reest and this later
        rd_ptr_reg <= {1'b0,rdfifo_rdptr};
        mem_read_data_valid_reg <= 1'b0;
    end
    else begin
        rd_ptr_reg <= rd_ptr_next;
        mem_read_data_valid_reg <= mem_read_data_valid_next;
    end

    rd_addr_reg <= rd_ptr_next;

    if (read) begin
        mem_read_data_reg <= mem[rd_addr_reg[FIFO_ADDR_WIDTH-1:0]];
    end
end

// Output register
always @* begin
    store_output = 1'b0;

    s_axi_rvalid_next = 1'b0; //s_axi_rvalid_reg;

    if (s_axi_rready) begin //  || !s_axi_rvalid) begin
        store_output = 1'b1;
        s_axi_rvalid_next = mem_read_data_valid_reg;
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axi_rvalid_reg <= 1'b0;
    end else begin
        s_axi_rvalid_reg <= s_axi_rvalid_next;
    end

    if (store_output) begin
        s_axi_r_reg <= mem_read_data_reg;
    end
end

endmodule
