// wb_adc_snapshot_frame_tb.v
//
// Purpose: End-to-end-ish DV for the default (stub) ADC SNAPSHOT path:
//   ADC_CMD.SNAPSHOT (W1P) -> frame pack -> FIFO -> regmap pop.
//
// Acceptance we assert here:
// - Exactly 9 words are pushed per SNAPSHOT (STATUS + CH0..CH7)
// - FIFO level reports 9 then decrements to 0 after 9 pops
// - Pop order matches the streaming contract
// - Stub ramp pattern values match the documented behavior in rtl/home_inventory_wb.v
//
// Run via:
//   make -C verify wb-adc-snapshot-frame-sim

`timescale 1ns/1ps
`default_nettype none

module wb_adc_snapshot_frame_tb;
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

    // Address map (single source-of-truth): spec/regmap_v1.yaml
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

    task automatic wb_write32(input [31:0] adr, input [31:0] data);
        begin
            @(negedge clk);
            wbs_adr_i = adr;
            wbs_dat_i = data;
            wbs_sel_i = 4'hF;
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

    reg [31:0] rdata;
    reg [31:0] level;
    integer i;

    task automatic expect_eq(input [31:0] got, input [31:0] exp, input [1023:0] what);
        begin
            if (got !== exp) begin
                $display("[tb] ERROR: %0s got=0x%08x exp=0x%08x", what, got, exp);
                $fatal(1);
            end
        end
    endtask

    initial begin
        $display("[tb] start wb_adc_snapshot_frame_tb");
        wb_idle();
        core_status = 8'h00;

        // Reset
        rst = 1'b1;
        repeat (5) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        // FIFO should be empty
        wb_read32(ADR_ADC_FIFO_STATUS, rdata);
        level = {16'h0, rdata[15:0]};
        expect_eq(level, 32'd0, "FIFO level after reset");

        // Snapshot count should start at 0
        wb_read32(ADR_ADC_SNAPSHOT_COUNT, rdata);
        expect_eq(rdata, 32'd0, "ADC_SNAPSHOT_COUNT after reset");

        // Fire SNAPSHOT (W1P bit0)
        wb_write32(ADR_ADC_CMD, 32'h0000_0001);

        // Wait until FIFO level reports 9
        begin : wait_level
            for (i = 0; i < 200; i = i + 1) begin
                wb_read32(ADR_ADC_FIFO_STATUS, rdata);
                if (rdata[15:0] == 16'd9) begin
                    disable wait_level;
                end
            end
            $display("[tb] ERROR: FIFO never reached level 9 after SNAPSHOT");
            $fatal(1);
        end

        // Pop 9 words and verify order/content.
        // Stub pattern: status=0 then ch0..ch7 = 0x1000 + snapshot_count_next + ch_index
        // First snapshot after reset => snapshot_count_next=1.
        wb_read32(ADR_ADC_FIFO_DATA, rdata);
        expect_eq(rdata, 32'h0000_0000, "word0 status");

        for (i = 0; i < 8; i = i + 1) begin
            wb_read32(ADR_ADC_FIFO_DATA, rdata);
            expect_eq(rdata, 32'h0000_1000 + 32'd1 + i[31:0], "ch sample word");
        end

        // FIFO should be empty again.
        wb_read32(ADR_ADC_FIFO_STATUS, rdata);
        expect_eq({16'h0, rdata[15:0]}, 32'd0, "FIFO level after draining 9 words");

        // Snapshot count should now be 1
        wb_read32(ADR_ADC_SNAPSHOT_COUNT, rdata);
        expect_eq(rdata, 32'd1, "ADC_SNAPSHOT_COUNT after one SNAPSHOT");

        $display("[tb] PASS wb_adc_snapshot_frame_tb");
        $finish;
    end
endmodule

`default_nettype wire
