// adc_frame_to_fifo_tb.v
//
// Directed testbench for adc_frame_to_fifo push sequencer.
//
// Checks (v1):
// - Presents WORDS_OUT words in-order (word0..word(WORDS_OUT-1)).
// - Advances at 1 word/cycle while busy.
// - Implements drop-on-full: if push_ready==0, the word is dropped (still advances).
// - Has a 1-frame skid buffer; a third overlapping frame is dropped (frame_dropped pulses).
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

  // Helpers
  task automatic pack_frame_incrementing;
    integer w;
    begin
      // word0 in [31:0], word1 in [63:32], ...
      for (w = 0; w < WORDS_IN; w = w + 1) begin
        frame_words_packed[32*w +: 32] = 32'hA000_0000 + w;
      end
    end
  endtask

  task automatic pulse_frame_valid;
    begin
      frame_valid <= 1'b1;
      @(posedge clk);
      frame_valid <= 1'b0;
    end
  endtask

  task automatic expect_word;
    input [31:0] exp;
    begin
      if (push_data !== exp) begin
        $display("FAIL: push_data mismatch exp=%h got=%h time=%0t", exp, push_data, $time);
        $fatal(1);
      end
    end
  endtask

  integer i;
  integer accepted;
  integer word_idx;

  initial begin
    $display("adc_frame_to_fifo_tb: start");

    // Init
    rst = 1'b1;
    frame_valid = 1'b0;
    frame_words_packed = {32*WORDS_IN{1'b0}};
    push_ready = 1'b0;

    repeat (4) @(posedge clk);
    rst = 1'b0;
    @(posedge clk);

    // ------------------------------------------------------------------
    // Test 1: no stalls, accept all WORDS_OUT words
    // ------------------------------------------------------------------
    pack_frame_incrementing();
    push_ready <= 1'b1;
    pulse_frame_valid();

    accepted = 0;
    word_idx = 0;

    // Busy should assert shortly after frame_valid (same or next cycle).
    if (!busy) @(posedge clk);
    if (busy !== 1'b1) begin
      $display("FAIL: expected busy asserted after frame_valid time=%0t", $time);
      $fatal(1);
    end

    while (busy) begin
      if (push_valid !== 1'b1) begin
        $display("FAIL: expected push_valid while busy time=%0t", $time);
        $fatal(1);
      end
      expect_word(32'hA000_0000 + word_idx);
      if (push_ready) accepted = accepted + 1;
      word_idx = word_idx + 1;
      @(posedge clk);
    end

    if (word_idx !== WORDS_OUT) begin
      $display("FAIL: expected %0d presented words, saw %0d", WORDS_OUT, word_idx);
      $fatal(1);
    end
    if (accepted !== WORDS_OUT) begin
      $display("FAIL: expected %0d accepted pushes, saw %0d", WORDS_OUT, accepted);
      $fatal(1);
    end

    // ------------------------------------------------------------------
    // Test 2: stalls cause drops; still advances 1 word/cycle
    // ------------------------------------------------------------------
    pack_frame_incrementing();
    accepted = 0;
    word_idx = 0;

    // Stall for first 2 words, then accept, then stall once mid-frame.
    push_ready <= 1'b0;
    pulse_frame_valid();

    if (!busy) @(posedge clk);
    while (busy) begin
      if (push_valid !== 1'b1) begin
        $display("FAIL: expected push_valid while busy time=%0t", $time);
        $fatal(1);
      end
      expect_word(32'hA000_0000 + word_idx);

      // Ready pattern by word index (since we advance 1/cycle):
      // drop words 0,1 and 4; accept the rest.
      if (word_idx == 0 || word_idx == 1 || word_idx == 4) push_ready = 1'b0;
      else push_ready = 1'b1;

      if (push_ready) accepted = accepted + 1;
      word_idx = word_idx + 1;
      @(posedge clk);
    end

    if (word_idx !== WORDS_OUT) begin
      $display("FAIL: expected %0d presented words (stall test), saw %0d", WORDS_OUT, word_idx);
      $fatal(1);
    end
    if (accepted !== (WORDS_OUT - 3)) begin
      $display("FAIL: expected %0d accepted pushes (stall test), saw %0d", WORDS_OUT-3, accepted);
      $fatal(1);
    end

    // ------------------------------------------------------------------
    // Test 3: 1-frame skid buffer, then drop on third overlap
    // ------------------------------------------------------------------
    push_ready <= 1'b0; // ensure we stay busy for overlap checks
    pack_frame_incrementing();
    pulse_frame_valid();

    // One extra overlapping frame should be buffered (no drop pulse).
    @(posedge clk);
    pulse_frame_valid();

    // Third overlapping frame should be dropped.
    @(posedge clk);
    pulse_frame_valid();

    begin : drop_check
      integer k;
      reg seen_drop;
      seen_drop = 1'b0;
      for (k = 0; k < 5; k = k + 1) begin
        if (frame_dropped) seen_drop = 1'b1;
        @(posedge clk);
      end
      if (!seen_drop) begin
        $display("FAIL: expected frame_dropped pulse on 3rd overlap (not observed) time=%0t", $time);
        $fatal(1);
      end
    end

    // Let it run out.
    push_ready <= 1'b1;
    while (busy) @(posedge clk);

    $display("adc_frame_to_fifo_tb: PASS");
    $finish;
  end

endmodule

`default_nettype wire
