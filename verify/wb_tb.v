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

    // Event-test helpers
    reg [31:0] base_sc;
    reg [31:0] ts1;
    reg [31:0] ts2;
    reg [31:0] ts3;

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

        // TIME_NOW should be a free-running counter.
        wb_read32(ADR_TIME_NOW, ts1);
        repeat (3) @(negedge clk);
        wb_read32(ADR_TIME_NOW, ts2);
        if (ts2 <= ts1) begin
            $display("[tb] ERROR: TIME_NOW did not increment: t0=%0d t1=%0d", ts1, ts2);
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

        // FIFO behavior: each SNAPSHOT pushes 9 words: status(0) then CH0..CH7.
        // FIFO depth is 16, so after 2 snapshots without draining:
        // - FIFO is full
        // - Overrun sticky flag is set (2 words dropped)
        //
        // IMPORTANT: do not assume the FIFO reaches its final level in the same
        // cycle as the SNAPSHOT pulse. Today the stub implementation populates
        // immediately, but the real ADC path will likely include a push sequencer.
        // Therefore we poll for the expected steady-state (bounded wait).
        begin : fifo_fill_wait
            integer tries;
            for (tries = 0; tries < 50; tries = tries + 1) begin
                wb_read32(ADR_ADC_FIFO_STATUS, rdata);
                if (rdata[15:0] === 16'd16 && rdata[16] === 1'b1) begin
                    disable fifo_fill_wait;
                end
            end
            $display("[tb] ERROR: ADC_FIFO_STATUS did not reach full+overrun after 2 snapshots: got 0x%08x", rdata);
            $fatal(1);
        end

        // Drain FIFO and verify word ordering:
        // snapshot[1]: status + 8 channels
        // snapshot[2]: only status + CH0..CH5 fit before overrun
        begin : fifo_drain_check
            integer idx;
            reg [31:0] exp;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                wb_read32(ADR_ADC_FIFO_DATA, rdata);

                // Expected sequence
                exp = 32'hDEAD_DEAD;
                if (idx == 0) exp = 32'h0000_0000;              // s1 status
                else if (idx >= 1 && idx <= 8) exp = 32'h0000_1001 + (idx-1); // s1 CH0..CH7
                else if (idx == 9) exp = 32'h0000_0000;         // s2 status
                else if (idx >= 10 && idx <= 15) exp = 32'h0000_1002 + (idx-10); // s2 CH0..CH5

                if (rdata !== exp) begin
                    $display("[tb] ERROR: FIFO_DATA[%0d] mismatch: got 0x%08x exp 0x%08x", idx, rdata, exp);
                    $fatal(1);
                end

                // Level must decrement after each pop
                wb_read32(ADR_ADC_FIFO_STATUS, rdata);
                if (rdata[15:0] !== (16'd15 - idx)) begin
                    $display("[tb] ERROR: FIFO level did not decrement at idx=%0d: got 0x%08x", idx, rdata);
                    $fatal(1);
                end
            end
        end

        // Overrun is sticky until W1C bit[16] (byte lane 2).
        wb_read32(ADR_ADC_FIFO_STATUS, rdata);
        if (rdata[16] !== 1'b1) begin
            $display("[tb] ERROR: FIFO overrun should still be set after drain: got 0x%08x", rdata);
            $fatal(1);
        end
        wb_write32_sel(ADR_ADC_FIFO_STATUS, 32'h0001_0000, 4'b0100);
        wb_read32(ADR_ADC_FIFO_STATUS, rdata);
        if (rdata[16] !== 1'b0) begin
            $display("[tb] ERROR: FIFO overrun W1C failed: got 0x%08x", rdata);
            $fatal(1);
        end

        // Empty FIFO reads must return 0 and not alter state.
        wb_read32(ADR_ADC_FIFO_STATUS, rdata);
        if (rdata[15:0] !== 16'd0) begin
            $display("[tb] ERROR: FIFO level expected 0 after full drain: got 0x%08x", rdata);
            $fatal(1);
        end
        wb_read32(ADR_ADC_FIFO_DATA, rdata);
        if (rdata !== 32'h0000_0000) begin
            $display("[tb] ERROR: FIFO empty read should return 0: got 0x%08x", rdata);
            $fatal(1);
        end
        wb_read32(ADR_ADC_FIFO_STATUS, rdata);
        if (rdata[15:0] !== 16'd0) begin
            $display("[tb] ERROR: FIFO level changed after empty read: got 0x%08x", rdata);
            $fatal(1);
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
        // Events: config path + counter/timestamp behavior via ADC snapshot stub
        // -----------------------------------------------------------------
        // Program a low threshold so each snapshot "hits".
        wb_write32(ADR_EVT_THRESH_CH0, 32'h0000_0000);

        // Enable only CH0.
        wb_write32(ADR_EVT_CFG, 32'h0000_0001);
        wb_read32(ADR_EVT_CFG, rdata);
        if (rdata[7:0] !== 8'h01) begin
            $display("[tb] ERROR: EVT_CFG readback mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        // Take a reference TIME_NOW so timestamp expectations stay stable
        // even if earlier parts of this test took extra cycles.
        wb_read32(ADR_TIME_NOW, base_sc);

        // First snapshot after enable: count increments, delta must be 0, timestamps update.
        wb_write32(ADR_ADC_CMD, 32'h0000_0001);
        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        if (rdata !== 32'd1) begin
            $display("[tb] ERROR: EVT_COUNT_CH0 after first snapshot: got 0x%08x", rdata);
            $fatal(1);
        end
        wb_read32(ADR_EVT_LAST_DELTA_CH0, rdata);
        if (rdata !== 32'd0) begin
            $display("[tb] ERROR: EVT_LAST_DELTA_CH0 after first snapshot should be 0: got 0x%08x", rdata);
            $fatal(1);
        end
        wb_read32(ADR_EVT_LAST_TS_CH0, ts1);
        if (ts1 < base_sc) begin
            $display("[tb] ERROR: EVT_LAST_TS_CH0 moved backwards: got 0x%08x base 0x%08x", ts1, base_sc);
            $fatal(1);
        end
        wb_read32(ADR_EVT_LAST_TS, rdata);
        if (rdata !== ts1) begin
            $display("[tb] ERROR: EVT_LAST_TS after first snapshot: got 0x%08x exp 0x%08x", rdata, ts1);
            $fatal(1);
        end

        // Second snapshot: delta should match the TIME_NOW difference.
        wb_read32(ADR_TIME_NOW, base_sc);
        wb_write32(ADR_ADC_CMD, 32'h0000_0001);
        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        if (rdata !== 32'd2) begin
            $display("[tb] ERROR: EVT_COUNT_CH0 after second snapshot: got 0x%08x", rdata);
            $fatal(1);
        end
        wb_read32(ADR_EVT_LAST_TS_CH0, ts2);
        if (ts2 <= ts1) begin
            $display("[tb] ERROR: EVT_LAST_TS_CH0 not monotonic: ts1=0x%08x ts2=0x%08x", ts1, ts2);
            $fatal(1);
        end
        if (ts2 < base_sc) begin
            $display("[tb] ERROR: EVT_LAST_TS_CH0 before snapshot base: ts2=0x%08x base=0x%08x", ts2, base_sc);
            $fatal(1);
        end
        wb_read32(ADR_EVT_LAST_DELTA_CH0, rdata);
        if (rdata == 32'd0) begin
            $display("[tb] ERROR: EVT_LAST_DELTA_CH0 after second snapshot should be >0: got 0x%08x", rdata);
            $fatal(1);
        end
        if (rdata !== (ts2 - ts1)) begin
            $display("[tb] ERROR: EVT_LAST_DELTA_CH0 mismatch: got 0x%08x exp 0x%08x", rdata, (ts2 - ts1));
            $fatal(1);
        end

        // Disable then re-enable: next event should reset delta to 0 again.
        wb_write32(ADR_EVT_CFG, 32'h0000_0000);
        wb_write32(ADR_EVT_CFG,  32'h0000_0001);
        wb_write32(ADR_ADC_CMD,  32'h0000_0001);
        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        if (rdata !== 32'd3) begin
            $display("[tb] ERROR: EVT_COUNT_CH0 after re-enable snapshot: got 0x%08x", rdata);
            $fatal(1);
        end
        wb_read32(ADR_EVT_LAST_DELTA_CH0, rdata);
        if (rdata !== 32'd0) begin
            $display("[tb] ERROR: EVT_LAST_DELTA_CH0 after re-enable should be 0: got 0x%08x", rdata);
            $fatal(1);
        end
        wb_read32(ADR_EVT_LAST_TS_CH0, ts3);
        if (ts3 <= ts2) begin
            $display("[tb] ERROR: EVT_LAST_TS_CH0 after re-enable not monotonic: ts2=0x%08x ts3=0x%08x", ts2, ts3);
            $fatal(1);
        end

        // -----------------------------------------------------------------
        // EVT_CFG clear controls (byte-lane masked W1P)
        // -----------------------------------------------------------------
        // Clear counts without disturbing enable bits: touch only byte lane 1.
        wb_write32_sel(ADR_EVT_CFG, 32'h0000_0100, 4'b0010); // CLEAR_COUNTS
        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        if (rdata !== 32'd0) begin
            $display("[tb] ERROR: CLEAR_COUNTS did not clear EVT_COUNT_CH0: got 0x%08x", rdata);
            $fatal(1);
        end

        // Snapshot should increment from 0 again (still enabled).
        wb_write32(ADR_ADC_CMD, 32'h0000_0001);
        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        if (rdata !== 32'd1) begin
            $display("[tb] ERROR: EVT_COUNT_CH0 after CLEAR_COUNTS + snapshot: got 0x%08x", rdata);
            $fatal(1);
        end

        // Clear history (timestamps + deltas) without disturbing enable bits.
        wb_write32_sel(ADR_EVT_CFG, 32'h0000_0200, 4'b0010); // CLEAR_HISTORY
        wb_read32(ADR_EVT_LAST_TS, rdata);
        if (rdata !== 32'd0) begin
            $display("[tb] ERROR: CLEAR_HISTORY did not clear EVT_LAST_TS: got 0x%08x", rdata);
            $fatal(1);
        end
        wb_read32(ADR_EVT_LAST_TS_CH0, rdata);
        if (rdata !== 32'd0) begin
            $display("[tb] ERROR: CLEAR_HISTORY did not clear EVT_LAST_TS_CH0: got 0x%08x", rdata);
            $fatal(1);
        end
        wb_read32(ADR_EVT_LAST_DELTA_CH0, rdata);
        if (rdata !== 32'd0) begin
            $display("[tb] ERROR: CLEAR_HISTORY did not clear EVT_LAST_DELTA_CH0: got 0x%08x", rdata);
            $fatal(1);
        end

        // Next snapshot should behave like first event again (delta = 0).
        wb_write32(ADR_ADC_CMD, 32'h0000_0001);
        wb_read32(ADR_EVT_LAST_DELTA_CH0, rdata);
        if (rdata !== 32'd0) begin
            $display("[tb] ERROR: EVT_LAST_DELTA_CH0 after CLEAR_HISTORY should be 0: got 0x%08x", rdata);
            $fatal(1);
        end

`ifdef SIM
        // -----------------------------------------------------------------
        // Events: SIM override smoke
        // -----------------------------------------------------------------
        // Purpose: prove the DV-only override path works so future wiring can
        // switch the event detector to real ADC frames without breaking tests.
        //
        // We force the internal SIM wires (declared in home_inventory_wb under
        // `ifdef SIM) to inject a known sample stream.

        // Clean slate.
        wb_write32_sel(ADR_EVT_CFG, 32'h0000_0100, 4'b0010); // CLEAR_COUNTS
        wb_write32_sel(ADR_EVT_CFG, 32'h0000_0200, 4'b0010); // CLEAR_HISTORY

        // Enable only CH0 and set threshold to 100.
        wb_write32(ADR_EVT_THRESH_CH0, 32'd100);
        wb_write32(ADR_EVT_CFG, 32'h0000_0001);

        // Turn on override + drive all channels.
        force dut.sim_evt_override_en = 1'b1;
        force dut.sim_evt_sample_ch0  = 32'd50;
        force dut.sim_evt_sample_ch1  = 32'd0;
        force dut.sim_evt_sample_ch2  = 32'd0;
        force dut.sim_evt_sample_ch3  = 32'd0;
        force dut.sim_evt_sample_ch4  = 32'd0;
        force dut.sim_evt_sample_ch5  = 32'd0;
        force dut.sim_evt_sample_ch6  = 32'd0;
        force dut.sim_evt_sample_ch7  = 32'd0;

        // Below threshold: no event.
        @(negedge clk); force dut.sim_evt_sample_valid = 1'b1;
        @(negedge clk); force dut.sim_evt_sample_valid = 1'b0;
        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        if (rdata !== 32'd0) begin
            $display("[tb] ERROR: SIM override below-threshold should not increment: got 0x%08x", rdata);
            $fatal(1);
        end

        // Above threshold: event increments.
        force dut.sim_evt_sample_ch0 = 32'd150;
        @(negedge clk); force dut.sim_evt_sample_valid = 1'b1;
        @(negedge clk); force dut.sim_evt_sample_valid = 1'b0;
        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        if (rdata !== 32'd1) begin
            $display("[tb] ERROR: SIM override above-threshold should increment to 1: got 0x%08x", rdata);
            $fatal(1);
        end

        // Release forced wires so the rest of the TB is not affected.
        release dut.sim_evt_sample_valid;
        release dut.sim_evt_override_en;
        release dut.sim_evt_sample_ch0;
        release dut.sim_evt_sample_ch1;
        release dut.sim_evt_sample_ch2;
        release dut.sim_evt_sample_ch3;
        release dut.sim_evt_sample_ch4;
        release dut.sim_evt_sample_ch5;
        release dut.sim_evt_sample_ch6;
        release dut.sim_evt_sample_ch7;
`endif

        // -----------------------------------------------------------------
        // RO regs must ignore writes (events are RO)
        // -----------------------------------------------------------------
        for (ch = 0; ch < 8; ch = ch + 1) begin
            wb_write32(adr_evt_cnt[ch], 32'hFFFF_FFFF);
            wb_read32(adr_evt_cnt[ch], rdata);
            if (rdata !== 32'h0000_0000 && ch != 0) begin
                $display("[tb] ERROR: EVT_COUNT_CH%0d should ignore writes: got 0x%08x", ch, rdata);
                $fatal(1);
            end
        end
        // CH0 already incremented above; confirm write still didn't clobber it.
        // Note: if SIM override smoke ran, we intentionally cleared counts and
        // re-incremented to 1.
        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        if (rdata !== 32'd1) begin
            $display("[tb] ERROR: EVT_COUNT_CH0 should ignore writes (preserve count=1): got 0x%08x", rdata);
            $fatal(1);
        end

        $display("[tb] PASS");
        $finish;
    end

endmodule

`default_nettype wire
