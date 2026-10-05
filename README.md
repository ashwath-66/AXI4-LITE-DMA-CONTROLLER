# AXI4-Lite Direct Memory Access (DMA) Controller

A verified, single-channel memory-to-memory DMA controller written in SystemVerilog and compliant with the AMBA AXI4-Lite protocol. It offloads bulk data transfers from the host CPU, reducing processor overhead and improving system bus throughput.

---

## 🚀 Key Features

- **Decoupled engine pipeline:** Independent AXI master read (`dma_read_engine`) and write (`dma_write_engine`) state machines isolate source and destination memory latencies.
- **Synchronous rate buffering:** A 16x32-bit circular FIFO (`dma_fifo`) handles synchronization, rate matching, and backpressure between the two engines.
- **Memory-mapped CSR bank:** A 32-bit AXI slave interface (`dma_csr`), mapped from `0x00` to `0x10`, provides runtime control (`start_dma`) and status tracking (`dma_busy`, `dma_done`, `dma_error`).
- **Synchronized handshaking:** `fifo_pop` is tied strictly to the completion of the combined write address and data handshakes, which eliminates sub-cycle write-pointer race conditions.

---

## 📐 System Architecture

```text
                       +--------------------------------------------+
                       |                axi_dma_top                 |
                       |                                            |
Host CPU AXI-Lite ---->| +-----------+  Control   +--------------+  |----> Source Memory
   (s_axi_csr)         | |  dma_csr  |----------->|  dma_read_   |  |     (m_axi_read)
                       | +-----------+  Signals   |    engine    |  |
                       |                          +------+-------+  |
                       |                                 | fifo_push, wdata
                       |                                 v
                       |                          +--------------+  |
                       |                          |   dma_fifo   |  |
                       |                          +------+-------+  |
                       |                                 | fifo_pop, rdata
                       |                                 v
                       |                          +--------------+  |
                       |                          |  dma_write_  |  |----> Destination Memory
                       |                          |    engine    |  |     (m_axi_write)
                       |                          +--------------+  |
                       +--------------------------------------------+
```

---

## 📑 Register Map

| Offset | Register     | Access    | Description                                           |
|--------|--------------|-----------|-------------------------------------------------------|
| `0x00` | `REG_CTRL`   | R/W       | Bit [0]: `start_dma` (self-clearing single-cycle trigger) |
| `0x04` | `REG_STATUS` | Read-only | Bit [0]: `dma_busy`, Bit [1]: `dma_done`, Bit [2]: `dma_error` |
| `0x08` | `REG_SRC`    | R/W       | Bits [31:0]: source memory start address              |
| `0x0C` | `REG_DST`    | R/W       | Bits [31:0]: destination memory start address         |
| `0x10` | `REG_LEN`    | R/W       | Bits [31:0]: transfer size in bytes                   |

---

## 📂 Repository Layout

```text
.
├── hdl/
│   ├── axi4_lite_if.sv       # SystemVerilog interface bundle (5 channels)
│   ├── dma_csr.sv            # Memory-mapped control & status registers
│   ├── dma_read_engine.sv    # AXI read master FSM
│   ├── dma_write_engine.sv   # AXI write master FSM
│   ├── dma_fifo.sv           # 16x32 synchronous circular FIFO
│   └── axi_dma_top.sv        # Top-level integration wrapper
├── tb/
│   └── tb_axi_dma_top.sv     # Self-checking testbench
└── README.md                 # Project documentation
```

---

## 🔍 Verification Highlight

During simulation, a sub-cycle write-pointer race condition was found: data was popped from the internal FIFO before the destination memory asserted `wready`.

**Fix:** `fifo_pop` in `dma_write_engine.sv` now asserts only when both the address and data channel handshakes complete simultaneously:

```systemverilog
assign fifo_pop = m_axi.awvalid && m_axi.wvalid && m_axi.awready && m_axi.wready;
```

---

## 🛠️ Simulation Instructions

### Icarus Verilog + GTKWave (Linux CLI)

```bash
# Compile design sources and testbench
iverilog -g2012 -o dma_sim hdl/*.sv tb/tb_axi_dma_top.sv

# Run the simulation
vvp dma_sim

# View the waveform
gtkwave dump.vcd
```

### AMD Vivado

1. Open Vivado and create a new project.
2. Add all files in `hdl/` as **Design Sources**.
3. Add `tb/tb_axi_dma_top.sv` as a **Simulation Source**.
4. Run **Behavioral Simulation**.

---

## 📜 License

This repository is licensed under the [MIT License](LICENSE).
