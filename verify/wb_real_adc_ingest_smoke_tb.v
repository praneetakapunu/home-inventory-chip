// wb_real_adc_ingest_smoke_tb.v
//
// End-to-end smoke test:
// home_inventory_wb (Wishbone regmap) + adc_streaming_ingest (USE_REAL_ADC_INGEST)
//
// Purpose:
// - Prove that a CTRL.START W1P write triggers capture
// - Prove that ADC_FIFO_STATUS level updates
// - Prove that ADC_FIFO_DATA pops return expected words (lower 24 bits)
//
// Notes:
// - This test models ADS131M08-style framing only at the bit level (MISO words).
// - We do not attempt to validate exact SCLK timing beyond the CPOL/CPHA model.
//
// Run via:
//   make -C verify wb-real-adc-smoke-sim
//
`timescale 1ns/1ps
`default_nettype none

module wb_real_adc_ingest_smoke_tb;
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

    // -------------------------
    // Real ADC pins (from DUT)
    // -------------------------
    wire adc_sclk;
    wire adc_cs_n;
    wire adc_mosi;
    reg  adc_miso;

`include "include/regmap_params.vh"

    // -------------------------
    // DUT
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
        .irq_en(irq_en),

        .adc_sclk(adc_sclk),
        .adc_cs_n(adc_cs_n),
        .adc_mosi(adc_mosi),
        .adc_miso(adc_miso)
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
    // Simple SPI MISO driver (CPOL=0, CPHA=1)
    // -------------------------
    localparam int unsigned BITS_PER_WORD   = 24;
    localparam int unsigned WORDS_PER_FRAME = 10;

    reg [BITS_PER_WORD-1:0] words [0:WORDS_PER_FRAME-1];
    integer word_i;
    integer bit_i;

    initial begin
        // STATUS + CH0..CH7 + CRC
        words[0] = 24'h112233; // STATUS
        words[1] = 24'h010203;
        words[2] = 24'h111213;
        words[3] = 24'h212223;
        words[4] = 24'h313233;
        words[5] = 24'h414243;
        words[6] = 24'h515253;
        words[7] = 24'h616263;
        words[8] = 24'h717273;
        words[9] = 24'hDEADBE; // CRC (dropped by WORDS_OUT=9)
    end

    // Reset bit/word counters when a new SPI transaction begins.
    always @(negedge adc_cs_n) begin
        word_i   <= 0;
        bit_i    <= 0;
        adc_miso <= words[0][BITS_PER_WORD-1];
    end

    // Drive the next bit on each SCLK posedge while CS is asserted.
    always @(posedge adc_sclk) begin
        if (!adc_cs_n) begin
            if (word_i < WORDS_PER_FRAME) begin
                adc_miso <= words[word_i][BITS_PER_WORD-1-bit_i]; // MSB-first
            end else begin
                adc_miso <= 1'b0;
            end

            bit_i <= bit_i + 1;
            if (bit_i == BITS_PER_WORD-1) begin
                bit_i  <= 0;
                word_i <= word_i + 1;
            end
        end
    end

    // -------------------------
    // Test sequence
    // -------------------------
    reg [31:0] rdata;
    integer k;

    initial begin
        $display("[tb] start wb_real_adc_ingest_smoke_tb");

        wb_idle();
        core_status = 8'h00;
        adc_miso = 1'b0;
        word_i = 0;
        bit_i  = 0;

        rst = 1'b1;
        repeat (8) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        // Trigger capture via CTRL.START W1P (bit[1] in byte lane 0).
        wb_write32_sel(ADR_CTRL, 32'h0000_0002, 4'b0001);

        // Wait for FIFO to fill to 9 words (STATUS + CH0..CH7).
        // Also confirm CAPTURE_BUSY (bit[17]) asserted at least once during capture.
        // (Avoid 'break' so this runs on older Icarus versions.)
        k = 0;
        begin : wait_fifo
            reg got_level;
            reg saw_busy;
            got_level = 1'b0;
            saw_busy  = 1'b0;
            while (!got_level) begin
                wb_read32(ADR_ADC_FIFO_STATUS, rdata);

                if (rdata[17]) begin
                    saw_busy = 1'b1;
                end

                if (rdata[15:0] == 16'd9) begin
                    $display("[tb] FIFO level reached 9");
                    got_level = 1'b1;
                end

                k = k + 1;
                if (k > 5000) begin
                    $display("[tb] ERROR: timeout waiting for FIFO level 9 (status=0x%08x)", rdata);
                    $fatal(1);
                end
            end

            if (!saw_busy) begin
                $display("[tb] ERROR: expected CAPTURE_BUSY (bit17) to assert during capture, never saw it (last status=0x%08x)", rdata);
                $fatal(1);
            end else begin
                $display("[tb] Saw CAPTURE_BUSY assert during capture");
            end
        end

        // Pop and verify words[0..8] (CRC dropped).
        for (k = 0; k < 9; k = k + 1) begin
            wb_read32(ADR_ADC_FIFO_DATA, rdata);
            if (rdata[23:0] !== words[k]) begin
                $display("[tb] ERROR: pop[%0d] mismatch: got 0x%06x exp 0x%06x (rdata=0x%08x)",
                         k, rdata[23:0], words[k], rdata);
                $fatal(1);
            end
        end

        // After pops, FIFO must be empty.
        wb_read32(ADR_ADC_FIFO_STATUS, rdata);
        if (rdata[15:0] !== 16'd0) begin
            $display("[tb] ERROR: expected FIFO level 0 after pops, got 0x%08x", rdata);
            $fatal(1);
        end

        $display("[tb] PASS");
        $finish;
    end

endmodule

`default_nettype wire
