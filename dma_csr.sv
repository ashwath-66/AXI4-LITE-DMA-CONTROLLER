// ============================================================================
// File: dma_csr.sv
// Description: Control and Status Registers (CSR) for AXI4-Lite DMA
// ============================================================================

module dma_csr #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                  clk,
    input  logic                  rst_n,
    axi4_lite_if.slave            s_axi,

    // Internal DMA Control Signals
    output logic [ADDR_WIDTH-1:0] src_addr,
    output logic [ADDR_WIDTH-1:0] dst_addr,
    output logic [DATA_WIDTH-1:0] xfer_len,
    output logic                  start_dma,

    // Internal DMA Status Signals
    input  logic                  dma_busy,
    input  logic                  dma_done,
    input  logic                  dma_error
);

    // Register Map offsets:
    // 0x00: Control (bit 0 = start_dma)
    // 0x04: Status  [dma_error, dma_done, dma_busy] (Read-Only)
    // 0x08: Source Address
    // 0x0C: Destination Address
    // 0x10: Transfer Length
    logic [DATA_WIDTH-1:0] reg_ctrl;
    logic [DATA_WIDTH-1:0] reg_src;
    logic [DATA_WIDTH-1:0] reg_dst;
    logic [DATA_WIDTH-1:0] reg_len;

    assign src_addr = reg_src;
    assign dst_addr = reg_dst;
    assign xfer_len = reg_len;

    // ------------------------------------------------------------------------
    // Write Channel Logic & Start Pulse Generation
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi.awready <= 1'b0;
            s_axi.wready  <= 1'b0;
            s_axi.bvalid  <= 1'b0;
            s_axi.bresp   <= 2'b00;
            reg_ctrl      <= '0;
            reg_src       <= '0;
            reg_dst       <= '0;
            reg_len       <= '0;
            start_dma     <= 1'b0;
        end else begin
            start_dma <= 1'b0; // Default pulse off

            if (!s_axi.awready && s_axi.awvalid && s_axi.wvalid) begin
                s_axi.awready <= 1'b1;
                s_axi.wready  <= 1'b1;

                case (s_axi.awaddr[4:2])
                    3'b000: begin
                        reg_ctrl  <= s_axi.wdata;
                        start_dma <= s_axi.wdata[0]; // Active-high 1-cycle trigger pulse
                    end
                    3'b010: reg_src <= s_axi.wdata; // Offset 0x08
                    3'b011: reg_dst <= s_axi.wdata; // Offset 0x0C
                    3'b100: reg_len <= s_axi.wdata; // Offset 0x10
                    default: ;
                endcase
                s_axi.bvalid <= 1'b1;
            end else begin
                if (s_axi.bready && s_axi.bvalid) begin
                    s_axi.bvalid  <= 1'b0;
                    s_axi.awready <= 1'b0;
                    s_axi.wready  <= 1'b0;
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // Read Channel Logic
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi.arready <= 1'b0;
            s_axi.rvalid  <= 1'b0;
            s_axi.rdata   <= '0;
            s_axi.rresp   <= 2'b00;
        end else begin
            if (!s_axi.arready && s_axi.arvalid) begin
                s_axi.arready <= 1'b1;
                case (s_axi.araddr[4:2])
                    3'b000: s_axi.rdata <= reg_ctrl;
                    3'b001: s_axi.rdata <= {29'b0, dma_error, dma_done, dma_busy}; // Offset 0x04
                    3'b010: s_axi.rdata <= reg_src;
                    3'b011: s_axi.rdata <= reg_dst;
                    3'b100: s_axi.rdata <= reg_len;
                    default: s_axi.rdata <= '0;
                endcase
                s_axi.rvalid <= 1'b1;
            end else begin
                if (s_axi.rready && s_axi.rvalid) begin
                    s_axi.rvalid  <= 1'b0;
                    s_axi.arready <= 1'b0;
                end
            end
        end
    end

endmodule : dma_csr