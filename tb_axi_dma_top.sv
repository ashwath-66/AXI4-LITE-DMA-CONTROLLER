// ============================================================================
// File: tb_axi_dma_top.sv
// Description: Self-Checking Testbench for AXI4-Lite DMA Controller
// ============================================================================

`timescale 1ns / 1ps

.module tb_axi_dma_top;

    // Parameters
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10; // 100 MHz clock

    // Clock and Reset Signals
    logic clk;
    logic rst_n;

    // Interface Instantiations
    axi4_lite_if #(ADDR_WIDTH, DATA_WIDTH) s_axi_csr   (.clk(clk), .rst_n(rst_n));
    axi4_lite_if #(ADDR_WIDTH, DATA_WIDTH) m_axi_read  (.clk(clk), .rst_n(rst_n));
    axi4_lite_if #(ADDR_WIDTH, DATA_WIDTH) m_axi_write (.clk(clk), .rst_n(rst_n));

    // Simulated Memory Banks (256 x 32-bit words)
    logic [DATA_WIDTH-1:0] src_memory [0:255];
    logic [DATA_WIDTH-1:0] dst_memory [0:255];

    // Design Under Test (DUT)
    axi_dma_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .s_axi_csr  (s_axi_csr),
        .m_axi_read (m_axi_read),
        .m_axi_write(m_axi_write)
    );

    // ------------------------------------------------------------------------
    // Clock Generator
    // ------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ------------------------------------------------------------------------
    // CPU Configuration Task
    // ------------------------------------------------------------------------
    task automatic cpu_csr_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            s_axi_csr.awaddr  <= addr;
            s_axi_csr.awvalid <= 1'b1;
            s_axi_csr.wdata   <= data;
            s_axi_csr.wstrb   <= 4'b1111;
            s_axi_csr.wvalid  <= 1'b1;
            s_axi_csr.bready  <= 1'b1;

            wait(s_axi_csr.awready && s_axi_csr.wready);
            @(posedge clk);
            s_axi_csr.awvalid <= 1'b0;
            s_axi_csr.wvalid  <= 1'b0;

            wait(s_axi_csr.bvalid);
            @(posedge clk);
            s_axi_csr.bready  <= 1'b0;
        end
    endtask

    // ------------------------------------------------------------------------
    // Memory Slave Model: Read Channel
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_read.arready <= 1'b0;
            m_axi_read.rvalid  <= 1'b0;
            m_axi_read.rdata   <= '0;
            m_axi_read.rresp   <= 2'b00;
        end else begin
            m_axi_read.arready <= 1'b1;

            if (m_axi_read.arvalid && m_axi_read.arready) begin
                m_axi_read.rdata  <= src_memory[m_axi_read.araddr[9:2]]; // Word-aligned index
                m_axi_read.rvalid <= 1'b1;
            end else if (m_axi_read.rready && m_axi_read.rvalid) begin
                m_axi_read.rvalid <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Memory Slave Model: Write Channel
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_write.awready <= 1'b0;
            m_axi_write.wready  <= 1'b0;
            m_axi_write.bvalid  <= 1'b0;
            m_axi_write.bresp   <= 2'b00;
        end else begin
            m_axi_write.awready <= 1'b1;
            m_axi_write.wready  <= 1'b1;

            if (m_axi_write.awvalid && m_axi_write.wvalid && m_axi_write.awready && m_axi_write.wready) begin
                dst_memory[m_axi_write.awaddr[9:2]] <= m_axi_write.wdata;
                m_axi_write.bvalid <= 1'b1;
            end else if (m_axi_write.bready && m_axi_write.bvalid) begin
                m_axi_write.bvalid <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Test Sequence Execution
    // ------------------------------------------------------------------------
    initial begin
        // 1. Initialize Bus Defaults & Memory Arrays
        s_axi_csr.awaddr  = '0;
        s_axi_csr.awvalid = '0;
        s_axi_csr.wdata   = '0;
        s_axi_csr.wstrb   = '0;
        s_axi_csr.wvalid  = '0;
        s_axi_csr.bready  = '0;
        s_axi_csr.araddr  = '0;
        s_axi_csr.arvalid = '0;
        s_axi_csr.rready  = '0;

        for (int i = 0; i < 256; i++) begin
            src_memory[i] = 32'ha5a50000 + i;
            dst_memory[i] = 32'h00000000;
        end

        // 2. Apply Hardware Reset
        rst_n = 0;
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        $display("\n[TB] --- Starting AXIWHOLE DMA Transfer Test ---");

        // 3. Configure Registers via CSR
        // Source Address = 0x0000_0000 (Index 0)
        cpu_csr_write(32'h08, 32'h0000_0000);

        // Destination Address = 0x0000_0040 (64 bytes offset = Index 16)
        cpu_csr_write(32'h0C, 32'h0000_0040);

        // Transfer Length = 16 Bytes (4 words)
        cpu_csr_write(32'h10, 32'd16);

        // Trigger DMA (Control Register bit 0)
        cpu_csr_write(32'h00, 32'h0000_0001);

        // 4. Wait for DMA Transfer Completion
        #600;

        // 5. Verify Results against Destination Index offset (16 + i)
        $display("[TB] --- Verifying Memory Transfer ---");
        for (int i = 0; i < 4; i++) begin
            $display("SRC Word %0d: 0x%08h | DST Word %0d: 0x%08h", 
                     i, src_memory[i], i, dst_memory[16 + i]);
            if (src_memory[i] === dst_memory[16 + i]) begin
                $display("  -> MATCH!");
            end else begin
                $display("  -> ERROR: MISMATCH!");
            end
        end

        $display("[TB] --- Simulation Complete ---\n");
        $finish;
    end

endmodule : tb_axi_dma_top