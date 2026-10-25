module dma_controller #(
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 32,
    parameter FIFO_ADDR_BITS = 4
)(
    input  wire clk_cpu,
    input  wire clk_read,
    input  wire clk_write,
    input  wire rst_n,

    input  wire [ADDR_WIDTH-1:0] cpu_addr,
    input  wire [DATA_WIDTH-1:0] cpu_wdata,
    output reg  [DATA_WIDTH-1:0] cpu_rdata,
    input  wire                  cpu_we,
    input  wire                  cpu_re,

    output wire [ADDR_WIDTH-1:0] cfg_src,
    output wire [ADDR_WIDTH-1:0] cfg_dst,

    output wire [ADDR_WIDTH-1:0] src_addr,
    input  wire [DATA_WIDTH-1:0] src_rdata,
    output wire                  src_re,
    input  wire                  src_ready,

    output wire [ADDR_WIDTH-1:0] dst_addr,
    output wire [DATA_WIDTH-1:0] dst_wdata,
    output wire                  dst_we,
    input  wire                  dst_ready
);


    reg [ADDR_WIDTH-1:0] src_reg, dst_reg, count_reg;
    reg dma_busy_cpu;
    reg dma_done_cpu;
    reg start_tog_cpu;         

    assign cfg_src = src_reg;
    assign cfg_dst = dst_reg;

  
    reg [ADDR_WIDTH-1:0] curr_src_addr;
    reg [ADDR_WIDTH-1:0] words_to_read;
    reg                  read_active_rclk;

    
    reg [ADDR_WIDTH-1:0] curr_dst_addr;
    reg [ADDR_WIDTH-1:0] words_to_write;
    reg                  write_active_wclk;
    reg                  write_done_tog_wclk;

   
    wire fifo_full, fifo_empty;
    wire fifo_we, fifo_re;
    wire [DATA_WIDTH-1:0] fifo_rdata;

    
    reg [2:0] start_sync_rclk;
    reg [2:0] start_sync_wclk;

    always @(posedge clk_read or negedge rst_n) begin
        if (!rst_n) start_sync_rclk <= 3'b0;
        else        start_sync_rclk <= {start_sync_rclk[1:0], start_tog_cpu};
    end
    wire start_read_rclk = start_sync_rclk[1] ^ start_sync_rclk[2];

    always @(posedge clk_write or negedge rst_n) begin
        if (!rst_n) start_sync_wclk <= 3'b0;
        else        start_sync_wclk <= {start_sync_wclk[1:0], start_tog_cpu};
    end
    wire start_write_wclk = start_sync_wclk[1] ^ start_sync_wclk[2];

    reg [2:0] done_sync_cpu;
    always @(posedge clk_cpu or negedge rst_n) begin
        if (!rst_n) done_sync_cpu <= 3'b0;
        else        done_sync_cpu <= {done_sync_cpu[1:0], write_done_tog_wclk};
    end
    wire write_finished_cpu = done_sync_cpu[1] ^ done_sync_cpu[2];


    always @(posedge clk_cpu or negedge rst_n) begin
        if (!rst_n) begin
            src_reg <= 0; dst_reg <= 0; count_reg <= 0;
            dma_busy_cpu <= 0; dma_done_cpu <= 0; start_tog_cpu <= 0;
        end else begin
            if (cpu_we) begin
                case (cpu_addr[3:0])
                    4'h0: src_reg   <= cpu_wdata;
                    4'h4: dst_reg   <= cpu_wdata;
                    4'h8: count_reg <= cpu_wdata;
                    4'hC: begin
                        if (cpu_wdata[1]) dma_done_cpu <= 0;
                        if (cpu_wdata[0] && !dma_busy_cpu) begin
                            dma_busy_cpu  <= 1;
                            start_tog_cpu <= ~start_tog_cpu;
                        end
                    end
                endcase
            end

            if (write_finished_cpu) begin
                dma_busy_cpu <= 0;
                dma_done_cpu <= 1;
            end
        end
    end

    always @(*) begin
        cpu_rdata = 0;
        if (cpu_re) begin
            case (cpu_addr[3:0])
                4'h0: cpu_rdata = src_reg;
                4'h4: cpu_rdata = dst_reg;
                4'h8: cpu_rdata = count_reg;
                4'hC: cpu_rdata = {{(DATA_WIDTH-2){1'b0}}, dma_done_cpu, dma_busy_cpu};
            endcase
        end
    end

    
    assign src_re   = read_active_rclk && (words_to_read > 0) && !fifo_full;
    assign fifo_we  = src_re && src_ready;
    assign src_addr = curr_src_addr;

    always @(posedge clk_read or negedge rst_n) begin
        if (!rst_n) begin
            curr_src_addr    <= 0;
            words_to_read    <= 0;
            read_active_rclk <= 0;
        end else begin
            if (start_read_rclk) begin
                curr_src_addr    <= src_reg;
                words_to_read    <= count_reg;
                read_active_rclk <= 1;
            end

            if (fifo_we) begin
                curr_src_addr <= curr_src_addr + 4;
                words_to_read <= words_to_read - 1;
                if (words_to_read == 1) read_active_rclk <= 0;
            end
        end
    end

   
    assign dst_we    = write_active_wclk && (words_to_write > 0) && !fifo_empty;
    assign fifo_re   = dst_we && dst_ready;
    assign dst_addr  = curr_dst_addr;
    assign dst_wdata = fifo_rdata;

    always @(posedge clk_write or negedge rst_n) begin
        if (!rst_n) begin
            curr_dst_addr       <= 0;
            words_to_write      <= 0;
            write_active_wclk   <= 0;
            write_done_tog_wclk <= 0;
        end else begin
            if (start_write_wclk) begin
                curr_dst_addr  <= dst_reg;
                words_to_write <= count_reg;
                if (count_reg == 0) write_done_tog_wclk <= ~write_done_tog_wclk;
                else                write_active_wclk   <= 1;
            end

            if (fifo_re) begin
                curr_dst_addr  <= curr_dst_addr + 4;
                words_to_write <= words_to_write - 1;
                if (words_to_write == 1) begin
                    write_active_wclk   <= 0;
                    write_done_tog_wclk <= ~write_done_tog_wclk;
                end
            end
        end
    end

    async_fifo #(
        .DSIZE(DATA_WIDTH),
        .ASIZE(FIFO_ADDR_BITS)
    ) internal_fifo (
        .wr_clk(clk_read),
        .wr_rst_n(rst_n),
        .wr_en(fifo_we),
        .wr_data(src_rdata),
        .wr_full(fifo_full),

        .rd_clk(clk_write),
        .rd_rst_n(rst_n),
        .rd_en(fifo_re),
        .rd_data(fifo_rdata),
        .rd_empty(fifo_empty)
    );

endmodule