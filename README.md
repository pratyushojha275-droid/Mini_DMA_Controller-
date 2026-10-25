# Mini DMA Controller with Asynchronous FIFO

## About the Project

This project is a Verilog-based design of a Mini Direct Memory Access (DMA) Controller with an Asynchronous FIFO.

DMA is used to transfer data from one memory location to another without requiring the CPU to handle every data word individually.

In this project, the DMA controller manages data transfers between main memory and different I/O blocks. An asynchronous FIFO is used to temporarily store data while transferring it between two different clock domains.

The design is developed using Verilog HDL and can be simulated using AMD/Xilinx Vivado.

## Project Objectives

- Design a DMA controller using Verilog HDL.
- Transfer data between memory and I/O blocks.
- Use an asynchronous FIFO for temporary data storage.
- Understand memory-mapped control and status registers.
- Verify data transfers using a Verilog testbench.
- Observe the working of the design through simulation waveforms.

## How Does It Work?

The project follows this basic flow:

CPU configures the DMA
        |
        v
DMA reads data from the source
        |
        v
Data is temporarily stored in FIFO
        |
        v
DMA writes data to the destination
        |
        v
DMA reports transfer completion

The CPU provides the source address, destination address, and number of words to transfer. The DMA controller then manages the data transfer.

## Main Features

- 32-bit data width.
- 32-bit address width by default.
- Memory-to-memory data transfers.
- Memory-to-I/O data transfers.
- I/O-to-memory data transfers.
- Transfers between modeled I/O blocks.
- Asynchronous FIFO with a default depth of 16 words.
- CPU-accessible configuration and status registers.
- Busy and Done status indicators.
- Verilog testbench for functional verification.

## Project Architecture

The project consists of the following main blocks:

1. DMA Controller
   - Stores configuration information.
   - Controls read and write operations.
   - Maintains source and destination addresses.
   - Tracks the number of words to transfer.

2. Asynchronous FIFO
   - Temporarily stores data.
   - Supports separate read and write clocks.
   - Helps transfer data between different clock domains.

3. Memory Subsystem
   - Models the main memory.
   - Supports memory read and write operations.

4. I/O Subsystem
   - Models four I/O memory blocks.
   - Supports data transfers to and from the modeled I/O blocks.

5. Testbench
   - Generates clocks and reset.
   - Configures the DMA controller.
   - Tests different transfer scenarios.
   - Compares destination data with expected data.

## Project Folder Structure

Mini_DMA_Controller/
|
|-- README.md
|
|-- rtl/
|   |-- dma_system.v
|   |-- dma_controller.v
|   |-- async_fifo.v
|   |-- memory_subsystem.v
|   |-- io_subsystem.v
|
|-- sim/
|   |-- tb_dma_system.v
|
|-- mem_init/
    |-- ram_array.hex
    |-- rom_array0.hex
    |-- rom_array 1.hex
    |-- rom_array 2.hex
    |-- rom_array 3.hex

## File Description

| File | Description |
|------|-------------|
| dma_system.v | Top-level module that connects the DMA controller, memory, and I/O blocks. |
| dma_controller.v | Controls DMA operations and maintains configuration and status registers. |
| async_fifo.v | Stores data temporarily between read and write clock domains. |
| memory_subsystem.v | Models the main memory. |
| io_subsystem.v | Models the I/O memory blocks. |
| tb_dma_system.v | Testbench used to simulate and verify data transfers. |
| .hex files | Supporting data files for memory initialization when enabled. |

## DMA Register Map

The CPU uses the following addresses to configure and monitor the DMA controller.

| CPU Address | Register | Function |
|-------------|----------|----------|
| 0x00000000 | SRC_ADDR | Stores the source address. |
| 0x00000004 | DST_ADDR | Stores the destination address. |
| 0x00000008 | COUNT | Stores the number of words to transfer. |
| 0x0000000C | CONTROL/STATUS | Starts the transfer and reports DMA status. |

### Control and Status

