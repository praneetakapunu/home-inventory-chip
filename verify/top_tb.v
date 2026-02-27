// Sanity testbench for home_inventory_top.v
//
// Goal (v1): ensure the top-level skeleton elaborates cleanly and its
// placeholder outputs are stable after reset. This is intentionally minimal
// so it can run in low-disk CI.

`timescale 1ns/1ps
`default_nettype none

module top_tb;

  reg clk = 1'b0;
  reg rst = 1'b1;

  wire        adc_sck;
  wire        adc_csn;
  wire        adc_mosi;
  reg         adc_miso = 1'b0;
  wire [7:0]  status;

  // 100MHz-ish
  always #5 clk = ~clk;

  home_inventory_top dut (
    .clk      (clk),
    .rst      (rst),
    .adc_sck  (adc_sck),
    .adc_csn  (adc_csn),
    .adc_mosi (adc_mosi),
    .adc_miso (adc_miso),
    .status   (status)
  );

  task expect_eq;
    input [255:0] what;
    input [31:0]  got;
    input [31:0]  exp;
    begin
      if (got !== exp) begin
        $display("FAIL: %0s got=0x%08x exp=0x%08x", what, got, exp);
        $finish;
      end
    end
  endtask

  initial begin
    $display("[top_tb] start");

    // Hold reset for a few cycles.
    repeat (4) @(posedge clk);
    rst <= 1'b0;

    // Let signals settle.
    repeat (4) @(posedge clk);

    // Placeholder contract in rtl/home_inventory_top.v
    expect_eq("adc_sck",  {31'b0, adc_sck},  32'h0);
    expect_eq("adc_csn",  {31'b0, adc_csn},  32'h1);
    expect_eq("adc_mosi", {31'b0, adc_mosi}, 32'h0);
    expect_eq("status",   {24'b0, status},   32'h0);

    $display("PASS: home_inventory_top placeholder outputs stable");
    $finish;
  end

endmodule

`default_nettype wire
