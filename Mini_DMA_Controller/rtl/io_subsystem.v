module io_subsystem #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BASE_ADDR  = 32'h0000_1000,
    parameter MEM_SIZE   = 64,
    parameter INIT_FILE  = "default_io.hex"
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire [DATA_WIDTH-1:0] wdata,
    input  wire                  we,
    input  wire                  re,
    output reg  [DATA_WIDTH-1:0] rdata,
    output reg                   ready
);

    reg [DATA_WIDTH-1:0] reg_array [0:MEM_SIZE-1];
    wire [ADDR_WIDTH-1:0] word_idx = (addr - BASE_ADDR) >> 2;
    wire valid_addr = (addr >= BASE_ADDR) && (addr < BASE_ADDR + (MEM_SIZE * 4));

    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, reg_array);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 0;
            rdata <= 0;
        end else begin
            ready <= 0;
            if (valid_addr && !ready) begin
                if (we) begin
                    reg_array[word_idx] <= wdata;
                    ready <= 1;
                end else if (re) begin
                    rdata <= reg_array[word_idx];
                    ready <= 1;
                end
            end
        end
    end
endmodule
