// SPDX-License-Identifier: Apache-2.0
`default_nettype none
/*
Memory Controller

Module to wrap all components together and connect the AXI to the SPI Controller.
*/

module OctalMemoryController_quad #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = (DATA_WIDTH / 8),
    parameter ID_WIDTH = 8,
    parameter CHIP_TYPE = -1,  // 1 for simulation with Infineon model, 2 for hardware with APMemory
    // clk frequency range: minimum times (reset) are derived from the highest, maximum times (tCEM) from the lowest
    parameter integer CLK_FREQ_HZ = 50_000_000,  // highest clk frequency
    parameter integer CLK_FREQ_MIN_HZ = 10_000_000,  // lowest clk frequency (slower clock for timing problems / tests)
    parameter integer MEMORY_RESET_CYCLES = (CLK_FREQ_HZ + 49) / 50,  // RESET# low time of the memories (20 ms)
    parameter integer CEM_MAX_CYCLES = CLK_FREQ_MIN_HZ / 1000 * 7 / 1000,  // longest CE# low time (7 us, tCEM 8 us)
    parameter BUS_CLOCK_NEGEDGE = 1,  // 1: bus clock from a negedge register, centre aligned data; 0: edge aligned (see OctalSPI_quad)
    // read data FIFO: 0 = none, else a power of 2 (>= 2); RREADY stalls then no longer split the memory burst
    parameter integer R_FIFO_DEPTH = 0
) (
    input clk,
    input rstn,  // active low, asynchronous assert, synchronous release (SoC: resetn_async)

    // SPI Pins
    output [3:0] o_spi_bus_clock,
    output [3:0] o_spi_bus_clock_neg,
    output [3:0] o_spi_chip_select_neg,
    output o_spi_reset_neg,

    input  [STRB_WIDTH-1:0] i_data_strobe,
    output [STRB_WIDTH-1:0] o_data_strobe,
    output [STRB_WIDTH-1:0] o_data_strobe_output_enable, // 0 input, 1 output

    input  [DATA_WIDTH-1:0] i_data,
    output [DATA_WIDTH-1:0] o_data,
    output [STRB_WIDTH-1:0] o_data_output_enable, // 0 input, 1 output

    // AXI Pins
    input  wire [  ID_WIDTH-1:0] s_axi_awid,     // write address channel
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire [           7:0] s_axi_awlen,
    input  wire [           2:0] s_axi_awsize,
    input  wire [           1:0] s_axi_awburst,
    input  wire                  s_axi_awlock,
    input  wire [           3:0] s_axi_awcache,
    input  wire [           2:0] s_axi_awprot,
    input  wire                  s_axi_awvalid,
    output wire                  s_axi_awready,

    input  wire [DATA_WIDTH-1:0] s_axi_wdata,   // write data channel
    input  wire [STRB_WIDTH-1:0] s_axi_wstrb,
    input  wire                  s_axi_wlast,
    input  wire                  s_axi_wvalid,
    output wire                  s_axi_wready,

    output wire [ID_WIDTH-1:0] s_axi_bid,     // write response channel
    output wire [         1:0] s_axi_bresp,
    output wire                s_axi_bvalid,
    input  wire                s_axi_bready,

    input  wire [  ID_WIDTH-1:0] s_axi_arid,     // read address channel
    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire [           7:0] s_axi_arlen,
    input  wire [           2:0] s_axi_arsize,
    input  wire [           1:0] s_axi_arburst,
    input  wire                  s_axi_arlock,
    input  wire [           3:0] s_axi_arcache,
    input  wire [           2:0] s_axi_arprot,
    input  wire                  s_axi_arvalid,
    output wire                  s_axi_arready,

    output wire [  ID_WIDTH-1:0] s_axi_rid,     // read data channel
    output wire [DATA_WIDTH-1:0] s_axi_rdata,
    output wire [           1:0] s_axi_rresp,
    output wire                  s_axi_rlast,
    output wire                  s_axi_rvalid,
    input  wire                  s_axi_rready
);

    wire spi_busy;
    wire spi_next_word;
    wire spi_recieved_next_word;
    wire [ADDR_WIDTH-1:0] axi_address;
    wire [DATA_WIDTH-1:0] axi_data_read;
    wire [DATA_WIDTH-1:0] axi_data_write;
    wire axi_write_enable;
    wire axi_write_data_valid;
    wire axi_last_word;
    wire axi_start_transaction;

    // R channel between AXI4Subordinate and the optional read data FIFO
    wire [  ID_WIDTH-1:0] ctrl_rid;
    wire [DATA_WIDTH-1:0] ctrl_rdata;
    wire [           1:0] ctrl_rresp;
    wire                  ctrl_rlast;
    wire                  ctrl_rvalid;
    wire                  ctrl_rready;

    /* verilator lint_off MODMISSING */
    generate
        if (R_FIFO_DEPTH == 0) begin : gen_r_direct
            assign s_axi_rid = ctrl_rid;
            assign s_axi_rdata = ctrl_rdata;
            assign s_axi_rresp = ctrl_rresp;
            assign s_axi_rlast = ctrl_rlast;
            assign s_axi_rvalid = ctrl_rvalid;
            assign ctrl_rready = s_axi_rready;
        end else if (R_FIFO_DEPTH < 2 || (R_FIFO_DEPTH & (R_FIFO_DEPTH - 1)) != 0) begin : gen_r_fifo_depth_check
            R_FIFO_DEPTH_must_be_0_or_a_power_of_2 illegal_instance ();
        end else begin : gen_r_fifo
            localparam integer RW = ID_WIDTH + DATA_WIDTH + 3;  // entry: id, data, resp, last
            localparam integer AW = $clog2(R_FIFO_DEPTH);
            reg  [      RW-1:0] r_fifo_mem      [0:R_FIFO_DEPTH-1];
            reg  [        AW:0] r_fifo_count;
            reg  [      AW-1:0] r_fifo_wr_ptr;
            reg  [      AW-1:0] r_fifo_rd_ptr;
            wire [ID_WIDTH-1:0] r_fifo_out_id;
            wire                r_fifo_out_last;
            wire                r_fifo_push = ctrl_rvalid & ctrl_rready;
            wire                r_fifo_pop = s_axi_rvalid & s_axi_rready;
            assign ctrl_rready  = ~r_fifo_count[AW];  // not full
            assign s_axi_rvalid = (r_fifo_count != 0);
            assign {r_fifo_out_id, s_axi_rdata, s_axi_rresp, r_fifo_out_last} = r_fifo_mem[r_fifo_rd_ptr];
            // RID/RLAST are 0 while empty: the FIFO RAM has no reset and interconnects may route R by RID with RVALID low
            assign s_axi_rid   = s_axi_rvalid ? r_fifo_out_id : {ID_WIDTH{1'b0}};
            assign s_axi_rlast = s_axi_rvalid & r_fifo_out_last;
            always @(posedge clk) begin
                if (r_fifo_push) r_fifo_mem[r_fifo_wr_ptr] <= {ctrl_rid, ctrl_rdata, ctrl_rresp, ctrl_rlast};
            end
            always @(posedge clk or negedge rstn) begin
                if (!rstn) begin
                    r_fifo_count  <= {(AW + 1) {1'b0}};
                    r_fifo_wr_ptr <= {AW{1'b0}};
                    r_fifo_rd_ptr <= {AW{1'b0}};
                end else begin
                    if (r_fifo_push) r_fifo_wr_ptr <= r_fifo_wr_ptr + 1'b1;
                    if (r_fifo_pop) r_fifo_rd_ptr <= r_fifo_rd_ptr + 1'b1;
                    r_fifo_count <= r_fifo_count + {{AW{1'b0}}, r_fifo_push} - {{AW{1'b0}}, r_fifo_pop};
                end
            end
        end
    endgenerate
    /* verilator lint_on MODMISSING */


    OSPIController_quad #(
        .ADDRESS_LENGTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CHIP_TYPE(CHIP_TYPE),
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .CLK_FREQ_MIN_HZ(CLK_FREQ_MIN_HZ),
        .MEMORY_RESET_CYCLES(MEMORY_RESET_CYCLES),
        .CEM_MAX_CYCLES(CEM_MAX_CYCLES),
        .BUS_CLOCK_NEGEDGE(BUS_CLOCK_NEGEDGE)
    ) SPI_Controller (
        .clk(clk),
        .reset_neg(rstn),
        .go(axi_start_transaction),

        .i_address(axi_address),
        .i_write_enable(axi_write_enable),
        .i_write_data_valid(axi_write_data_valid),
        .i_last_word(axi_last_word),
        .i_data_write(axi_data_write),
        .i_data_word_mask(~s_axi_wstrb), // the axi write strobe signals are inverted to the octal-spi signals
        .o_data_read(axi_data_read),
        .o_busy(spi_busy),
        .o_next_word(spi_next_word),
        .o_recieved_next_word(spi_recieved_next_word),

        // SPI Pins
        .o_bus_clock(o_spi_bus_clock),
        .o_bus_clock_neg(o_spi_bus_clock_neg),
        .o_chip_select_neg(o_spi_chip_select_neg),
        .o_reset_neg(o_spi_reset_neg),
        .i_data_strobe(i_data_strobe),
        .o_data_strobe(o_data_strobe),
        .o_data_strobe_output_enable(o_data_strobe_output_enable),
        .i_data(i_data),
        .o_data(o_data),
        .o_data_output_enable(o_data_output_enable)
    );


    AXI4Subordinate #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ID_WIDTH  (ID_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) AXI4_Subordinate (
        .clk(clk),
        .rst_neg(rstn),

        // Control Interface Pins
        .i_write_word_ready(spi_next_word),
        .i_read_word_ready(spi_recieved_next_word),
        .i_busy(spi_busy),
        .o_last_word(axi_last_word),
        .o_write_enable(axi_write_enable),
        .o_write_data_valid(axi_write_data_valid),
        .o_start_transaction(axi_start_transaction),
        .o_address(axi_address),
        .o_write_data(axi_data_write),
        .i_read_data(axi_data_read),

        // AXI Pins
        .s_axi_awid(s_axi_awid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awsize(s_axi_awsize),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bid(s_axi_bid),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_arid(s_axi_arid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arsize(s_axi_arsize),
        .s_axi_arburst(s_axi_arburst),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rid(ctrl_rid),
        .s_axi_rdata(ctrl_rdata),
        .s_axi_rresp(ctrl_rresp),
        .s_axi_rlast(ctrl_rlast),
        .s_axi_rvalid(ctrl_rvalid),
        .s_axi_rready(ctrl_rready)
    );


endmodule

// restore the default for files compiled after this one
`default_nettype wire
