// adc_spi_frame_capture_tb.v
//
// Minimal self-checking testbench for adc_spi_frame_capture.
//
// Strategy:
// - Instantiate DUT with small frame size for fast simulation.
// - Use CPOL=0, CPHA=1 (matches ADS131M08 mode per project spec).
//   => sampling occurs on SCLK *falling* edges (trailing edge back to idle).
// - Drive adc_miso MSB-first, updating on SCLK rising edges (prep next bit).
//
`timescale 1ns/1ps
`default_nettype none

module adc_spi_frame_capture_tb;

  // -------------------------
  // Clocks / reset
  // -------------------------
  reg clk = 1'b0;
  always #5 clk = ~clk; // 100MHz

  reg rst   = 1'b1;
  reg start = 1'b0;

  // -------------------------
  // DUT pins
  // -------------------------
  wire adc_sclk;
  wire adc_cs_n;
  wire adc_mosi;
  reg  adc_miso = 1'b0;

  wire frame_valid;
  wire [63:0] frame_words_packed;
  wire busy;

  localparam int unsigned BITS_PER_WORD   = 8;
  localparam int unsigned WORDS_PER_FRAME = 2;
  localparam int unsigned SCLK_DIV        = 2;

  adc_spi_frame_capture #(
    .BITS_PER_WORD(BITS_PER_WORD),
    .WORDS_PER_FRAME(WORDS_PER_FRAME),
    .SCLK_DIV(SCLK_DIV),
    .CPOL(1'b0),
    .CPHA(1'b1)
  ) dut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .adc_sclk(adc_sclk),
    .adc_cs_n(adc_cs_n),
    .adc_mosi(adc_mosi),
    .adc_miso(adc_miso),
    .frame_valid(frame_valid),
    .frame_words_packed(frame_words_packed),
    .busy(busy)
  );

  // -------------------------
  // Stimulus: 2 words of 8b each
  // Word0 = 0xA5, Word1 = 0x3C
  // MSB-first on the wire.
  // -------------------------
  reg [15:0] bitstream = 16'hA53C;
  integer bit_idx;

  // Helper: load current bit into adc_miso
  task automatic drive_current_bit;
    begin
      adc_miso = bitstream[15 - bit_idx];
    end
  endtask

  // When CS asserts low, reset our bit index.
  // For CPHA=1, the first *valid* data bit is typically presented after the first
  // leading edge, and sampled on the trailing edge.
  always @(negedge adc_cs_n) begin
    bit_idx = 0;
    adc_miso = 1'b0;
  end

  // For CPHA=1 we sample on falling edges, so we present the current bit on the
  // rising edge (leading edge) and advance the index on the falling edge.
  always @(posedge adc_sclk) begin
    if (!adc_cs_n) begin
      drive_current_bit();
    end
  end

  always @(negedge adc_sclk) begin
    if (!adc_cs_n) begin
      if (bit_idx < 16-1) begin
        bit_idx = bit_idx + 1;
      end
    end
  end

  // -------------------------
  // Test sequence + checks
  // -------------------------
  initial begin
    $dumpfile("adc_spi_frame_capture_tb.vcd");
    $dumpvars(0, adc_spi_frame_capture_tb);

    // Reset
    repeat (5) @(posedge clk);
    rst <= 1'b0;

    // Start pulse
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    // Wait for completion
    wait (frame_valid === 1'b1);
    @(posedge clk);

    // Expected packing: word0 in [31:0], word1 in [63:32]
    if (frame_words_packed[31:0] !== 32'h000000A5) begin
      $display("FAIL: word0 mismatch: got 0x%08x", frame_words_packed[31:0]);
      $finish(2);
    end
    if (frame_words_packed[63:32] !== 32'h0000003C) begin
      $display("FAIL: word1 mismatch: got 0x%08x", frame_words_packed[63:32]);
      $finish(2);
    end

    $display("PASS: adc_spi_frame_capture captured expected frame");
    $finish(0);
  end

endmodule

`default_nettype wire
