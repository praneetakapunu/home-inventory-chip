// Smoke test for home_inventory_wb Wishbone register block
//
// Focus: basic read/write paths + pulse semantics + byte strobes + reset values.
//
// Run via:
//   make -C verify sim

`timescale 1ns/1ps
`default_nettype none

module wb_tb;
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

    // Clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Address map (single source-of-truth): spec/regmap_v1.yaml
    // Reuse the generated RTL include so the test can't drift.
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

    task automatic wb_write32_sel(input [31:0] adr, input [31:0] data, input [3:0] sel);
        begin
            @(negedge clk);
            wbs_adr_i = adr;
            wbs_dat_i = data;
            wbs_sel_i = sel;
            wbs_we_i  = 1'b1;
            wbs_cyc_i = 1'b1;
            wbs_stb_i = 1'b1;

            // Wait for ack
            while (wbs_ack_o !== 1'b1) begin
                @(negedge clk);
            end

            // Deassert next cycle
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

    reg [31:0] rdata;

    // Address vectors (so we can loop without hard-coding offsets twice)
    reg [31:0] adr_adc_raw [0:7];
    reg [31:0] adr_tare    [0:7];
    reg [31:0] adr_scale   [0:7];
    reg [31:0] adr_evt_cnt [0:7];

    integer ch;

    initial begin
        // Populate address arrays from generated params
        adr_adc_raw[0] = ADR_ADC_RAW_CH0;
        adr_adc_raw[1] = ADR_ADC_RAW_CH1;
        adr_adc_raw[2] = ADR_ADC_RAW_CH2;
        adr_adc_raw[3] = ADR_ADC_RAW_CH3;
        adr_adc_raw[4] = ADR_ADC_RAW_CH4;
        adr_adc_raw[5] = ADR_ADC_RAW_CH5;
        adr_adc_raw[6] = ADR_ADC_RAW_CH6;
        adr_adc_raw[7] = ADR_ADC_RAW_CH7;

        adr_tare[0] = ADR_TARE_CH0;
        adr_tare[1] = ADR_TARE_CH1;
        adr_tare[2] = ADR_TARE_CH2;
        adr_tare[3] = ADR_TARE_CH3;
        adr_tare[4] = ADR_TARE_CH4;
        adr_tare[5] = ADR_TARE_CH5;
        adr_tare[6] = ADR_TARE_CH6;
        adr_tare[7] = ADR_TARE_CH7;

        adr_scale[0] = ADR_SCALE_CH0;
        adr_scale[1] = ADR_SCALE_CH1;
        adr_scale[2] = ADR_SCALE_CH2;
        adr_scale[3] = ADR_SCALE_CH3;
        adr_scale[4] = ADR_SCALE_CH4;
        adr_scale[5] = ADR_SCALE_CH5;
        adr_scale[6] = ADR_SCALE_CH6;
        adr_scale[7] = ADR_SCALE_CH7;

        adr_evt_cnt[0] = ADR_EVT_COUNT_CH0;
        adr_evt_cnt[1] = ADR_EVT_COUNT_CH1;
        adr_evt_cnt[2] = ADR_EVT_COUNT_CH2;
        adr_evt_cnt[3] = ADR_EVT_COUNT_CH3;
        adr_evt_cnt[4] = ADR_EVT_COUNT_CH4;
        adr_evt_cnt[5] = ADR_EVT_COUNT_CH5;
        adr_evt_cnt[6] = ADR_EVT_COUNT_CH6;
        adr_evt_cnt[7] = ADR_EVT_COUNT_CH7;

        $display("[tb] start");
        wb_idle();
        core_status = 8'hA5;

        // Reset
        rst = 1'b1;
        repeat (5) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        // -----------------------------------------------------------------
        // ID/version reads
        // -----------------------------------------------------------------
        wb_read32(ADR_ID, rdata);
        if (rdata !== 32'h4849_4348) begin
            $display("[tb] ERROR: ID mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        wb_read32(ADR_VERSION, rdata);
        if (rdata !== 32'h0000_0001) begin
            $display("[tb] ERROR: VERSION mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        // STATUS readback passes through core_status
        wb_read32(ADR_STATUS, rdata);
        if (rdata[7:0] !== 8'hA5) begin
            $display("[tb] ERROR: STATUS mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        // -----------------------------------------------------------------
        // CTRL/IRQ
        // -----------------------------------------------------------------
        // CTRL.ENABLE sticky bit; CTRL.START readback must be 0.
        wb_write32(ADR_CTRL, 32'h0000_0001);
        if (ctrl_enable !== 1'b1) begin
            $display("[tb] ERROR: ctrl_enable not set");
            $fatal(1);
        end
        wb_read32(ADR_CTRL, rdata);
        if (rdata[0] !== 1'b1 || rdata[1] !== 1'b0) begin
            $display("[tb] ERROR: CTRL readback mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        // CTRL.START is a 1-cycle pulse on write-1.
        // Depending on bus timing, the pulse may occur in the cycle of the accepted write.
        // So we look for it within a small window after the write completes.
        wb_write32(ADR_CTRL, 32'h0000_0002);
        begin : start_pulse_check
            integer seen;
            integer k;
            seen = 0;
            for (k = 0; k < 4; k = k + 1) begin
                @(posedge clk);
                if (ctrl_start === 1'b1) seen = 1;
            end
            if (seen == 0) begin
                $display("[tb] ERROR: ctrl_start did not pulse");
                $fatal(1);
            end
        end
        // It must not stick high.
        @(posedge clk);
        if (ctrl_start !== 1'b0) begin
            $display("[tb] ERROR: ctrl_start did not clear");
            $fatal(1);
        end

        // IRQ_EN reserved bits must read as 0 / ignore writes.
        wb_write32(ADR_IRQ_EN, 32'hFFFF_FFFF);
        wb_read32(ADR_IRQ_EN, rdata);
        if (rdata !== 32'h0000_0007) begin
            $display("[tb] ERROR: IRQ_EN reserved-bit mask mismatch: got 0x%08x", rdata);
            $fatal(1);
        end
        if (irq_en !== 3'b111) begin
            $display("[tb] ERROR: irq_en mismatch: got %b", irq_en);
            $fatal(1);
        end

        // Partial-byte overwrite: write only low byte to 0x05.
        wb_write32_sel(ADR_IRQ_EN, 32'h0000_0005, 4'b0001);
        wb_read32(ADR_IRQ_EN, rdata);
        if (rdata !== 32'h0000_0005) begin
            $display("[tb] ERROR: IRQ_EN byte-strobe mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        // -----------------------------------------------------------------
        // ADC
        // -----------------------------------------------------------------
        wb_read32(ADR_ADC_CFG, rdata);
        if (rdata !== 32'h0000_0000) begin
            $display("[tb] ERROR: ADC_CFG reset mismatch: got 0x%08x", rdata);
            $fatal(1);
        end
        wb_write32(ADR_ADC_CFG, 32'h0000_0004); // NUM_CH=4
        wb_read32(ADR_ADC_CFG, rdata);
        if (rdata[3:0] !== 4'h4) begin
            $display("[tb] ERROR: ADC_CFG NUM_CH mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        // ADC_RAW defaults to 0 after reset (all channels).
        for (ch = 0; ch < 8; ch = ch + 1) begin
            wb_read32(adr_adc_raw[ch], rdata);
            if (rdata !== 32'h0000_0000) begin
                $display("[tb] ERROR: ADC_RAW_CH%0d reset mismatch: got 0x%08x", ch, rdata);
                $fatal(1);
            end
        end

        // ADC_CMD is write-1-to-pulse; reads must return 0.
        // (Note: in this stub implementation, writing SNAPSHOT has side effects.)
        wb_read32(ADR_ADC_CMD, rdata);
        if (rdata !== 32'h0000_0000) begin
            $display("[tb] ERROR: ADC_CMD readback mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        // SNAPSHOT should update raw regs with a deterministic stub pattern.
        // Pattern increments each snapshot so firmware can observe changing values.
        // v1 stub: CHn returns 0x0000_1000 + snapshot_count in low bits, plus channel index in [7:4].
        wb_write32(ADR_ADC_CMD, 32'h0000_0001);
        for (ch = 0; ch < 8; ch = ch + 1) begin
            wb_read32(adr_adc_raw[ch], rdata);
            if (rdata !== (32'h0000_1001 + ch)) begin
                $display("[tb] ERROR: ADC_RAW_CH%0d snapshot[1] pattern mismatch: got 0x%08x", ch, rdata);
                $fatal(1);
            end
        end

        wb_write32(ADR_ADC_CMD, 32'h0000_0001);
        for (ch = 0; ch < 8; ch = ch + 1) begin
            wb_read32(adr_adc_raw[ch], rdata);
            if (rdata !== (32'h0000_1002 + ch)) begin
                $display("[tb] ERROR: ADC_RAW_CH%0d snapshot[2] pattern mismatch: got 0x%08x", ch, rdata);
                $fatal(1);
            end
        end

        // -----------------------------------------------------------------
        // Calibration
        // -----------------------------------------------------------------
        // SCALE defaults to 1.0, TARE defaults to 0 (all channels).
        for (ch = 0; ch < 8; ch = ch + 1) begin
            wb_read32(adr_scale[ch], rdata);
            if (rdata !== 32'h0001_0000) begin
                $display("[tb] ERROR: SCALE_CH%0d reset mismatch: got 0x%08x", ch, rdata);
                $fatal(1);
            end
            wb_read32(adr_tare[ch], rdata);
            if (rdata !== 32'h0000_0000) begin
                $display("[tb] ERROR: TARE_CH%0d reset mismatch: got 0x%08x", ch, rdata);
                $fatal(1);
            end
        end

        // Byte strobes: write 0xDEADBEEF into TARE_CH0 using two half-writes
        wb_write32_sel(ADR_TARE_CH0, 32'h0000_BEEF, 4'b0011); // low 16
        wb_write32_sel(ADR_TARE_CH0, 32'hDEAD_0000, 4'b1100); // high 16
        wb_read32(ADR_TARE_CH0, rdata);
        if (rdata !== 32'hDEAD_BEEF) begin
            $display("[tb] ERROR: TARE_CH0 strobe write mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        // Byte strobes: poke only top byte of SCALE_CH1 and confirm other bytes unchanged.
        wb_write32_sel(ADR_SCALE_CH1, 32'hAB00_0000, 4'b1000);
        wb_read32(ADR_SCALE_CH1, rdata);
        if (rdata !== 32'hAB01_0000) begin
            $display("[tb] ERROR: SCALE_CH1 byte-strobe mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        // -----------------------------------------------------------------
        // RO regs must ignore writes (events are RO)
        // -----------------------------------------------------------------
        for (ch = 0; ch < 8; ch = ch + 1) begin
            wb_write32(adr_evt_cnt[ch], 32'hFFFF_FFFF);
            wb_read32(adr_evt_cnt[ch], rdata);
            if (rdata !== 32'h0000_0000) begin
                $display("[tb] ERROR: EVT_COUNT_CH%0d should ignore writes: got 0x%08x", ch, rdata);
                $fatal(1);
            end
        end

        $display("[tb] PASS");
        $finish;
    end

endmodule

`default_nettype wire
