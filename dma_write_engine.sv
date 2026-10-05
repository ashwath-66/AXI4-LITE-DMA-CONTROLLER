// ============================================================================
// File: dma_write_engine.sv
// Description: Fixed AXI4-Lite Write Engine with Correct FIFO Handshake
// ============================================================================

module dma_write_engine #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  start_dma,
    input  logic [ADDR_WIDTH-1:0] dst_addr,
    input  logic [DATA_WIDTH-1:0] xfer_len,

    axi4_lite_if.master           m_axi,

    output logic                  fifo_pop,
    input  logic [DATA_WIDTH-1:0] fifo_rdata,
    input  logic                  fifo_empty,

    output logic                  dma_busy,
    output logic                  dma_done,
    output logic                  dma_error
);

    typedef enum logic [1:0] {
        IDLE,
        WRITE_REQ,
        WAIT_RESP
    } state_t;

    state_t state;
    logic [ADDR_WIDTH-1:0] current_addr;
    logic [DATA_WIDTH-1:0] bytes_remaining;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            m_axi.awvalid   <= 1'b0;
            m_axi.awaddr    <= '0;
            m_axi.wvalid    <= 1'b0;
            m_axi.wdata     <= '0;
            m_axi.wstrb     <= 4'b1111;
            m_axi.bready    <= 1'b0;
            fifo_pop        <= 1'b0;
            dma_busy        <= 1'b0;
            dma_done        <= 1'b0;
            dma_error       <= 1'b0;
            current_addr    <= '0;
            bytes_remaining <= '0;
        end else begin
            fifo_pop <= 1'b0; // Default pulse off

            case (state)
                IDLE: begin
                    dma_done <= 1'b0;
                    if (start_dma && (xfer_len > 0)) begin
                        dma_busy        <= 1'b1;
                        current_addr    <= dst_addr;
                        bytes_remaining <= xfer_len;
                        state           <= WRITE_REQ;
                    end
                end

                WRITE_REQ: begin
                    // Wait until FIFO has data, then present write signals
                    if (!fifo_empty && !m_axi.awvalid && !m_axi.wvalid) begin
                        m_axi.awaddr  <= current_addr;
                        m_axi.awvalid <= 1'b1;
                        m_axi.wdata   <= fifo_rdata; // Samples valid data
                        m_axi.wstrb   <= 4'b1111;
                        m_axi.wvalid  <= 1'b1;
                    end

                    // Once memory slave accepts write handshake
                    if (m_axi.awvalid && m_axi.wvalid && m_axi.awready && m_axi.wready) begin
                        m_axi.awvalid <= 1'b0;
                        m_axi.wvalid  <= 1'b0;
                        fifo_pop      <= 1'b1; // Pop FIFO AFTER data is accepted
                        m_axi.bready  <= 1'b1;
                        state         <= WAIT_RESP;
                    end
                end

                WAIT_RESP: begin
                    if (m_axi.bvalid && m_axi.bready) begin
                        m_axi.bready <= 1'b0;

                        if (bytes_remaining <= 4) begin
                            bytes_remaining <= '0;
                            dma_busy        <= 1'b0;
                            dma_done        <= 1'b1;
                            state           <= IDLE;
                        end else begin
                            bytes_remaining <= bytes_remaining - 4;
                            current_addr    <= current_addr + 4;
                            state           <= WRITE_REQ;
                        end
                    end
                end
            endcase
        end
    end

endmodule : dma_write_engine