- Writing bit 0 as 1 starts a transfer when the DMA is not busy.
- Writing bit 1 as 1 clears the stored Done flag.
- When reading the status register, bit 0 indicates Busy.
- When reading the status register, bit 1 indicates Done.

## Memory Address Map

| Memory Block | Base Address | Capacity |
|--------------|--------------|----------|
| I/O 0 | 0x00001000 | 64 words |
| I/O 1 | 0x00001100 | 64 words |
| I/O 2 | 0x00001200 | 64 words |
| I/O 3 | 0x00001300 | 64 words |
| Main Memory | 0x00002000 | 1024 words |

Each word contains 32 bits, or 4 bytes. Therefore, the address increases by 4 for every word transferred.

## Example of a DMA Transfer

Suppose the CPU configures the following values:

- Source Address: 0x00002000
- Destination Address: 0x00001000
- Transfer Count: 16 words

The DMA controller attempts to transfer 16 words from main memory to I/O 0.

The expected address sequence is:

Source:
0x2000, 0x2004, 0x2008, ... 0x203C

Destination:
0x1000, 0x1004, 0x1008, ... 0x103C

The testbench checks whether the destination contains the expected data after the transfer.

## How to Run the Project in Vivado

1. Open AMD/Xilinx Vivado.
2. Create a new RTL Project.
3. Add the following files under Design Sources:
   - dma_system.v
   - dma_controller.v
   - async_fifo.v
   - memory_subsystem.v
   - io_subsystem.v
4. Set dma_system as the top module for Design Sources.
5. Add tb_dma_system.v under Simulation Sources.
6. Set tb_dma_system as the simulation top module.
7. Check the memory initialization filenames and paths if the .hex files are being used.
8. Select Run Simulation.
9. Click Run Behavioral Simulation.
10. Click Run All in the simulation window.
11. Check the Tcl Console or simulation log for the final test result.

The testbench initializes memory arrays for its tests. If the .hex initialization files are disabled, ensure the RTL configuration is consistent with that choice.

## Important Signals to Observe

| Signal | Purpose |
|--------|---------|
| sys_clk | System clock. |
| io_clk | I/O clock. |
| rst_n | Active-low reset. |
| cpu_addr | Address of the DMA register being accessed by the CPU. |
| cpu_wdata | Data written by the CPU. |
| cpu_rdata | Data returned to the CPU. |
| cpu_we | CPU write-enable signal. |
| cpu_re | CPU read-enable signal. |
| src_addr | Current source address used by the DMA. |
| src_re | Source read request. |
| src_ready | Indicates source-side readiness. |
| fifo_we | FIFO write-enable signal. |
| fifo_re | FIFO read-enable signal. |
| fifo_full | Indicates whether the FIFO is full. |
| fifo_empty | Indicates whether the FIFO is empty. |
| dst_addr | Current destination address used by the DMA. |
| dst_we | Destination write-enable signal. |
| dst_ready | Indicates destination-side readiness. |
| dma_busy_cpu | Indicates whether the DMA is busy. |
| dma_done_cpu | Indicates that the DMA has reported completion. |

## Verification

The provided testbench attempts several transfer scenarios, including:

- Main memory to I/O 0.
- Main memory to other I/O blocks.
- I/O to main memory.
- Transfers between I/O blocks.
- Main memory to main memory.

The testbench compares the transferred data with expected values and reports errors or a final simulation result.

A successful result should be confirmed by running the complete simulation and checking the final console message. A waveform showing clocks and configuration writes alone does not prove that the entire data transfer has succeeded.

## Tools Used

- Verilog HDL
- AMD/Xilinx Vivado
- Behavioral Simulation

## Conclusion

This project demonstrates the basic design and simulation of a DMA controller with asynchronous FIFO buffering.

It provides practical experience with Verilog modules, memory-mapped registers, clock domains, FIFO operation, control logic, and testbench-based verification.

The design is intended for educational purposes and should be fully verified before synthesis or FPGA implementation.
