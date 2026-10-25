`timescale 1ns/1ps

module tb_dma_system;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    reg sys_clk;
    reg io_clk;
    reg rst_n;

    reg  [ADDR_WIDTH-1:0] cpu_addr;
    reg  [DATA_WIDTH-1:0] cpu_wdata;
    wire [DATA_WIDTH-1:0] cpu_rdata;
    reg                   cpu_we;
    reg                   cpu_re;

    reg  [DATA_WIDTH-1:0] read_val;
    reg  [DATA_WIDTH-1:0] expected [0:63];
    integer error_count  = 0;
    integer block_errors = 0;
    integer total_words  = 0;
    integer idx;
    integer i;
    integer timeout;


    dma_system #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .sys_clk(sys_clk),
        .io_clk(io_clk),
        .rst_n(rst_n),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata),
        .cpu_we(cpu_we),
        .cpu_re(cpu_re)
    );

    initial begin
        sys_clk = 0;
        forever #5 sys_clk = ~sys_clk;   
    end

    initial begin
        io_clk = 0;
        forever #12 io_clk = ~io_clk;    
    end

   
    function [DATA_WIDTH-1:0] golden(input integer n);
        begin
            golden = (n + 1) * 32'h11111111;
        end
    endfunction

    function [DATA_WIDTH-1:0] peek(input [ADDR_WIDTH-1:0] addr);
        begin
            if      (addr >= 32'h2000 && addr < 32'h3000) peek = dut.mem_inst.ram_array[(addr - 32'h2000) >> 2];
            else if (addr >= 32'h1000 && addr < 32'h1100) peek = dut.io_0.reg_array[(addr - 32'h1000) >> 2];
            else if (addr >= 32'h1100 && addr < 32'h1200) peek = dut.io_1.reg_array[(addr - 32'h1100) >> 2];
            else if (addr >= 32'h1200 && addr < 32'h1300) peek = dut.io_2.reg_array[(addr - 32'h1200) >> 2];
            else if (addr >= 32'h1300 && addr < 32'h1400) peek = dut.io_3.reg_array[(addr - 32'h1300) >> 2];
            else                                          peek = {DATA_WIDTH{1'bx}};
        end
    endfunction

    initial begin
        #1;
        for (i = 0; i < 1024; i = i + 1)
            dut.mem_inst.ram_array[i] = (i < 128) ? golden(i) : 32'h0;

        for (i = 0; i < 64; i = i + 1) begin
            dut.io_0.reg_array[i] = 32'h0;
            dut.io_1.reg_array[i] = 32'h0;
            dut.io_2.reg_array[i] = 32'h0;
            dut.io_3.reg_array[i] = 32'h0;
        end
    end

    
    task cpu_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
    begin
        @(posedge sys_clk);
        cpu_addr  <= addr;
        cpu_wdata <= data;
        cpu_we    <= 1;
        cpu_re    <= 0;
        @(posedge sys_clk);
        cpu_we    <= 0;
    end
    endtask

    task cpu_read(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data);
    begin
        @(posedge sys_clk);
        cpu_addr <= addr;
        cpu_re   <= 1;
        cpu_we   <= 0;
        @(posedge sys_clk);
        #1;
        data = cpu_rdata;
        cpu_re   <= 0;
    end
    endtask

    task run_dma_transfer(input [31:0] src, input [31:0] dst, input [31:0] count);
    begin
        cpu_write(32'h0000_0000, src);
        cpu_write(32'h0000_0004, dst);
        cpu_write(32'h0000_0008, count);
        cpu_write(32'h0000_000C, 32'h0000_0003); 

        read_val = 0;
        timeout  = 0;
        while (read_val[1] == 0 && timeout < 1000) begin
            #30;
            cpu_read(32'h0000_000C, read_val);
            timeout = timeout + 1;
        end
        if (timeout >= 1000) begin
            $display("  [TIMEOUT] DMA never signalled done");
            error_count = error_count + 1;
        end
    end
    endtask

    task print_tx_summary(input [8*10-1:0] tag, input [31:0] src, input [31:0] dst,
                          input [31:0] count, input integer errs);
    begin
        $display("[%0t] %0s: SRC = 0x%08h | DST = 0x%08h | COUNT = %0d words", $time, tag, src, dst, count);
        if (errs > 0) $display("  -> STATUS: FAILED (%0d errors)\n", errs);
        else          $display("  -> STATUS: PASSED (0 errors)\n");
    end
    endtask

    task do_tx(input [8*10-1:0] tag, input [31:0] src, input [31:0] dst, input integer count);
    begin
        for (idx = 0; idx < count; idx = idx + 1)
            expected[idx] = peek(src + (idx << 2));

        run_dma_transfer(src, dst, count);

        block_errors = 0;
        for (idx = 0; idx < count; idx = idx + 1) begin
            if ((^expected[idx] === 1'bx) || (peek(dst + (idx << 2)) !== expected[idx])) begin
                $display("  [FAIL] %0s word %0d @0x%08h = %0h (Expected %0h)",
                         tag, idx, dst + (idx << 2), peek(dst + (idx << 2)), expected[idx]);
                block_errors = block_errors + 1;
            end
        end
        error_count = error_count + block_errors;
        total_words = total_words + count;
        print_tx_summary(tag, src, dst, count, block_errors);
    end
    endtask

 
    initial begin
        rst_n     = 0;
        cpu_addr  = 0;
        cpu_wdata = 0;
        cpu_we    = 0;
        cpu_re    = 0;

        $display("[%0t] Asserting Reset...", $time);
        #30 rst_n = 1;
        $display("[%0t] Reset Released.\n", $time);
        #20;

        do_tx("MEM->IO0", 32'h2000, 32'h1000, 16);
        do_tx("MEM->IO1", 32'h2040, 32'h1100, 16);
        do_tx("MEM->IO2", 32'h2080, 32'h1200, 16);
        do_tx("MEM->IO3", 32'h20C0, 32'h1300, 16);

        do_tx("IO0->MEM", 32'h1000, 32'h2400, 16);

        do_tx("IO1->IO2", 32'h1100, 32'h1240, 16);  

        do_tx("IO3->IO3", 32'h1300, 32'h1380, 16);   

        do_tx("MEM->MEM", 32'h2000, 32'h2800, 32);

        do_tx("IO2->MEM", 32'h1200, 32'h2600, 16);
        do_tx("MEM->IO0", 32'h2600, 32'h1040, 16);   

        $display("========================================");
        if (error_count == 0)
            $display("SIMULATION PASSED: all %0d data words matched across all transactions.", total_words);
        else
            $display("SIMULATION FAILED: %0d total mismatches/errors found.", error_count);
        $display("========================================");

        #100;
        $finish;
    end

    initial begin
        $dumpfile("dma_async_tb.vcd");
        $dumpvars(0, tb_dma_system);
    end

endmodule