module memory_subsystem #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BASE_ADDR  = 32'h0000_2000,
    parameter MEM_SIZE   = 1024
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [ADDR_WIDTH-1:0] mem_addr,
    input  wire [DATA_WIDTH-1:0] mem_wdata,
    output reg  [DATA_WIDTH-1:0] mem_rdata,
    input  wire                  mem_we,
    input  wire                  mem_re,
    output reg                   mem_ready
);
    reg [DATA_WIDTH-1:0] ram_array [0:MEM_SIZE-1];
    wire valid_addr = (mem_addr >= BASE_ADDR) && (mem_addr < BASE_ADDR + (MEM_SIZE * 4));
    wire [ADDR_WIDTH-1:0] word_idx = (mem_addr - BASE_ADDR) >> 2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 0;
            mem_rdata <= 0;
        end else begin
            mem_ready <= 0;
            if (valid_addr) begin
                if (mem_we && !mem_ready) begin
                    ram_array[word_idx] <= mem_wdata;
                    mem_ready <= 1;
                end
                else if (mem_re && !mem_ready) begin
                    mem_rdata <= ram_array[word_idx];
                    mem_ready <= 1;
                end
            end
        end
    end
endmodule
