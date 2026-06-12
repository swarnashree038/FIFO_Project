// ============================================================
//  LOW POWER SYNCHRONOUS FIFO
//  Depth : 8 locations
//  Width : 8 bits
//  Power techniques:
//    1. Clock Gating  — memory clocked ONLY when writing
//    2. Output Gating — data_out holds value unless rd_en
//    3. Sync Reset    — avoids glitch-induced power spikes
// ============================================================
 
module low_power_fifo ( input  wire        clk,
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
 
// ---- Memory Array ----
reg [7:0] mem [0:DEPTH-1];
 
// ---- Pointers (4-bit: 3 address + 1 MSB wrap flag) ----
reg [ADDR_W:0] wr_ptr;
reg [ADDR_W:0] rd_ptr;
 
// ---- Clock Gating Cell ----
// Latch is transparent when clk is LOW.
// This captures wr_en during the safe low phase,
// preventing glitches on the gated clock output.
reg  clk_en_latch;
wire gated_clk;
 
always @(*) begin
    if (!clk)
        clk_en_latch = wr_en & ~full;  // capture during low phase
end
 
// Gated clock: only pulses when a write is intended
assign gated_clk = clk & clk_en_latch;
 
// ---- WRITE OPERATION (uses gated clock) ----
integer i;
always @(posedge gated_clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] <= 8'b0;
        wr_ptr <= 0;
    end
    else begin
        // Clock only arrives here when wr_en=1 and full=0
        mem[wr_ptr[ADDR_W-1:0]] <= data_in;
        wr_ptr <= wr_ptr + 1;
    end
end
 
// ---- READ OPERATION (uses main clock) ----
// Output gating: data_out only switches when rd_en is high.
// No else clause — register holds value naturally (zero switching).
always @(posedge clk or posedge rst) begin
    if (rst) begin
        data_out <= 8'b0;
        rd_ptr   <= 0;
    end
    else if (rd_en && !empty) begin
        data_out <= mem[rd_ptr[ADDR_W-1:0]];
        rd_ptr   <= rd_ptr + 1;
    end
        // No else: data_out holds value — zero bus toggling
end
 
// ---- FULL / EMPTY FLAGS (combinational) ----
assign empty = (wr_ptr == rd_ptr);
assign full  = (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]) &&
               (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]);
 
endmodule