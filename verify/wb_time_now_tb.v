// Smoke test: TIME_NOW free-running counter semantics
//
// Verifies:
//  - TIME_NOW increases over time after reset deassert
//  - TIME_NOW returns close to 0 after reset is asserted again
//
// Run via:
//   make -C verify wb-time-now-sim

`timescale 1ns/1ps
`default_nettype none

module wb_time_now_tb;
    reg         clk;
    reg         rst;

    reg         wbs_stb_i;
    reg         wbs_cyc_i;
    reg         wbs_we_i;
    reg  [3:0]  wbs_sel_i;
    reg  [31:0] wbs_dat_i;
    reg  [31:0] wbs_adr_i;
    wire        wbs_ack_o;
    wire [31:0] wbs_dat_o;

    reg  [7:0]  core_status;
    wire        ctrl_enable;
    wire        ctrl_start;
    wire [2:0]  irq_en;

    // DUT
    home_inventory_wb dut (
        .wb_clk_i(clk),
        .wb_rst_i(rst),
        .wbs_stb_i(wbs_stb_i),
        .wbs_cyc_i(wbs_cyc_i),
        .wbs_we_i(wbs_we_i),
        .wbs_sel_i(wbs_sel_i),
        .wbs_dat_i(wbs_dat_i),
        .wbs_adr_i(wbs_adr_i),
        .wbs_ack_o(wbs_ack_o),
        .wbs_dat_o(wbs_dat_o),
        .core_status(core_status),
        .ctrl_enable(ctrl_enable),
        .ctrl_start(ctrl_start),
        .irq_en(irq_en)
    );

    // Clock: 100 MHz equivalent (10 ns period)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Address map (single source-of-truth)
`include "include/regmap_params.vh"

    task automatic wb_idle;
        begin
            wbs_stb_i = 1'b0;
            wbs_cyc_i = 1'b0;
            wbs_we_i  = 1'b0;
            wbs_sel_i = 4'h0;
            wbs_dat_i = 32'h0;
            wbs_adr_i = 32'h0;
        end
    endtask

    task automatic wb_read32(input [31:0] adr, output [31:0] data);
        begin
            @(negedge clk);
            wbs_adr_i = adr;
            wbs_sel_i = 4'hF;
            wbs_we_i  = 1'b0;
            wbs_cyc_i = 1'b1;
            wbs_stb_i = 1'b1;

            while (wbs_ack_o !== 1'b1) begin
                @(negedge clk);
            end

            data = wbs_dat_o;

            @(negedge clk);
            wb_idle();
        end
    endtask

    reg [31:0] t1;
    reg [31:0] t2;
    reg [31:0] t3;

    initial begin
        wb_idle();
        core_status = 8'h00;

        // Reset
        rst = 1'b1;
        repeat (5) @(posedge clk);
        rst = 1'b0;

        // Give it a couple cycles to start counting
        repeat (2) @(posedge clk);

        wb_read32(ADR_TIME_NOW, t1);

        // Wait some time, then read again
        repeat (25) @(posedge clk);
        wb_read32(ADR_TIME_NOW, t2);

        if (t2 <= t1) begin
            $display("FAIL: TIME_NOW did not increase (t1=%0d t2=%0d)", t1, t2);
            $fatal;
        end

        // Re-assert reset and make sure TIME_NOW returns near 0
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (1) @(posedge clk);

        wb_read32(ADR_TIME_NOW, t3);

        // Allow a small nonzero due to read timing; it should be tiny.
        if (t3 > 32'd5) begin
            $display("FAIL: TIME_NOW not reset-close-to-zero (t3=%0d)", t3);
            $fatal;
        end

        $display("PASS: TIME_NOW increments and resets correctly (t1=%0d t2=%0d t3=%0d)", t1, t2, t3);
        $finish;
    end

endmodule

`default_nettype wire
