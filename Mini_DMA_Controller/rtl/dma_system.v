module dma_system #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                  sys_clk,   
    input  wire                  io_clk,    
    input  wire                  rst_n,

    input  wire [ADDR_WIDTH-1:0] cpu_addr,
    input  wire [DATA_WIDTH-1:0] cpu_wdata,
    output wire [DATA_WIDTH-1:0] cpu_rdata,
    input  wire                  cpu_we,
    input  wire                  cpu_re
);

    
    localparam MEM_BASE  = 32'h0000_2000;
    localparam MEM_WORDS = 1024;
    localparam IO0_BASE  = 32'h0000_1000;
    localparam IO1_BASE  = 32'h0000_1100;
    localparam IO2_BASE  = 32'h0000_1200;
    localparam IO3_BASE  = 32'h0000_1300;
    localparam IO_WORDS  = 64;

    function [4:0] decode(input [ADDR_WIDTH-1:0] a);
        begin
            decode[0] = (a >= MEM_BASE) && (a < MEM_BASE + MEM_WORDS*4);
            decode[1] = (a >= IO0_BASE) && (a < IO0_BASE + IO_WORDS*4);
            decode[2] = (a >= IO1_BASE) && (a < IO1_BASE + IO_WORDS*4);
            decode[3] = (a >= IO2_BASE) && (a < IO2_BASE + IO_WORDS*4);
            decode[4] = (a >= IO3_BASE) && (a < IO3_BASE + IO_WORDS*4);
        end
    endfunction

    function is_io(input [ADDR_WIDTH-1:0] a);
        reg [4:0] d;
        begin
            d     = decode(a);
            is_io = |d[4:1];
        end
    endfunction

    
    wire [ADDR_WIDTH-1:0] cfg_src, cfg_dst;

    wire [ADDR_WIDTH-1:0] src_addr;
    wire [DATA_WIDTH-1:0] src_rdata;
    wire                  src_re;
    wire                  src_ready;

    wire [ADDR_WIDTH-1:0] dst_addr;
    wire [DATA_WIDTH-1:0] dst_wdata;
    wire                  dst_we;
    wire                  dst_ready;

  
    wire clk_read  = is_io(cfg_src) ? io_clk : sys_clk;
    wire clk_write = is_io(cfg_dst) ? io_clk : sys_clk;

    dma_controller #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_ADDR_BITS(4) 
    ) dma_inst (
        .clk_cpu(sys_clk),
        .clk_read(clk_read),
        .clk_write(clk_write),
        .rst_n(rst_n),

        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata),
        .cpu_we(cpu_we),
        .cpu_re(cpu_re),

        .cfg_src(cfg_src),
        .cfg_dst(cfg_dst),

        .src_addr(src_addr),
        .src_rdata(src_rdata),
        .src_re(src_re),
        .src_ready(src_ready),

        .dst_addr(dst_addr),
        .dst_wdata(dst_wdata),
        .dst_we(dst_we),
        .dst_ready(dst_ready)
    );

   
    wire [DATA_WIDTH-1:0] mem_rdata, io0_rdata, io1_rdata, io2_rdata, io3_rdata;
    wire mem_ready, io0_ready, io1_ready, io2_ready, io3_ready;

    wire [4:0] sl_ready  = {io3_ready, io2_ready, io1_ready, io0_ready, mem_ready};
    wire [4:0] slave_clk = {io_clk, io_clk, io_clk, io_clk, sys_clk};

   
    wire [4:0] src_hit = decode(src_addr);
    wire [4:0] dst_hit = decode(dst_addr);

    wire [4:0] req_r = src_hit & {5{src_re}};
    wire [4:0] req_w = dst_hit & {5{dst_we}};

    reg  [4:0] own_r, own_w;

    wire [4:0] gnt_w = req_w & ~own_r;
    wire [4:0] gnt_r = req_r & ~own_w & (own_r | ~req_w);

    genvar g;
    generate
        for (g = 0; g < 5; g = g + 1) begin : arb
            always @(posedge slave_clk[g] or negedge rst_n) begin
                if (!rst_n) begin
                    own_r[g] <= 1'b0;
                    own_w[g] <= 1'b0;
                end else begin
                    own_r[g] <= gnt_r[g] & ~sl_ready[g];
                    own_w[g] <= gnt_w[g] & ~sl_ready[g];
                end
            end
        end
    endgenerate

    assign src_ready = |(gnt_r & sl_ready);
    assign dst_ready = |(gnt_w & sl_ready);

    assign src_rdata = ({DATA_WIDTH{src_hit[0]}} & mem_rdata) |
                       ({DATA_WIDTH{src_hit[1]}} & io0_rdata) |
                       ({DATA_WIDTH{src_hit[2]}} & io1_rdata) |
                       ({DATA_WIDTH{src_hit[3]}} & io2_rdata) |
                       ({DATA_WIDTH{src_hit[4]}} & io3_rdata);

    wire [ADDR_WIDTH-1:0] mem_addr = gnt_w[0] ? dst_addr : src_addr;
    wire [ADDR_WIDTH-1:0] io0_addr = gnt_w[1] ? dst_addr : src_addr;
    wire [ADDR_WIDTH-1:0] io1_addr = gnt_w[2] ? dst_addr : src_addr;
    wire [ADDR_WIDTH-1:0] io2_addr = gnt_w[3] ? dst_addr : src_addr;
    wire [ADDR_WIDTH-1:0] io3_addr = gnt_w[4] ? dst_addr : src_addr;

   
    memory_subsystem #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BASE_ADDR(MEM_BASE),
        .MEM_SIZE(MEM_WORDS)
    ) mem_inst (
        .clk(sys_clk),
        .rst_n(rst_n),
        .mem_addr(mem_addr),
        .mem_wdata(dst_wdata),
        .mem_rdata(mem_rdata),
        .mem_we(gnt_w[0]),
        .mem_re(gnt_r[0]),
        .mem_ready(mem_ready)
    );


    io_subsystem #(.BASE_ADDR(IO0_BASE), .INIT_FILE()) io_0 (
        .clk(io_clk), .rst_n(rst_n), .addr(io0_addr), .wdata(dst_wdata),
        .we(gnt_w[1]), .re(gnt_r[1]), .rdata(io0_rdata), .ready(io0_ready)
    );

    io_subsystem #(.BASE_ADDR(IO1_BASE), .INIT_FILE()) io_1 (
        .clk(io_clk), .rst_n(rst_n), .addr(io1_addr), .wdata(dst_wdata),
        .we(gnt_w[2]), .re(gnt_r[2]), .rdata(io1_rdata), .ready(io1_ready)
    );

    io_subsystem #(.BASE_ADDR(IO2_BASE), .INIT_FILE()) io_2 (
        .clk(io_clk), .rst_n(rst_n), .addr(io2_addr), .wdata(dst_wdata),
        .we(gnt_w[3]), .re(gnt_r[3]), .rdata(io2_rdata), .ready(io2_ready)
    );

    io_subsystem #(.BASE_ADDR(IO3_BASE), .INIT_FILE()) io_3 (
        .clk(io_clk), .rst_n(rst_n), .addr(io3_addr), .wdata(dst_wdata),
        .we(gnt_w[4]), .re(gnt_r[4]), .rdata(io3_rdata), .ready(io3_ready)
    );

endmodule

