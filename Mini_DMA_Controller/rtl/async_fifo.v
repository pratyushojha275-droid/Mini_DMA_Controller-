module async_fifo #(
    parameter DSIZE = 32,
    parameter ASIZE = 4
)(
    input  wire             wr_clk,
    input  wire             wr_rst_n,
    input  wire             wr_en,
    input  wire [DSIZE-1:0] wr_data,
    output reg              wr_full,

    input  wire             rd_clk,
    input  wire             rd_rst_n,
    input  wire             rd_en,
    output wire [DSIZE-1:0] rd_data,
    output reg              rd_empty
);

    reg [DSIZE-1:0] mem [0:(1<<ASIZE)-1];
    reg [ASIZE:0]   wq1_rptr, wq2_rptr;
    reg [ASIZE:0]   rq1_wptr, rq2_wptr;
    reg [ASIZE:0]   wbin, wptr, rbin, rptr;

    assign rd_data = mem[rbin[ASIZE-1:0]];

    always @(posedge wr_clk) begin
        if (wr_en && !wr_full) mem[wbin[ASIZE-1:0]] <= wr_data;
    end

    wire [ASIZE:0] rgraynext = (rbin + (rd_en & ~rd_empty)) ^ ((rbin + (rd_en & ~rd_empty)) >> 1);
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rbin <= 0; rptr <= 0; rd_empty <= 1;
        end else begin
            rbin <= rbin + (rd_en & ~rd_empty);
            rptr <= rgraynext;
            rd_empty <= (rgraynext == rq2_wptr);
        end
    end

    wire [ASIZE:0] wgraynext = (wbin + (wr_en & ~wr_full)) ^ ((wbin + (wr_en & ~wr_full)) >> 1);
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wbin <= 0; wptr <= 0; wr_full <= 0;
        end else begin
            wbin <= wbin + (wr_en & ~wr_full);
            wptr <= wgraynext;
            wr_full <= (wgraynext == {~wq2_rptr[ASIZE:ASIZE-1], wq2_rptr[ASIZE-2:0]});
        end
    end

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) {wq2_rptr, wq1_rptr} <= 0;
        else           {wq2_rptr, wq1_rptr} <= {wq1_rptr, rptr};
    end

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) {rq2_wptr, rq1_wptr} <= 0;
        else           {rq2_wptr, rq1_wptr} <= {rq1_wptr, wptr};
    end
endmodule
