// Integration test: Wishbone programming of event detector + SIM sample override
//
// Purpose:
// - Prove firmware-visible reg programming (EVT_CFG/EVT_THRESH) actually drives
//   home_inventory_event_detector inside home_inventory_wb.
// - Prove the DV-only SIM override hook works (sample injection without
//   changing the regmap or adding ports).
//
// Run via:
//   make -C verify wb-evt-integration-sim

`timescale 1ns/1ps
`default_nettype none

module wb_evt_integration_tb;
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

    // Clock (100MHz-ish)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Address map: generated from spec/regmap_v1.yaml
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

    task automatic expect32(input [31:0] got, input [31:0] exp, input [1023:0] msg);
        begin
            if (got !== exp) begin
                $display("ASSERT FAIL: %0s got=0x%08x exp=0x%08x", msg, got, exp);
                $fatal(1);
            end
        end
    endtask

    // SIM override drive regs (module-scoped so iverilog allows procedural force wiring).
    reg [31:0] forced_ts;
    reg [31:0] forced_sample_ch0;
    reg        forced_sample_valid;

    task automatic sim_evt_pulse_ch0(input [31:0] sample, input [31:0] ts);
        begin
            forced_ts = ts;
            forced_sample_ch0 = sample;

            forced_sample_valid = 1'b1;
            @(posedge clk);
            #1;
            forced_sample_valid = 1'b0;
            @(posedge clk);
            #1;
        end
    endtask

    reg [31:0] rdata;

    initial begin
        $display("[wb_evt_integration_tb] start");

        wb_idle();
        core_status = 8'h00;

        // Reset
        rst = 1'b1;
        repeat (5) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        // -----------------------------------------------------------------
        // Wire up SIM overrides (forced) so we can inject deterministic samples
        // -----------------------------------------------------------------
        forced_ts = 32'h0;
        forced_sample_ch0 = 32'h0;
        forced_sample_valid = 1'b0;

        // Force the DV-only internal SIM hooks (declared in home_inventory_wb)
        // using *module-scoped* RHS regs (iverilog limitation).
        force dut.r_time_now            = forced_ts;
        force dut.sim_evt_override_en   = 1'b1;
        force dut.sim_evt_sample_ch0    = forced_sample_ch0;
        force dut.sim_evt_sample_valid  = forced_sample_valid;

        // -----------------------------------------------------------------
        // Program event threshold + enable ch0
        // -----------------------------------------------------------------
        wb_write32(ADR_EVT_THRESH_CH0, 32'd100);

        // EVT_CFG layout (see spec/regmap.md):
        // - [7:0]   EVT_EN
        // - [8]     CLEAR_COUNTS (W1P)
        // - [9]     CLEAR_HISTORY (W1P)
        wb_write32(ADR_EVT_CFG, 32'h0000_0001); // enable ch0

        // -----------------------------------------------------------------
        // Inject samples via SIM override and observe Wishbone readback
        // -----------------------------------------------------------------
        // First hit: count increments, per-ch last_ts set, last_delta is 0.
        sim_evt_pulse_ch0(32'd150, 32'd10);

        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        expect32(rdata, 32'd1, "EVT_COUNT_CH0 after first hit");

        wb_read32(ADR_EVT_LAST_TS_CH0, rdata);
        expect32(rdata, 32'd10, "EVT_LAST_TS_CH0 after first hit");

        wb_read32(ADR_EVT_LAST_DELTA_CH0, rdata);
        expect32(rdata, 32'd0, "EVT_LAST_DELTA_CH0 after first hit");

        // Miss (below threshold): no changes.
        sim_evt_pulse_ch0(32'd50, 32'd20);

        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        expect32(rdata, 32'd1, "EVT_COUNT_CH0 unchanged after miss");

        wb_read32(ADR_EVT_LAST_TS_CH0, rdata);
        expect32(rdata, 32'd10, "EVT_LAST_TS_CH0 unchanged after miss");

        // Second hit: count increments and delta updates.
        sim_evt_pulse_ch0(32'd101, 32'd25);

        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        expect32(rdata, 32'd2, "EVT_COUNT_CH0 after second hit");

        wb_read32(ADR_EVT_LAST_TS_CH0, rdata);
        expect32(rdata, 32'd25, "EVT_LAST_TS_CH0 after second hit");

        wb_read32(ADR_EVT_LAST_DELTA_CH0, rdata);
        expect32(rdata, 32'd15, "EVT_LAST_DELTA_CH0 after second hit");

        // Clear counts (W1P lives in bit[8], byte lane 1).
        wb_write32_sel(ADR_EVT_CFG, 32'h0000_0100, 4'b0010); // write bit[8]

        wb_read32(ADR_EVT_COUNT_CH0, rdata);
        expect32(rdata, 32'd0, "EVT_COUNT_CH0 after clear_counts");

        // History should remain until CLEAR_HISTORY.
        wb_read32(ADR_EVT_LAST_TS_CH0, rdata);
        expect32(rdata, 32'd25, "EVT_LAST_TS_CH0 preserved by clear_counts");

        // Clear history (bit[9])
        wb_write32_sel(ADR_EVT_CFG, 32'h0000_0200, 4'b0010);

        wb_read32(ADR_EVT_LAST_TS_CH0, rdata);
        expect32(rdata, 32'd0, "EVT_LAST_TS_CH0 after clear_history");

        wb_read32(ADR_EVT_LAST_DELTA_CH0, rdata);
        expect32(rdata, 32'd0, "EVT_LAST_DELTA_CH0 after clear_history");

        // Cleanup
        release dut.r_time_now;
        release dut.sim_evt_override_en;
        release dut.sim_evt_sample_ch0;
        release dut.sim_evt_sample_valid;

        $display("[wb_evt_integration_tb] PASS");
        $finish;
    end

endmodule

`default_nettype wire
