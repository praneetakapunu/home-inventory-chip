// adc_streaming_ingest_tb.v
//
// Directed smoke test for adc_streaming_ingest (SPI capture -> frame_to_fifo -> FIFO pop).
//
// This test keeps the SPI model intentionally simple:
// - CPOL=0, CPHA=1 (default project mode)
// - We drive MISO MSB-first on each *posedge* of SCLK so it is stable by the
//   *negedge* (the sampling edge for CPHA=1 with CPOL=0).
//
`timescale 1ns/1ps
`default_nettype none

module adc_streaming_ingest_tb;

  // -------------------------
  // Clock/reset
  // -------------------------
  reg clk = 1'b0;
  always #5 clk = ~clk; // 100 MHz

  reg rst = 1'b1;

  // -------------------------
  // DUT signals
  // -------------------------
  reg  start;

  wire adc_sclk;
  wire adc_cs_n;
  wire adc_mosi;
  reg  adc_miso;

  wire        pop_valid;
  wire [31:0] pop_data;
  reg         pop_ready;

  wire        capture_busy;
  wire        fifo_overrun_sticky;
  reg         fifo_overrun_clear;
  wire [3:0]  fifo_level_words; // for FIFO_DEPTH_WORDS=8

  // -------------------------
  // Instantiate DUT
  // -------------------------
  localparam int unsigned BITS_PER_WORD   = 8;
  localparam int unsigned WORDS_PER_FRAME = 3;
  localparam int unsigned WORDS_OUT       = 3;
  localparam int unsigned SCLK_DIV        = 2;
  localparam int unsigned FIFO_DEPTH_WORDS = 8;

  adc_streaming_ingest #(
      .BITS_PER_WORD(BITS_PER_WORD),
      .WORDS_PER_FRAME(WORDS_PER_FRAME),
      .WORDS_OUT(WORDS_OUT),
      .SCLK_DIV(SCLK_DIV),
      .CPOL(1'b0),
      .CPHA(1'b1),
      .FIFO_DEPTH_WORDS(FIFO_DEPTH_WORDS)
  ) dut (
      .clk(clk),
      .rst(rst),
      .start(start),
      .adc_sclk(adc_sclk),
      .adc_cs_n(adc_cs_n),
      .adc_mosi(adc_mosi),
      .adc_miso(adc_miso),
      .pop_valid(pop_valid),
      .pop_data(pop_data),
      .pop_ready(pop_ready),
      .capture_busy(capture_busy),
      .fifo_overrun_sticky(fifo_overrun_sticky),
      .fifo_overrun_clear(fifo_overrun_clear),
      .fifo_level_words(fifo_level_words)
  );

  // -------------------------
  // Simple SPI MISO driver
  // -------------------------
  reg [BITS_PER_WORD-1:0] words [0:WORDS_PER_FRAME-1];
  integer word_i;
  integer bit_i;

  initial begin
    words[0] = 8'hA5;
    words[1] = 8'h5A;
    words[2] = 8'h3C;
  end

  // Reset bit/word counters when a new SPI transaction begins.
  always @(negedge adc_cs_n) begin
    word_i <= 0;
    bit_i  <= 0;
    adc_miso <= words[0][BITS_PER_WORD-1];
  end

  // Drive the next bit on each SCLK posedge while CS is asserted.
  // For CPHA=1, the DUT samples on negedge, so posedge-updated MISO is stable.
  always @(posedge adc_sclk) begin
    if (!adc_cs_n) begin
      if (word_i < WORDS_PER_FRAME) begin
        adc_miso <= words[word_i][BITS_PER_WORD-1-bit_i]; // MSB-first
      end else begin
        adc_miso <= 1'b0;
      end

      bit_i <= bit_i + 1;
      if (bit_i == BITS_PER_WORD-1) begin
        bit_i <= 0;
        word_i <= word_i + 1;
      end
    end
  end

  // -------------------------
  // Test sequence
  // -------------------------
  integer k;
  reg [7:0] got [0:WORDS_OUT-1];

  initial begin
    $display("[tb] start");

    start = 1'b0;
    adc_miso = 1'b0;
    pop_ready = 1'b0;
    fifo_overrun_clear = 1'b0;

    word_i = 0;
    bit_i  = 0;

    // reset
    repeat (5) @(posedge clk);
    rst <= 1'b0;

    // Start capture pulse
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    // Sanity: capture should go busy quickly.
    k = 0;
    while (!capture_busy) begin
      @(posedge clk);
      k = k + 1;
      if (k > 50) begin
        $fatal(1, "capture_busy never asserted after start");
      end
    end

    // Wait until FIFO has all words.
    // (Capture takes a little while due to SCLK divider and bit shifting.)
    k = 0;
    while (fifo_level_words != WORDS_OUT[3:0]) begin
      @(posedge clk);
      k = k + 1;
      if (k > 2000) begin
        $fatal(1, "timeout waiting for fifo_level_words == %0d (got %0d)", WORDS_OUT, fifo_level_words);
      end
    end

    if (fifo_overrun_sticky) $fatal(1, "unexpected overrun_sticky in basic capture");

    // Pop all words and check order.
    for (k = 0; k < WORDS_OUT; k = k + 1) begin
      // Wait until valid then accept on a cycle.
      while (!pop_valid) @(posedge clk);
      pop_ready = 1'b1;
      @(posedge clk);
      got[k] = pop_data[7:0];
      pop_ready = 1'b0;
      @(posedge clk);
    end

    if (got[0] !== 8'hA5) $fatal(1, "word0 mismatch: got 0x%02x", got[0]);
    if (got[1] !== 8'h5A) $fatal(1, "word1 mismatch: got 0x%02x", got[1]);
    if (got[2] !== 8'h3C) $fatal(1, "word2 mismatch: got 0x%02x", got[2]);

    if (fifo_level_words != 0) $fatal(1, "expected fifo empty after pops (level=%0d)", fifo_level_words);

    $display("[tb] PASS");
    $finish;
  end

endmodule

`default_nettype wire
