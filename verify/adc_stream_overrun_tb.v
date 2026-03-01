// adc_stream_overrun_tb.v
//
// Directed test for FIFO overrun semantics when the producer keeps pushing
// (drop-on-full) and the consumer does not drain.
//
// Expectation (v1):
// - FIFO depth is finite (DEPTH=16 here)
// - when full, pushes are dropped and overrun_sticky asserts
// - the retained words are the earliest accepted ones (in-order)
//
`timescale 1ns/1ps
`default_nettype none

module adc_stream_overrun_tb;

  // Clock / reset
  reg clk;
  reg rst;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk; // 100 MHz
  end

  initial begin
    rst = 1'b1;
    repeat (5) @(posedge clk);
    rst = 1'b0;
  end

  localparam integer WORDS_IN  = 10;
  localparam integer WORDS_OUT = 9;
  localparam integer DEPTH     = 16;

  // Frame source -> frame_to_fifo
  reg                  frame_valid;
  reg [32*WORDS_IN-1:0] frame_words_packed;

  wire                 push_valid;
  wire [31:0]          push_data;
  wire                 push_ready;
  wire                 busy;
  wire                 frame_dropped;

  // FIFO
  wire                 pop_valid;
  wire [31:0]          pop_data;
  reg                  pop_ready;

  wire [$clog2(DEPTH+1)-1:0] level_words;
  wire                 overrun_sticky;
  reg                  overrun_clear;

  adc_frame_to_fifo #(
    .WORDS_IN (WORDS_IN),
    .WORDS_OUT(WORDS_OUT)
  ) u_f2f (
    .clk               (clk),
    .rst               (rst),
    .frame_valid       (frame_valid),
    .frame_words_packed(frame_words_packed),
    .push_valid        (push_valid),
    .push_data         (push_data),
    .push_ready        (push_ready),
    .busy              (busy),
    .frame_dropped     (frame_dropped)
  );

  adc_stream_fifo #(
    .DEPTH_WORDS(DEPTH)
  ) u_fifo (
    .clk           (clk),
    .rst           (rst),
    .push_valid    (push_valid),
    .push_data     (push_data),
    .push_ready    (push_ready),
    .pop_valid     (pop_valid),
    .pop_data      (pop_data),
    .pop_ready     (pop_ready),
    .level_words   (level_words),
    .overrun_sticky(overrun_sticky),
    .overrun_clear (overrun_clear)
  );

  task automatic pack_frame;
    input [31:0] base;
    integer i;
    begin
      frame_words_packed = {32*WORDS_IN{1'b0}};
      for (i = 0; i < WORDS_IN; i = i + 1) begin
        frame_words_packed[32*i +: 32] = base + i;
      end
    end
  endtask

  integer i;

  initial begin
    frame_valid        = 1'b0;
    frame_words_packed = {32*WORDS_IN{1'b0}};
    pop_ready          = 1'b0;
    overrun_clear      = 1'b0;

    @(negedge rst);
    repeat (2) @(posedge clk);

    // Consumer does not drain: force the FIFO to fill.
    pop_ready <= 1'b0;

    // Push 2 frames back-to-back: 2*9 = 18 words attempted into DEPTH=16.
    pack_frame(32'h1000);
    @(posedge clk);
    frame_valid <= 1'b1;
    @(posedge clk);
    frame_valid <= 1'b0;

    // Ensure we issue frame 1 after the skid buffer window (not to test frame_dropped).
    // This should still overflow the FIFO (not the f2f skid buffer).
    wait (busy == 1'b0);
    repeat (2) @(posedge clk);

    pack_frame(32'h2000);
    @(posedge clk);
    frame_valid <= 1'b1;
    @(posedge clk);
    frame_valid <= 1'b0;

    // Wait for the sequencer to finish pushing.
    wait (busy == 1'b0);
    repeat (5) @(posedge clk);

    if (level_words !== DEPTH[$clog2(DEPTH+1)-1:0]) begin
      $display("ERROR: expected FIFO level_words to saturate at %0d, got %0d", DEPTH, level_words);
      $fatal(1);
    end

    if (!overrun_sticky) begin
      $display("ERROR: expected overrun_sticky to assert when FIFO fills");
      $fatal(1);
    end

    if (frame_dropped) begin
      $display("ERROR: did not expect frame_dropped in this test (we waited for busy==0)");
      $fatal(1);
    end

    // Now drain and verify we kept the earliest 16 words in-order.
    pop_ready <= 1'b1;

    // Expected retained sequence:
    // - Frame0: base 0x1000, words 0..8
    // - Frame1: base 0x2000, words 0..6  (only first 7 fit)
    for (i = 0; i < DEPTH; i = i + 1) begin
      wait (pop_valid);
      @(posedge clk);

      if (i < 9) begin
        if (pop_data !== (32'h1000 + i)) begin
          $display("ERROR: pop[%0d]=0x%08x expected frame0 word=0x%08x", i, pop_data, 32'h1000 + i);
          $fatal(1);
        end
      end else begin
        if (pop_data !== (32'h2000 + (i-9))) begin
          $display("ERROR: pop[%0d]=0x%08x expected frame1 word=0x%08x", i, pop_data, 32'h2000 + (i-9));
          $fatal(1);
        end
      end
    end

    // FIFO should be empty after draining DEPTH words.
    repeat (2) @(posedge clk);
    if (level_words !== 0) begin
      $display("ERROR: expected FIFO to be empty after drain, got level_words=%0d", level_words);
      $fatal(1);
    end

    // Clear overrun and ensure it deasserts.
    @(posedge clk);
    overrun_clear <= 1'b1;
    @(posedge clk);
    overrun_clear <= 1'b0;

    repeat (2) @(posedge clk);
    if (overrun_sticky) begin
      $display("ERROR: expected overrun_sticky to clear");
      $fatal(1);
    end

    $display("PASS: adc_stream_overrun_tb");
    $finish;
  end

endmodule

`default_nettype wire
