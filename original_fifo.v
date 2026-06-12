// ============================================================
//  ORIGINAL SYNCHRONOUS FIFO — NO POWER OPTIMIZATION
//  Depth : 8 locations
//  Width : 8 bits
//  No clock gating, no output gating
//  Memory clocks EVERY cycle regardless of wr_en
// ============================================================
 
module sync_fifo_original (
    input  wire        clk,
    input  wire        rst,
    input  wire        wr_en,
    input  wire        rd_en,
    input  wire [7:0]  data_in,
    output reg  [7:0]  data_out,
    output wire        full,
    output wire        empty
);
 
parameter DEPTH  = 8;
parameter ADDR_W = 3;
 
// Memory array — clocked every single cycle (no gating)
reg [7:0] mem [0:DEPTH-1];
 
// Pointers — 4-bit (3 address + 1 MSB for full/empty)
reg [ADDR_W:0] wr_ptr;
reg [ADDR_W:0] rd_ptr;
 
integer i;
 
// ---- WRITE OPERATION ----
// Uses MAIN clock directly — no gating whatsoever
// Memory flip-flops toggle every posedge regardless
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] <= 8'b0;
        wr_ptr <= 0;
    end
    else if (wr_en && !full) begin
        mem[wr_ptr[ADDR_W-1:0]] <= data_in;
        wr_ptr <= wr_ptr + 1;
    end
end
 
// ---- READ OPERATION ----
// Output updates every cycle when rd_en — no output holding
always @(posedge clk or posedge rst) begin
    if (rst) begin
        data_out <= 8'b0;
        rd_ptr   <= 0;
    end
    else if (rd_en && !empty) begin
        data_out <= mem[rd_ptr[ADDR_W-1:0]];
        rd_ptr   <= rd_ptr + 1;
    end
    else begin
        // NO output gating — re-drives output every cycle
        // This causes unnecessary switching on the output bus
        data_out <= data_out;
    end

    end
 
// ---- FULL / EMPTY FLAGS ----
assign empty = (wr_ptr == rd_ptr);
assign full  = (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]) &&
               (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]);
 
endmodule