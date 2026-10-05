// ============================================================================
// File: axi_dma_top.sv
// Description: Top-Level Module for AXI4-Lite DMA Controller
// ============================================================================

module axi_dma_top #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n,

    // AXI4-Lite Slave Interface for CSR Configuration
    axi4_lite_if.slave s_axi_csr,

    // AXI4-Lite Master Interfaces for Read and Write Engines
    axi4_lite_if.master m_axi_read,
    axi4_lite_if.master m_axi_write
);

    // Internal Interconnect Signals
    logic [ADDR_WIDTH-1:0] src_addr;
    logic [ADDR_WIDTH-1:0] dst_addr;
    logic [DATA_WIDTH-1:0] xfer_len;
    logic                  start_dma;
    logic                  dma_busy;
    logic                  dma_done;
    logic                  dma_error;

    // Internal FIFO Buffer Interconnects
    logic                  fifo_push;
    logic                  fifo_pop;
    logic [DATA_WIDTH-1:0] fifo_wdata;
    logic [DATA_WIDTH-1:0] fifo_rdata;
    logic                  fifo_empty;
    logic                  fifo_full;

    // 1. Control & Status Register Bank
    dma_csr #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_csr (
        .clk       (clk),
        .rst_n     (rst_n),
        .s_axi     (s_axi_csr),
        .src_addr  (src_addr),
        .dst_addr  (dst_addr),
        .xfer_len  (xfer_len),
        .start_dma (start_dma),
        .dma_busy  (dma_busy),
        .dma_done  (dma_done),
        .dma_error (dma_error)
    );

    // 2. Read Engine
    dma_read_engine #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_read_engine (
        .clk       (clk),
        .rst_n     (rst_n),
        .start_dma (start_dma),
        .src_addr  (src_addr),
        .xfer_len  (xfer_len),
        .m_axi     (m_axi_read),
        .fifo_push (fifo_push),
        .fifo_wdata(fifo_wdata),
        .fifo_full (fifo_full)
    );

    // 3. Internal FIFO Buffer
    dma_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(16)
    ) u_fifo (
        .clk   (clk),
        .rst_n (rst_n),
        .push  (fifo_push),
        .pop   (fifo_pop),
        .wdata (fifo_wdata),
        .rdata (fifo_rdata),
        .empty (fifo_empty),
        .full  (fifo_full)
    );

    // 4. Write Engine
    dma_write_engine #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_write_engine (
        .clk       (clk),
        .rst_n     (rst_n),
        .start_dma (start_dma),
        .dst_addr  (dst_addr),
        .xfer_len  (xfer_len),
        .m_axi     (m_axi_write),
        .fifo_pop  (fifo_pop),
        .fifo_rdata(fifo_rdata),
        .fifo_empty(fifo_empty),
        .dma_busy  (dma_busy),
        .dma_done  (dma_done),
        .dma_error (dma_error)
    );

endmodule : axi_dma_top