// Home Inventory Chip - top-level RTL wrapper
//
// This is the canonical top module for the IP RTL filelist (rtl/ip_home_inventory.f).
//
// Goals for v1:
// - Provide a single place to integrate the Wishbone regbank (`home_inventory_wb`)
//   and any future "core" logic.
// - Keep the top elaboratable in isolation (used by ops/rtl_compile_check.sh and
//   OpenLane configs), without requiring Caravel-specific wrapper logic.
//
// NOTE:
// - The OpenMPW harness repo provides the *Caravel user_project_wrapper*.
// - This module is the IP top (Wishbone + optional ADC pins).

`timescale 1ns/1ps

`default_nettype none

module home_inventory_top (
    // ------------------------------------------------------------------
    // Wishbone (register interface)
    // ------------------------------------------------------------------
    input  wire        wb_clk_i,
    input  wire        wb_rst_i,
    input  wire        wbs_stb_i,
    input  wire        wbs_cyc_i,
    input  wire        wbs_we_i,
    input  wire [3:0]  wbs_sel_i,
    input  wire [31:0] wbs_dat_i,
    input  wire [31:0] wbs_adr_i,
    output wire        wbs_ack_o,
    output wire [31:0] wbs_dat_o,

    // ------------------------------------------------------------------
    // Optional: core status input (can be tied off until integrated)
    // ------------------------------------------------------------------
    input  wire [7:0]  core_status,

    // ------------------------------------------------------------------
    // Debug/control surface (exported for top-level DV / bring-up)
    // ------------------------------------------------------------------
    output wire        ctrl_enable,
    output wire        ctrl_start,
    output wire [2:0]  irq_en

`ifdef USE_REAL_ADC_INGEST
    ,
    // ------------------------------------------------------------------
    // Real ADC SPI pins (only present when USE_REAL_ADC_INGEST is defined)
    // ------------------------------------------------------------------
    output wire        adc_sclk,
    output wire        adc_cs_n,
    output wire        adc_mosi,
    input  wire        adc_miso
`endif
);

    home_inventory_wb u_wb (
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
        .irq_en     (irq_en)

`ifdef USE_REAL_ADC_INGEST
        ,
        .adc_sclk(adc_sclk),
        .adc_cs_n(adc_cs_n),
        .adc_mosi(adc_mosi),
        .adc_miso(adc_miso)
`endif
    );

endmodule

`default_nettype wire
