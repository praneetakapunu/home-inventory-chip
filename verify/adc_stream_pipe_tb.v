// adc_stream_pipe_tb.v
//
// Integration smoke for the ADC streaming datapath primitives:
//   adc_frame_to_fifo -> adc_stream_fifo
//
// Goal: prove a completed frame can be sequenced into FIFO words and drained
// by a consumer, including basic backpressure on both push and pop.
//
`timescale 1ns/1ps
`default_nettype none

module adc_stream_pipe_tb;

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

  // Parameters kept small for fast, deterministic sim.
  localparam integer WORDS_IN  = 10;
  localparam integer WORDS_OUT = 9;
  localparam integer DEPTH     = 16;

  // Frame source
  reg                    frame_valid;
  reg [32*WORDS_IN-1:0]   frame_words_packed;
  wire                   f2f_push_valid;
  wire [31:0]            f2f_push_data;
  wire                   f2f_push_ready;
  wire                   f2f_busy;
  wire                   frame_dropped;

  // FIFO
  wire                   fifo_push_valid;
  wire [31:0]            fifo_push_data;
  wire                   fifo_push_ready;

  wire                   fifo_pop_valid;
  wire [31:0]            fifo_pop_data;
  reg                    fifo_pop_ready;

  wire [$clog2(DEPTH+1)-1:0] level_words;
  wire                   overrun_sticky;
  reg                    overrun_clear;

  assign fifo_push_valid = f2f_push_valid;
  assign fifo_push_data  = f2f_push_data;
  assign f2f_push_ready  = fifo_push_ready;

  adc_frame_to_fifo #(
    .WORDS_IN (WORDS_IN),
    .WORDS_OUT(WORDS_OUT)
  ) u_f2f (
    .clk               (clk),
    .rst               (rst),
    .frame_valid       (frame_valid),
    .frame_words_packed(frame_words_packed),
    .push_valid        (f2f_push_valid),
    .push_data         (f2f_push_data),
    .push_ready        (f2f_push_ready),
    .busy              (f2f_busy),
    .frame_dropped     (frame_dropped)
  );

  adc_stream_fifo #(
    .DEPTH_WORDS(DEPTH)
  ) u_fifo (
    .clk          (clk),
    .rst          (rst),
    .push_valid   (fifo_push_valid),
    .push_data    (fifo_push_data),
    .push_ready   (fifo_push_ready),
    .pop_valid    (fifo_pop_valid),
    .pop_data     (fifo_pop_data),
    .pop_ready    (fifo_pop_ready),
    .level_words  (level_words),
    .overrun_sticky(overrun_sticky),
    .overrun_clear(overrun_clear)
  );

  // Scoreboard
  integer pop_count;
  localparam integer TOTAL_WORDS = 2*WORDS_OUT;
  reg [31:0] expected_word [0:TOTAL_WORDS-1];

  task automatic load_expected;
    input integer start_idx;
    input [31:0] base;
    integer i;
    begin
      // Word0 = base+0, word1 = base+1, ... for easy checking.
      for (i = 0; i < WORDS_OUT; i = i + 1) begin
        expected_word[start_idx + i] = base + i;
      end

      // Pack WORDS_IN words; only first WORDS_OUT should be pushed.
      frame_words_packed = {32*WORDS_IN{1'b0}};
      for (i = 0; i < WORDS_IN; i = i + 1) begin
        frame_words_packed[32*i +: 32] = base + i;
      end
    end
  endtask

  // Simple consumer with pop backpressure pattern.
  always @(posedge clk) begin
    if (rst) begin
      fifo_pop_ready <= 1'b0;
      overrun_clear  <= 1'b0;
      pop_count      <= 0;
    end else begin
      overrun_clear <= 1'b0;

      // Toggle readiness to exercise backpressure.
      // Ready for 3 cycles, stall 2 cycles.
      if (($time/10) % 5 < 3) fifo_pop_ready <= 1'b1;
      else                    fifo_pop_ready <= 1'b0;

      if (fifo_pop_valid && fifo_pop_ready) begin
        if (pop_count >= TOTAL_WORDS) begin
          $display("ERROR: popped more than expected TOTAL_WORDS=%0d", TOTAL_WORDS);
          $fatal(1);
        end
        if (fifo_pop_data !== expected_word[pop_count]) begin
          $display("ERROR: pop[%0d]=0x%08x expected=0x%08x", pop_count, fifo_pop_data, expected_word[pop_count]);
          $fatal(1);
        end
        pop_count <= pop_count + 1;
      end
    end
  end

  initial begin
    frame_valid        = 1'b0;
    frame_words_packed = {32*WORDS_IN{1'b0}};

    // Wait for reset deassert
    @(negedge rst);
    repeat (2) @(posedge clk);

    // Prepare 2 frames worth of expected data.
    load_expected(0*WORDS_OUT, 32'h1000);

    // Present a 1-cycle frame_valid pulse (frame 0)
    @(posedge clk);
    frame_valid <= 1'b1;
    @(posedge clk);
    frame_valid <= 1'b0;

    // While busy, present a second frame; with the 1-frame skid buffer this
    // should be accepted and drained after frame 0.
    load_expected(1*WORDS_OUT, 32'h2000);
    repeat (2) @(posedge clk);
    frame_valid <= 1'b1;
    @(posedge clk);
    frame_valid <= 1'b0;

    // Third overlapping frame should be dropped.
    repeat (2) @(posedge clk);
    frame_valid <= 1'b1;
    @(posedge clk);
    frame_valid <= 1'b0;

    // Observe a frame_dropped pulse within a few cycles.
    begin : drop_check
      integer k;
      reg seen_drop;
      seen_drop = 1'b0;
      for (k = 0; k < 10; k = k + 1) begin
        if (frame_dropped) seen_drop = 1'b1;
        @(posedge clk);
      end
      if (!seen_drop) begin
        $display("ERROR: expected frame_dropped pulse for 3rd overlapping frame");
        $fatal(1);
      end
    end

    // Run until we've observed all expected pops.
    wait (pop_count == TOTAL_WORDS);

    // FIFO should eventually drain to empty.
    repeat (10) @(posedge clk);
    if (level_words !== 0) begin
      $display("ERROR: expected FIFO to drain to level 0, got %0d", level_words);
      $fatal(1);
    end

    // We should not see FIFO overrun in this smoke.
    if (overrun_sticky) begin
      $display("ERROR: unexpected fifo overrun_sticky");
      $fatal(1);
    end

    $display("PASS: adc_stream_pipe_tb");
    $finish;
  end

endmodule

`default_nettype wire
