// Smoke test for home_inventory_event_detector
//
// Runs in iverilog/vvp.

`timescale 1ns/1ps
`default_nettype none

module event_detector_tb;

  reg clk;
  reg rst;

  reg        sample_valid;
  reg [31:0] ts_now;
  reg [7:0]  evt_en;

  reg [31:0] thresh_ch0, thresh_ch1, thresh_ch2, thresh_ch3;
  reg [31:0] thresh_ch4, thresh_ch5, thresh_ch6, thresh_ch7;

  reg [31:0] sample_ch0, sample_ch1, sample_ch2, sample_ch3;
  reg [31:0] sample_ch4, sample_ch5, sample_ch6, sample_ch7;

  wire [31:0] evt_count_ch0, evt_count_ch1, evt_count_ch2, evt_count_ch3;
  wire [31:0] evt_count_ch4, evt_count_ch5, evt_count_ch6, evt_count_ch7;

  wire [31:0] last_delta_ch0, last_delta_ch1, last_delta_ch2, last_delta_ch3;
  wire [31:0] last_delta_ch4, last_delta_ch5, last_delta_ch6, last_delta_ch7;

  wire [31:0] last_ts;

  wire [31:0] last_ts_ch0, last_ts_ch1, last_ts_ch2, last_ts_ch3;
  wire [31:0] last_ts_ch4, last_ts_ch5, last_ts_ch6, last_ts_ch7;

  home_inventory_event_detector dut (
    .clk(clk),
    .rst(rst),

    .sample_valid(sample_valid),
    .ts_now(ts_now),

    .evt_en(evt_en),

    .thresh_ch0(thresh_ch0), .thresh_ch1(thresh_ch1), .thresh_ch2(thresh_ch2), .thresh_ch3(thresh_ch3),
    .thresh_ch4(thresh_ch4), .thresh_ch5(thresh_ch5), .thresh_ch6(thresh_ch6), .thresh_ch7(thresh_ch7),

    .sample_ch0(sample_ch0), .sample_ch1(sample_ch1), .sample_ch2(sample_ch2), .sample_ch3(sample_ch3),
    .sample_ch4(sample_ch4), .sample_ch5(sample_ch5), .sample_ch6(sample_ch6), .sample_ch7(sample_ch7),

    .evt_count_ch0(evt_count_ch0), .evt_count_ch1(evt_count_ch1), .evt_count_ch2(evt_count_ch2), .evt_count_ch3(evt_count_ch3),
    .evt_count_ch4(evt_count_ch4), .evt_count_ch5(evt_count_ch5), .evt_count_ch6(evt_count_ch6), .evt_count_ch7(evt_count_ch7),

    .last_delta_ch0(last_delta_ch0), .last_delta_ch1(last_delta_ch1), .last_delta_ch2(last_delta_ch2), .last_delta_ch3(last_delta_ch3),
    .last_delta_ch4(last_delta_ch4), .last_delta_ch5(last_delta_ch5), .last_delta_ch6(last_delta_ch6), .last_delta_ch7(last_delta_ch7),

    .last_ts(last_ts),

    .last_ts_ch0(last_ts_ch0), .last_ts_ch1(last_ts_ch1), .last_ts_ch2(last_ts_ch2), .last_ts_ch3(last_ts_ch3),
    .last_ts_ch4(last_ts_ch4), .last_ts_ch5(last_ts_ch5), .last_ts_ch6(last_ts_ch6), .last_ts_ch7(last_ts_ch7)
  );

  // 100MHz-ish
  initial clk = 1'b0;
  always #5 clk = ~clk;

  task tick;
    begin
      @(posedge clk);
      #1;
    end
  endtask

  task expect32(input [31:0] got, input [31:0] exp, input [1023:0] msg);
    begin
      if (got !== exp) begin
        $display("ASSERT FAIL: %0s got=0x%08x exp=0x%08x", msg, got, exp);
        $fatal(1);
      end
    end
  endtask

  initial begin
    // Defaults
    rst = 1'b1;
    sample_valid = 1'b0;
    ts_now = 32'h0;
    evt_en = 8'h00;

    thresh_ch0 = 32'd100; thresh_ch1 = 32'd0;   thresh_ch2 = 32'd0;   thresh_ch3 = 32'd0;
    thresh_ch4 = 32'd0;   thresh_ch5 = 32'd0;   thresh_ch6 = 32'd0;   thresh_ch7 = 32'd0;

    sample_ch0 = 32'd0; sample_ch1 = 32'd0; sample_ch2 = 32'd0; sample_ch3 = 32'd0;
    sample_ch4 = 32'd0; sample_ch5 = 32'd0; sample_ch6 = 32'd0; sample_ch7 = 32'd0;

    // Hold reset for a few cycles
    tick();
    tick();
    tick();
    rst = 1'b0;
    tick();

    // After reset, counters should be 0
    expect32(evt_count_ch0, 32'd0, "count ch0 after reset");
    expect32(last_ts,       32'd0, "last_ts after reset");
    expect32(last_delta_ch0,32'd0, "last_delta ch0 after reset");

    // Enable ch0 (rising edge). No sample yet.
    evt_en = 8'b0000_0001;
    tick();

    // First event after enable should report last_delta=0
    ts_now = 32'd10;
    sample_ch0 = 32'd150; // hit
    sample_valid = 1'b1;
    tick();
    sample_valid = 1'b0;

    expect32(evt_count_ch0, 32'd1, "count ch0 after first hit");
    expect32(last_ts,       32'd10, "last_ts updates on any event");
    expect32(last_ts_ch0,   32'd10, "last_ts_ch0 after first hit");
    expect32(last_delta_ch0,32'd0,  "delta is 0 for first event after enable");

    // Second event: delta should be ts_now - last_ts_ch0
    ts_now = 32'd25;
    sample_ch0 = 32'd101; // hit again
    sample_valid = 1'b1;
    tick();
    sample_valid = 1'b0;

    expect32(evt_count_ch0, 32'd2,  "count ch0 after second hit");
    expect32(last_ts,       32'd25, "last_ts after second hit");
    expect32(last_ts_ch0,   32'd25, "last_ts_ch0 after second hit");
    expect32(last_delta_ch0,32'd15, "delta between hits");

    // No event: sample below threshold should not change counters/timestamps
    ts_now = 32'd40;
    sample_ch0 = 32'd99; // no hit
    sample_valid = 1'b1;
    tick();
    sample_valid = 1'b0;

    expect32(evt_count_ch0, 32'd2,  "count unchanged on miss");
    expect32(last_ts,       32'd25, "last_ts unchanged on miss");
    expect32(last_ts_ch0,   32'd25, "last_ts_ch0 unchanged on miss");
    expect32(last_delta_ch0,32'd15, "delta unchanged on miss");

    // Disable then re-enable: next event should reset history and delta should be 0
    evt_en = 8'h00;
    tick();
    evt_en = 8'h01;
    tick();

    ts_now = 32'd50;
    sample_ch0 = 32'd200; // hit
    sample_valid = 1'b1;
    tick();
    sample_valid = 1'b0;

    expect32(evt_count_ch0, 32'd3, "count after hit post re-enable");
    expect32(last_delta_ch0,32'd0, "delta resets to 0 after re-enable");

    $display("PASS: event_detector_tb");
    $finish;
  end

endmodule

`default_nettype wire
