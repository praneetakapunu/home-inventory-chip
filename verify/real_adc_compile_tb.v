// real_adc_compile_tb.v
//
// Compile-only smoke test for the top-level with USE_REAL_ADC_INGEST enabled.
//
// Goal: ensure the RTL elaborates when the real ADC ingest path is selected,
// without requiring any ADC stimulus or full DV.

`timescale 1ns/1ps
`default_nettype none

module real_adc_compile_tb;
    reg         wb_clk_i = 1'b0;
    reg         wb_rst_i = 1'b1;
    reg         wbs_stb_i = 1'b0;
    reg         wbs_cyc_i = 1'b0;
    reg         wbs_we_i  = 1'b0;
    reg  [3:0]  wbs_sel_i = 4'h0;
    reg  [31:0] wbs_dat_i = 32'h0;
    reg  [31:0] wbs_adr_i = 32'h0;
    wire        wbs_ack_o;
    wire [31:0] wbs_dat_o;

    reg  [7:0]  core_status = 8'h00;

    wire        ctrl_enable;
    wire        ctrl_start;
    wire [2:0]  irq_en;

    wire        adc_sclk;
    wire        adc_cs_n;
    wire        adc_mosi;
    wire        adc_miso = 1'b0;

    // simple clock
    always #5 wb_clk_i = ~wb_clk_i;

    initial begin
        // bring reset low after a few cycles
        #50;
        wb_rst_i = 1'b0;
        #50;
        $finish;
    end

    home_inventory_top dut (
        .wb_clk_i(wb_clk_i),
        .wb_rst_i(wb_rst_i),
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
        .ctrl_start (ctrl_start),
        .irq_en     (irq_en),

        .adc_sclk(adc_sclk),
        .adc_cs_n(adc_cs_n),
        .adc_mosi(adc_mosi),
        .adc_miso(adc_miso)
    );

endmodule

`default_nettype wire
