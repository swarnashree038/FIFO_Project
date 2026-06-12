// ============================================================
//  TESTBENCH — LOW POWER SYNCHRONOUS FIFO
//  Identical test phases to the original testbench
//  for a direct apples-to-apples power comparison
// ============================================================
 
`timescale 1ns/1ps
 
module tb_low_power_fifo;
 
reg        clk, rst;
reg        wr_en, rd_en;
reg  [7:0] data_in;
wire [7:0] data_out;
wire       full, empty;
 
low_power_fifo uut (
    .clk(clk), .rst(rst), .wr_en(wr_en), .rd_en(rd_en),
    .data_in(data_in), .data_out(data_out),
    .full(full), .empty(empty)
);
 
initial clk = 0;
always #5 clk = ~clk;
 
// ---- Power counters ----
integer gated_clk_toggles;  // counts only actual write clocks
integer out_bus_toggles;
integer write_cycles;
integer total_cycles;
reg [7:0] prev_data_out;
 
always @(posedge uut.gated_clk) begin
    gated_clk_toggles = gated_clk_toggles + 1;
end
 
always @(posedge clk) begin
    total_cycles = total_cycles + 1;
    if (data_out !== prev_data_out) begin
        out_bus_toggles = out_bus_toggles + 1;
        prev_data_out = data_out;
    end
    if (wr_en && !full) write_cycles = write_cycles + 1;
end
 reg [7:0] expected [0:7];
integer   exp_idx, err_count;
 
initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_low_power_fifo);
 
    gated_clk_toggles = 0; out_bus_toggles = 0;
    write_cycles = 0; total_cycles = 0;
    err_count = 0; exp_idx = 0;
    prev_data_out = 8'b0;
 
    rst = 1; wr_en = 0; rd_en = 0; data_in = 0;
    repeat(3) @(posedge clk); #1;
    rst = 0;
 
    $display("=== LOW POWER FIFO — SIMULATION START ===");
 
    // Phase 1: Write 8 values
    $display("--- Phase 1: Writing 8 values ---");
    repeat(8) begin
        @(posedge clk); #1;
        wr_en = 1; data_in = ($random) % 256;
        expected[exp_idx] = data_in; exp_idx = exp_idx + 1;
        $display("  WRITE [%0d]: data=%3d | full=%b empty=%b",
                  exp_idx-1, data_in, full, empty);
    end
    @(posedge clk); #1; wr_en = 0;
 
    // Phase 2: Write when full
    @(posedge clk); #1; wr_en = 1; data_in = 8'hFF;
    @(posedge clk); #1; wr_en = 0;
 
    // Phase 3: Read all 8
    $display("--- Phase 3: Reading 8 values ---");
    begin : read_loop
        integer j;
        for (j = 0; j < 8; j = j + 1) begin
            @(posedge clk); #1; rd_en = 1;
            @(posedge clk); #1; rd_en = 0;
            if (data_out !== expected[j]) begin
                $display("  READ [%0d]: %3d MISMATCH (exp=%3d)",
                          j, data_out, expected[j]);
                err_count = err_count + 1;
            end else
                $display("  READ [%0d]: %3d CORRECT", j, data_out);
        end
    end
 
    // Phase 4: 20 idle cycles
    repeat(20) @(posedge clk); #1;
 
    // Phase 5: Interleaved write+read
    repeat(4) begin
        @(posedge clk); #1; wr_en = 1;
        data_in = ($random) % 256;
        @(posedge clk); #1; wr_en = 0; rd_en = 1;
        @(posedge clk); #1; rd_en = 0;
    end
 
    #20;
    $display("=== POWER REPORT — LOW POWER FIFO ===");
    $display("  Total clock cycles            : %0d", total_cycles);
    $display("  Useful write cycles           : %0d", write_cycles);
    $display("  Gated clock toggles (mem clk) : %0d", gated_clk_toggles);
    $display("  Output bus transitions        : %0d", out_bus_toggles);
    $display("  Clock pulses saved (gated)    : %0d",
              total_cycles - gated_clk_toggles);
    $display("  Clock gating efficiency       : %0d%%",
              ((total_cycles - gated_clk_toggles) * 100) / total_cycles);
    if (err_count == 0)
        $display("  CORRECTNESS: ALL READS MATCHED — PASS");
    else
        $display("  CORRECTNESS: %0d MISMATCHES — FAIL", err_count);
    $finish;
end
 
endmodule