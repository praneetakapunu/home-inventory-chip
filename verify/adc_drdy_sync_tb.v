// adc_drdy_sync_tb.v
//
// Minimal self-checking testbench for adc_drdy_sync.
// Ensures:
//  - reset initializes synced DRDY high (inactive)
//  - a falling edge on adc_drdy_n_async produces exactly one clk-wide pulse
//  - steady-low / steady-high does not create extra pulses
//  - no spurious pulse occurs if DRDY is held low across reset (arming logic)
//
`timescale 1ns/1ps
`default_nettype none

module adc_drdy_sync_tb;

  reg clk;
  reg rst;

  reg  adc_drdy_n_async;
  wire drdy_fall_pulse;

  // DUT
  adc_drdy_sync dut (
    .clk(clk),
    .rst(rst),
    .adc_drdy_n_async(adc_drdy_n_async),
    .drdy_fall_pulse(drdy_fall_pulse)
  );

  // 100MHz-ish clock
  initial clk = 1'b0;
  always #5 clk = ~clk;

  integer pulses;

  task expect_pulse_once;
    input [256*8-1:0] tag;
    begin
      // Observe for a handful of cycles and ensure exactly one pulse.
      integer i;
      integer local_pulses;
      local_pulses = 0;
      for (i = 0; i < 6; i = i + 1) begin
        @(posedge clk);
        if (drdy_fall_pulse) local_pulses = local_pulses + 1;
      end
      if (local_pulses !== 1) begin
        $display("FAIL(%0s): expected exactly 1 pulse, saw %0d", tag, local_pulses);
        $fatal(1);
      end else begin
        $display("OK(%0s): saw 1 pulse", tag);
      end
      pulses = pulses + local_pulses;
    end
  endtask

  task expect_no_pulse;
    input [256*8-1:0] tag;
    begin
      integer i;
      integer local_pulses;
      local_pulses = 0;
      for (i = 0; i < 6; i = i + 1) begin
        @(posedge clk);
        if (drdy_fall_pulse) local_pulses = local_pulses + 1;
      end
      if (local_pulses !== 0) begin
        $display("FAIL(%0s): expected 0 pulses, saw %0d", tag, local_pulses);
        $fatal(1);
      end else begin
        $display("OK(%0s): saw 0 pulses", tag);
      end
      pulses = pulses + local_pulses;
    end
  endtask

  initial begin
    pulses = 0;

    // ------------------------------------------------------------------
    // Case A: Normal bring-up, DRDY idles high.
    // ------------------------------------------------------------------
    rst = 1'b1;
    adc_drdy_n_async = 1'b1; // inactive high (active-low)

    repeat (3) @(posedge clk);
    rst = 1'b0;

    // Let synchronizer settle; should not pulse on steady-high.
    expect_no_pulse("steady-high after reset");

    // Create a falling edge (async) mid-cycle.
    #2 adc_drdy_n_async = 1'b0;
    expect_pulse_once("first falling edge");

    // Hold low; should not create additional pulses.
    expect_no_pulse("steady-low");

    // Rising edge: should not pulse.
    #2 adc_drdy_n_async = 1'b1;
    expect_no_pulse("rising edge");

    // Second falling edge.
    #2 adc_drdy_n_async = 1'b0;
    expect_pulse_once("second falling edge");

    // ------------------------------------------------------------------
    // Case B: DRDY held low across reset deassertion.
    // Expectation: no spurious pulse until we observe DRDY high post-reset.
    // ------------------------------------------------------------------
    rst = 1'b1;
    adc_drdy_n_async = 1'b0;
    repeat (3) @(posedge clk);
    rst = 1'b0;

    // Still low: should NOT produce a pulse (arming not satisfied).
    expect_no_pulse("held-low after reset deassert (no arm yet)");

    // Go high (arm), still no pulse.
    #2 adc_drdy_n_async = 1'b1;
    expect_no_pulse("arm on high (no pulse)");

    // Now falling edge should pulse once.
    #2 adc_drdy_n_async = 1'b0;
    expect_pulse_once("falling edge after arm");

    $display("PASS: adc_drdy_sync_tb (total pulses=%0d)", pulses);
    $finish;
  end

endmodule

`default_nettype wire
