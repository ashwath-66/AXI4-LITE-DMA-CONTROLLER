// ============================================================================
// File: dma_read_engine.sv
// Description: Fixed AXI4-Lite Read Engine
// ============================================================================

module dma_read_engine #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  start_dma,
    input  logic [ADDR_WIDTH-1:0] src_addr,
    input  logic [DATA_WIDTH-1:0] xfer_len,

    axi4_lite_if.master           m_axi,

    output logic                  fifo_push,
    output logic [DATA_WIDTH-1:0] fifo_wdata,
    input  logic                  fifo_full
);

    typedef enum logic [1:0] {
        IDLE,
        ADDR_STATE,
        DATA_STATE
    } state_t;

    state_t state;
    logic [ADDR_WIDTH-1:0] current_addr;
    logic [DATA_WIDTH-1:0] bytes_remaining;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            m_axi.arvalid   <= 1'b0;
            m_axi.araddr    <= '0;
            m_axi.rready    <= 1'b0;
            fifo_push       <= 1'b0;
            fifo_wdata      <= '0;
            current_addr    <= '0;
            bytes_remaining <= '0;
        end else begin
            fifo_push <= 1'b0;

            case (state)
                IDLE: begin
                    if (start_dma && (xfer_len > 0)) begin
                        current_addr    <= src_addr;
                        bytes_remaining <= xfer_len;
                        state           <= ADDR_STATE;
                    end
                end

                ADDR_STATE: begin
                    if (!fifo_full && !m_axi.arvalid) begin
                        m_axi.araddr  <= current_addr;
                        m_axi.arvalid <= 1'b1;
                    end

                    if (m_axi.arvalid && m_axi.arready) begin
                        m_axi.arvalid <= 1'b0;
                        m_axi.rready  <= 1'b1;
                        state         <= DATA_STATE;
                    end
                end

                DATA_STATE: begin
                    if (m_axi.rvalid && m_axi.rready) begin
                        m_axi.rready <= 1'b0;
                        fifo_push    <= 1'b1;
                        fifo_wdata   <= m_axi.rdata;

                        if (bytes_remaining <= 4) begin
                            bytes_remaining <= '0;
                            state           <= IDLE;
                        end else begin
                            bytes_remaining <= bytes_remaining - 4;
                            current_addr    <= current_addr + 4;
                            state           <= ADDR_STATE;
                        end
                    end
                end
            endcase
        end
    end

endmodule : dma_read_engine