Mini DMA Controller with Asynchronous FIFO
1. About the Project
This project is a Verilog design of a small Direct Memory Access (DMA) controller. DMA helps move data from a source address to a destination address without the CPU having to copy every data word itself.

The design contains a DMA controller, an asynchronous FIFO, a main-memory model, and four I/O memory blocks. A testbench is included to simulate different kinds of transfers in Vivado.
Project status: Verilog source files and a simulation testbench are provided. Run the testbench and check the final console message to confirm whether the current version passes all tests.

2. How It Works
The transfer follows this general flow:
CPU configures DMA
        |
        v
DMA reads data from the source
        |
        v
Asynchronous FIFO temporarily stores the data
        |
        v
DMA writes data to the destination
        |
        v
DMA sets the DONE status when the transfer finishes
The CPU provides three main settings:
- Source address: where the data should be read from.
- Destination address: where the data should be written.
- Transfer count: how many 32-bit words should be copied.
The FIFO buffers data between the read side and write side. It is designed to use separate read-side and write-side clocks.
3. Main Features
- 32-bit data path and 32-bit addresses by default.
- Memory-to-memory transfers.
- Memory-to-I/O and I/O-to-memory transfers.
- Transfers between the modeled I/O blocks.
- Asynchronous FIFO with a default depth of 16 words.
- CPU-visible source, destination, count, control, and status registers.
- busy and done status bits.
- A Verilog testbench that checks several transfer scenarios.
This is an educational RTL/simulation project. It has not been presented here as a verified, board-ready DMA implementation.
4. Project Folder Structure
Keep the files arranged like this in the repository:
Mini_DMA_Controller/
├── README.md
├── rtl/
│   ├── dma_system.v
│   ├── dma_controller.v
│   ├── async_fifo.v
│   ├── memory_subsystem.v
│   └── io_subsystem.v
├── sim/
│   └── tb_dma_system.v
└── mem_init/
    ├── ram_array.hex
    ├── rom_array0.hex
    ├── rom_array 1.hex
    ├── rom_array 2.hex
    └── rom_array 3.hex
What each file does
File	Purpose
dma_system.v	Top-level module. Connects the DMA controller, memory, and I/O blocks.
dma_controller.v	Holds DMA configuration registers and controls read/write transfers.
async_fifo.v	Temporarily buffers words between the read and write clock domains.
memory_subsystem.v	Models the main memory.
io_subsystem.v	Models an I/O memory block. Four instances are connected in dma_system.v.
tb_dma_system.v	Generates clocks and reset, configures transfers, and checks the results.
*.hex	Optional memory initialization data files. The file paths in the RTL must match the actual filenames and locations if these files are used.


5. Address Map
DMA configuration registers
The CPU writes to these addresses to configure the DMA controller:
CPU address	Register	Meaning
0x00000000	SRC_ADDR	Source address
0x00000004	DST_ADDR	Destination address
0x00000008	COUNT	Number of 32-bit words to transfer
0x0000000C	CONTROL/STATUS	Start command and DMA status


For the control register:
- Writing bit 0 as 1 starts a transfer when the DMA is not already busy.
- Writing bit 1 as 1 clears the stored done flag.
- When read, status bit 0 indicates busy and bit 1 indicates done.
Data memory and I/O address ranges
Block	Base address	Capacity in the current RTL
I/O 0	0x00001000	64 words
I/O 1	0x00001100	64 words
I/O 2	0x00001200	64 words
I/O 3	0x00001300	64 words
Main memory	0x00002000	1024 words


Each word is 32 bits (4 bytes), so addresses advance by 4 for each word. For example, a 4-word transfer from source 0x2000 reads addresses 0x2000, 0x2004, 0x2008, and 0x200C.
6. How to Run the Simulation in Vivado
1. Open Vivado and create an RTL Project.
2. Add these five files as Design Sources: dma_system.v, dma_controller.v, async_fifo.v, memory_subsystem.v, and io_subsystem.v.
3. Set dma_system as the top module under Design Sources.
4. Add tb_dma_system.v under Simulation Sources.
5. Set tb_dma_system as the simulation top module.
6. Check the $readmemh filenames in dma_system.v. They must match the actual filenames and paths. The uploaded filenames with spaces (for example, rom_array 1.hex) do not automatically match names such as rom_array_1.hex.
7. Click Run Simulation → Run Behavioral Simulation.
8. In the simulator, click Run All.
9. Check the Tcl Console/Log for the testbench's final SIMULATION PASSED or SIMULATION FAILED message.
The testbench initializes the modeled memory arrays for its tests. If you choose not to use the .hex initialization files for a simulation, make sure the INIT_FILE parameters are set accordingly. Do not assume that simulation has passed until the final result message confirms it.
7. What the Testbench Tests
The supplied testbench attempts different transfer cases, including:
- Main memory to I/O 0
- Main memory to I/O 1, 2, and 3
- I/O 0 to main memory
- I/O 1 to I/O 2
- I/O 3 to I/O 3
- Main memory to main memory
- I/O 2 to main memory
- Main memory to I/O 0 again
For each transaction, the testbench records expected data, starts the DMA, waits for the status to indicate completion, and compares the destination data with the expected values.
8. Useful Signals to View in the Waveform
Signal	What it tells you
sys_clk, io_clk	The system and I/O clocks
rst_n	Active-low reset
cpu_addr, cpu_wdata, cpu_we	CPU register writes used to configure DMA
cpu_rdata, cpu_re	CPU reads, including status polling
src_addr, src_re, src_ready, src_rdata	Source-side address, request, readiness, and data
fifo_we, fifo_re, fifo_full, fifo_empty, fifo_rdata	FIFO activity and status
dst_addr, dst_we, dst_ready, dst_wdata	Destination-side write activity and data
dma_busy_cpu, dma_done_cpu	DMA busy and completion status


A successful transfer should show the source read side supplying data, the FIFO buffering it, and the destination write side accepting the corresponding data. The final testbench message and data comparisons are the main pass/fail checks.
9. Notes and Limitations
- This repository contains RTL and a behavioral testbench; it does not include a board-specific pin constraints file.
- The design should be simulated and debugged before attempting synthesis or FPGA programming.
- Ensure the .hex file names and $readmemh paths match if initialization files are enabled.
- A waveform showing clocks and CPU register writes alone does not prove that a complete DMA transfer succeeded. Confirm the final test result and inspect the source/FIFO/destination handshake signals.
10. Tools
- Verilog HDL
- AMD/Xilinx Vivado (behavioral simulation)
Project: Mini DMA Controller with Asynchronous FIFO
Purpose: Educational study of DMA data movement, buffering, memory-mapped registers, and RTL simulation.
