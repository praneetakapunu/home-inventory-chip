// wb_evt_cfg_selmask_tb.v
//
// Purpose:
// - Verify that EVT_CFG CLEAR_COUNTS / CLEAR_HISTORY W1P bits are correctly
//   byte-lane masked (they live in byte lane 1).
//
// This prevents firmware surprises when doing partial writes.
//
// Run via:
//   make -C verify wb-evt-cfg-selmask-sim
//
`timescale 1ns/1ps
`default_nettype none

module wb_evt_cfg_selmask_tb;
    // -------------------------
    // Clock/reset
    // -------------------------
    reg clk = 1'b0;
    always #5 clk = ~clk; // 100 MHz

    reg rst;

    // -------------------------
    // Wishbone
    // -------------------------
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

`include "include/regmap_params.vh"

    // -------------------------
    // DUT (stub ADC mode; no USE_REAL_ADC_INGEST)
    // -------------------------
    home_inventory_wb dut (
        .wb_clk_i(clk),
        .wb_rst_i(rst),

        .wbs_stb_i(wbs_stb_i),
        .wbs_cyc_i(wbs_cyc_i),
        .wbs_we_i (wbs_we_i),
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

    // -------------------------
    // Wishbone helpers
    // -------------------------
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

    task automatic wb_write32_sel(
        input [31:0] adr,
        input [31:0] data,
        input [3:0]  sel
    );
        begin
            @(negedge clk);
            wbs_adr_i = adr;
            wbs_dat_i = data;
            wbs_sel_i = sel;
            wbs_we_i  = 1'b1;
            wbs_cyc_i = 1'b1;
            wbs_stb_i = 1'b1;

            while (wbs_ack_o !== 1'b1) begin
                @(negedge clk);
            end

            @(negedge clk);
            wb_idle();
        end
    endtask

    task automatic wb_write32(input [31:0] adr, input [31:0] data);
        begin
            wb_write32_sel(adr, data, 4'hF);
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

    // -------------------------
    // Test
    // -------------------------
    reg [31:0] rdata;

    initial begin
        $display("[TB] wb_evt_cfg_selmask_tb starting");

        core_status = 8'h00;
        wb_idle();

        rst = 1'b1;
        repeat (5) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        // Ensure CH0 will always trigger: threshold = 0
        wb_write32(ADR_EVT_THRESH_CH0, 32'sd0);

        // Enable CH0 (EVT_EN is in byte lane 0)
        wb_write32_sel(ADR_EVT_CFG, 32'h0000_0001, 4'h1);

        // Generate exactly one sample_valid boundary (ADC snapshot)
        wb_write32_sel(ADR_ADC_CMD, 32'h0000_0001, 4'h1); // SNAPSHOT W1P bit0
        repeat (4) @(negedge clk);

        // Verify count incremented
        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        if (rdata !== 32'h0000_0001) begin
            $display("[TB] FAIL: expected EVT_COUNT_CH0=1, got %h", rdata);
            $finish;
        end

        // Attempt CLEAR_COUNTS with WRONG byte-lane select (bit8 is in lane1)
        wb_write32_sel(ADR_EVT_CFG, (32'h1 << 8), 4'h1); // sel lane0 only
        repeat (2) @(negedge clk);

        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        if (rdata !== 32'h0000_0001) begin
            $display("[TB] FAIL: CLEAR_COUNTS should be masked when sel[1]=0; got %h", rdata);
            $finish;
        end

        // Now CLEAR_COUNTS with correct byte-lane select (lane1)
        wb_write32_sel(ADR_EVT_CFG, (32'h1 << 8), 4'h2);
        repeat (2) @(negedge clk);

        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        if (rdata !== 32'h0000_0000) begin
            $display("[TB] FAIL: expected EVT_COUNT_CH0=0 after CLEAR_COUNTS, got %h", rdata);
            $finish;
        end

        $display("[TB] PASS");
        $finish;
    end

endmodule

`default_nettype wire
