// ============================================================================
// File: dma_fifo.sv
// Description: Internal Synchronous FIFO Buffer
// ============================================================================

module dma_fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 16
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  push,
    input  logic                  pop,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  empty,
    output logic                  full
);

    localparam ADDR_W = $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_W:0]       wptr;
    logic [ADDR_W:0]       rptr;

    assign empty = (wptr == rptr);
    assign full  = (wptr[ADDR_W] != rptr[ADDR_W]) && (wptr[ADDR_W-1:0] == rptr[ADDR_W-1:0]);
    assign rdata = mem[rptr[ADDR_W-1:0]];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= '0;
            rptr <= '0;
        end else begin
            if (push && !full) begin
                mem[wptr[ADDR_W-1:0]] <= wdata;
                wptr <= wptr + 1'b1;
            end
            if (pop && !empty) begin
                rptr <= rptr + 1'b1;
            end
        end
    end

endmodule : dma_fifo