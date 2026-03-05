// wb_adc_fifo_override_tb.v
//
// DV-only test: use SIM override wires in home_inventory_wb to push synthetic
// ADC FIFO words without using the SNAPSHOT stub.
//
// Purpose:
// - Provide a stable cocotb-friendly hook for future ADC bring-up work.
// - Prove the FIFO pop semantics, empty-read behavior, and W1C overrun clear
//   behavior work with an external word stream.
//
// Run via:
//   make -C verify wb-adc-override-sim

`timescale 1ns/1ps
`default_nettype none

module wb_adc_fifo_override_tb;
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

    // Clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

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

    reg [31:0] sim_word;

    // Push a single word into the ADC FIFO via SIM override.
    task sim_push_word(input [31:0] w);
        begin
            // Drive for one full cycle so the FIFO sees it on a posedge.
            sim_word = w;
            @(negedge clk);
            force dut.sim_adc_fifo_override_en = 1'b1;
            force dut.sim_adc_fifo_push_data  = sim_word;
            force dut.sim_adc_fifo_push_valid = 1'b1;

            @(negedge clk);
            force dut.sim_adc_fifo_push_valid = 1'b0;
        end
    endtask

    task automatic sim_disable_override;
        begin
            @(negedge clk);
            release dut.sim_adc_fifo_push_valid;
            release dut.sim_adc_fifo_push_data;
            release dut.sim_adc_fifo_override_en;
        end
    endtask

    reg [31:0] rdata;
    integer i;

    initial begin
        $display("[tb] start wb_adc_fifo_override_tb");
        wb_idle();
        core_status = 8'h00;

        rst = 1'b1;
        repeat (5) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        // Ensure FIFO empty at start.
        wb_read32(ADR_ADC_FIFO_STATUS, rdata);
        if (rdata[15:0] !== 16'd0) begin
            $display("[tb] ERROR: expected FIFO level 0 after reset, got 0x%08x", rdata);
            $fatal(1);
        end

        // Empty read must return 0 (and not underflow).
        wb_read32(ADR_ADC_FIFO_DATA, rdata);
        if (rdata !== 32'h0000_0000) begin
            $display("[tb] ERROR: expected FIFO_DATA=0 when empty, got 0x%08x", rdata);
            $fatal(1);
        end

        // Push 3 synthetic words.
        sim_push_word(32'hCAFE_0001);
        sim_push_word(32'hCAFE_0002);
        sim_push_word(32'hCAFE_0003);

        // Level should become 3.
        wb_read32(ADR_ADC_FIFO_STATUS, rdata);
        if (rdata[15:0] !== 16'd3) begin
            $display("[tb] ERROR: expected FIFO level 3 after pushes, got 0x%08x", rdata);
            $fatal(1);
        end

        // Pop and verify ordering.
        wb_read32(ADR_ADC_FIFO_DATA, rdata);
        if (rdata !== 32'hCAFE_0001) begin
            $display("[tb] ERROR: pop[0] mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        wb_read32(ADR_ADC_FIFO_DATA, rdata);
        if (rdata !== 32'hCAFE_0002) begin
            $display("[tb] ERROR: pop[1] mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        wb_read32(ADR_ADC_FIFO_DATA, rdata);
        if (rdata !== 32'hCAFE_0003) begin
            $display("[tb] ERROR: pop[2] mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        // FIFO empty again.
        wb_read32(ADR_ADC_FIFO_STATUS, rdata);
        if (rdata[15:0] !== 16'd0) begin
            $display("[tb] ERROR: expected FIFO level 0 after drain, got 0x%08x", rdata);
            $fatal(1);
        end

        // Empty read again must return 0.
        wb_read32(ADR_ADC_FIFO_DATA, rdata);
        if (rdata !== 32'h0000_0000) begin
            $display("[tb] ERROR: expected FIFO_DATA=0 when empty (post-drain), got 0x%08x", rdata);
            $fatal(1);
        end

        // -----------------------------------------------------------------
        // Overrun behavior + W1C clear semantics (byte-lane masking)
        // -----------------------------------------------------------------
        // FIFO depth in home_inventory_wb is small (localparam ADC_FIFO_DEPTH=16).
        // Push 17 words; the last should be dropped and set sticky OVERRUN.
        for (i = 0; i < 17; i = i + 1) begin
            sim_push_word(32'hBEEF_0000 + i[31:0]);
        end

        wb_read32(ADR_ADC_FIFO_STATUS, rdata);
        if (rdata[15:0] !== 16'd16) begin
            $display("[tb] ERROR: expected FIFO level 16 when full, got 0x%08x", rdata);
            $fatal(1);
        end
        if (rdata[16] !== 1'b1) begin
            $display("[tb] ERROR: expected OVERRUN sticky (bit16)=1 after overflow attempt, got 0x%08x", rdata);
            $fatal(1);
        end

        // Attempt clear with the wrong byte-lane select: should NOT clear.
        // OVERRUN lives in bit[16], which is byte lane 2 -> wbs_sel_i[2] (SEL=0x4).
        wb_write32_sel(ADR_ADC_FIFO_STATUS, 32'h0001_0000, 4'h1);
        wb_read32(ADR_ADC_FIFO_STATUS, rdata);
        if (rdata[16] !== 1'b1) begin
            $display("[tb] ERROR: OVERRUN cleared unexpectedly with wrong SEL, got 0x%08x", rdata);
            $fatal(1);
        end

        // Clear with correct select.
        wb_write32_sel(ADR_ADC_FIFO_STATUS, 32'h0001_0000, 4'h4);
        wb_read32(ADR_ADC_FIFO_STATUS, rdata);
        if (rdata[16] !== 1'b0) begin
            $display("[tb] ERROR: expected OVERRUN cleared with SEL=0x4 W1C, got 0x%08x", rdata);
            $fatal(1);
        end

        sim_disable_override();

        $display("[tb] PASS wb_adc_fifo_override_tb");
        $finish;
    end
endmodule

`default_nettype wire
