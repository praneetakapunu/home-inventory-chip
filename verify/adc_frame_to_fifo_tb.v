// adc_frame_to_fifo_tb.v
//
// Directed testbench for adc_frame_to_fifo push sequencer.
//
// Checks:
// - Pushes WORDS_OUT words in-order after frame_valid.
// - Honors push_ready backpressure.
// - Pulses frame_dropped if a new frame_valid arrives while busy.
//
`timescale 1ns/1ps
`default_nettype none

module adc_frame_to_fifo_tb;

  localparam integer WORDS_IN  = 10;
  localparam integer WORDS_OUT = 9;

  reg clk;
  reg rst;

  reg                    frame_valid;
  reg [32*WORDS_IN-1:0]   frame_words_packed;

  wire                   push_valid;
  wire [31:0]            push_data;
  reg                    push_ready;

  wire                   busy;
  wire                   frame_dropped;

  adc_frame_to_fifo #(
    .WORDS_IN(WORDS_IN),
    .WORDS_OUT(WORDS_OUT)
  ) dut (
    .clk(clk),
    .rst(rst),
    .frame_valid(frame_valid),
    .frame_words_packed(frame_words_packed),
    .push_valid(push_valid),
    .push_data(push_data),
    .push_ready(push_ready),
    .busy(busy),
    .frame_dropped(frame_dropped)
  );

  // Clock
  initial clk = 1'b0;
  always #5 clk = ~clk;

  integer i;
  integer push_count;

  // Helpers
  task pack_frame_incrementing;
    integer w;
    begin
      // word0 in [31:0], word1 in [63:32], ...
      for (w = 0; w < WORDS_IN; w = w + 1) begin
        frame_words_packed[32*w +: 32] = 32'hA000_0000 + w;
      end
    end
  endtask

  task expect_push_word;
    input [31:0] expected;
    begin
      if (push_data !== expected) begin
        $display("FAIL: push_data mismatch. expected=%h got=%h time=%0t", expected, push_data, $time);
        $fatal(1);
      end
    end
  endtask

  initial begin
    $display("adc_frame_to_fifo_tb: start");

    // Init
    rst = 1'b1;
    frame_valid = 1'b0;
    frame_words_packed = {32*WORDS_IN{1'b0}};
    push_ready = 1'b0;
    push_count = 0;

    repeat (4) @(posedge clk);
    rst = 1'b0;
    @(posedge clk);

    // Load a known frame.
    pack_frame_incrementing();

    // Fire frame_valid for 1 cycle.
    frame_valid <= 1'b1;
    @(posedge clk);
    frame_valid <= 1'b0;

    // Apply backpressure for a couple cycles, then allow pushes.
    // During backpressure, push_valid should remain asserted while busy.
    repeat (2) begin
      push_ready <= 1'b0;
      @(posedge clk);
      if (busy !== 1'b1) begin
        $display("FAIL: expected busy during push sequence (backpressure) time=%0t", $time);
        $fatal(1);
      end
      if (push_valid !== 1'b1) begin
        $display("FAIL: expected push_valid asserted while busy time=%0t", $time);
        $fatal(1);
      end
    end

    // Now drain with intermittent stalls.
    for (i = 0; i < WORDS_OUT; i = i + 1) begin
      // Sometimes stall.
      if (i == 3 || i == 6) begin
        push_ready <= 1'b0;
        @(posedge clk);
        if (push_valid !== 1'b1) begin
          $display("FAIL: expected push_valid asserted during stall time=%0t", $time);
          $fatal(1);
        end
      end

      push_ready <= 1'b1;
      @(posedge clk);
      if (push_valid !== 1'b1) begin
        $display("FAIL: expected push_valid when ready time=%0t", $time);
        $fatal(1);
      end
      expect_push_word(32'hA000_0000 + i);
      push_count = push_count + 1;
    end

    // After last word accepted, busy should drop within 1 cycle.
    push_ready <= 1'b1;
    @(posedge clk);
    if (busy !== 1'b0) begin
      $display("FAIL: expected busy deasserted after final push time=%0t", $time);
      $fatal(1);
    end

    if (push_count !== WORDS_OUT) begin
      $display("FAIL: expected %0d pushes, saw %0d", WORDS_OUT, push_count);
      $fatal(1);
    end

    // Check frame_dropped behavior.
    // Start a frame, then attempt to start another before done.
    push_count = 0;
    pack_frame_incrementing();

    frame_valid <= 1'b1;
    @(posedge clk);
    frame_valid <= 1'b0;

    // While busy, pulse frame_valid again; should drop.
    // Hold push_ready low so we don't accidentally advance the sequencer while
    // we're checking for the drop pulse.
    push_ready <= 1'b0;
    @(posedge clk);
    if (busy !== 1'b1) begin
      $display("FAIL: expected busy before drop test time=%0t", $time);
      $fatal(1);
    end
    frame_valid <= 1'b1;
    @(posedge clk);
    frame_valid <= 1'b0;

    // frame_dropped is a 1-cycle pulse; it may occur on the same cycle as the
    // rejected frame_valid or the immediately following cycle depending on
    // sampling. Accept either, but require it to be observed.
    begin : drop_check
      integer k;
      reg seen_drop;
      seen_drop = 1'b0;
      for (k = 0; k < 3; k = k + 1) begin
        if (frame_dropped) seen_drop = 1'b1;
        @(posedge clk);
      end
      if (!seen_drop) begin
        $display("FAIL: expected frame_dropped pulse (not observed) time=%0t", $time);
        $fatal(1);
      end
    end

    // Drain the first frame quickly.
    push_ready <= 1'b1;
    while (busy) begin
      @(posedge clk);
      if (push_valid && push_ready) push_count = push_count + 1;
    end

    if (push_count !== WORDS_OUT) begin
      $display("FAIL: expected %0d pushes in drop test, saw %0d", WORDS_OUT, push_count);
      $fatal(1);
    end

    $display("adc_frame_to_fifo_tb: PASS");
    $finish;
  end

endmodule

`default_nettype wire
