// Sanity testbench for rtl/home_inventory_top.v
//
// Goal (v1): ensure the IP top elaborates cleanly and its basic outputs are
// well-defined after reset.
//
// Note: this test intentionally does *not* depend on the Caravel harness.

`timescale 1ns/1ps
`default_nettype none

module top_tb;

  reg wb_clk_i = 1'b0;
  reg wb_rst_i = 1'b1;

  // Wishbone signals (tied off; this is an elaboration/defined-outputs test)
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

  // 100MHz-ish
  always #5 wb_clk_i = ~wb_clk_i;

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
    .irq_en     (irq_en)
  );

  task expect_eq1;
    input [255:0] what;
    input         got;
    input         exp;
    begin
      if (got !== exp) begin
        $display("FAIL: %0s got=%0d exp=%0d", what, got, exp);
        $finish;
      end
    end
  endtask

  initial begin
    $display("[top_tb] start");

    // Hold reset for a few cycles.
    repeat (4) @(posedge wb_clk_i);
    wb_rst_i <= 1'b0;

    // Let signals settle.
    repeat (4) @(posedge wb_clk_i);

    // With Wishbone idle, these should be well-defined (and typically 0).
    expect_eq1("ctrl_enable", ctrl_enable, 1'b0);
    expect_eq1("ctrl_start",  ctrl_start,  1'b0);

    // Don't over-specify irq_en reset value beyond "known"; but for v1 we
    // expect it to reset low.
    if (irq_en !== 3'b000) begin
      $display("FAIL: irq_en not reset-low (got=%b)", irq_en);
      $finish;
    end

    // Wishbone should not ack when idle.
    expect_eq1("wbs_ack_o", wbs_ack_o, 1'b0);

    $display("PASS: home_inventory_top elaborates and outputs are defined");
    $finish;
  end

endmodule

`default_nettype wire
