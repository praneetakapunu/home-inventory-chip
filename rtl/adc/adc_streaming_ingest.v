// adc_streaming_ingest.v
//
// Glue block: SPI framed capture -> streaming FIFO.
//
// Purpose:
// - Provide a stable, reusable integration point so the Wishbone block (or any
//   other consumer) can drain ADC frames as a word stream.
// - Keep the capture block generic (adc_spi_frame_capture) and keep FIFO logic
//   generic (adc_stream_fifo). This module owns the sequencing needed to push
//   a captured frame into the FIFO over multiple cycles.
//
// v1 policy alignment (normative): docs/ADC_STREAM_CONTRACT.md
// - Drop-on-full: if the FIFO is full, attempted pushes are dropped and the
//   FIFO's sticky overrun flag asserts.
// - Back-to-back frames: a 1-frame skid buffer is provided by adc_frame_to_fifo.
//
// Notes:
// - This module does *not* interpret ADC words (no channel mapping). It simply
//   forwards the captured 32-bit packed words in order: word0, word1, ...
// - This module exposes the FIFO level + sticky overrun flag so the regbank can
//   implement ADC_FIFO_STATUS/ADC_FIFO_DATA semantics.
//
`default_nettype none

module adc_streaming_ingest #(
    parameter int unsigned BITS_PER_WORD   = 24,
    parameter int unsigned WORDS_PER_FRAME = 9,

    // If the on-wire frame contains extra words (e.g., ADS131M08 OUTPUT_CRC),
    // set WORDS_OUT < WORDS_PER_FRAME to drop the tail.
    parameter int unsigned WORDS_OUT       = WORDS_PER_FRAME,

    parameter int unsigned SCLK_DIV        = 4,
    parameter bit          CPOL            = 1'b0,
    parameter bit          CPHA            = 1'b1,

    parameter int unsigned FIFO_DEPTH_WORDS = 64
) (
    input  wire        clk,
    input  wire        rst,

    // Start capture for one frame (pulse). If asserted while busy, it is ignored.
    input  wire        start,

    // SPI pins (direction is from our SoC perspective)
    output wire        adc_sclk,
    output wire        adc_cs_n,
    output wire        adc_mosi,
    input  wire        adc_miso,

    // Stream out (firmware side)
    output wire        pop_valid,
    output wire [31:0] pop_data,
    input  wire        pop_ready,

    // Status
    output wire        capture_busy,
    output wire        fifo_overrun_sticky,
    input  wire        fifo_overrun_clear,
    output wire [$clog2(FIFO_DEPTH_WORDS+1)-1:0] fifo_level_words
);

    // ---------------------------------------------------------------------
    // SPI framed capture
    // ---------------------------------------------------------------------
    wire                           frame_valid;
    wire [32*WORDS_PER_FRAME-1:0]  frame_words_packed;

    adc_spi_frame_capture #(
        .BITS_PER_WORD(BITS_PER_WORD),
        .WORDS_PER_FRAME(WORDS_PER_FRAME),
        .SCLK_DIV(SCLK_DIV),
        .CPOL(CPOL),
        .CPHA(CPHA)
    ) u_cap (
        .clk(clk),
        .rst(rst),
        .start(start),
        .adc_sclk(adc_sclk),
        .adc_cs_n(adc_cs_n),
        .adc_mosi(adc_mosi),
        .adc_miso(adc_miso),
        .frame_valid(frame_valid),
        .frame_words_packed(frame_words_packed),
        .busy(capture_busy)
    );

    // ---------------------------------------------------------------------
    // Frame -> FIFO push sequencer (drop-on-full)
    // ---------------------------------------------------------------------
    wire        push_valid;
    wire [31:0] push_data;
    wire        push_ready;

    wire        push_seq_busy;
    wire        frame_dropped;

    // Synthesis-time guardrails.
    initial begin
        if (WORDS_OUT < 1) $fatal(1, "WORDS_OUT must be >= 1");
        if (WORDS_OUT > WORDS_PER_FRAME) $fatal(1, "WORDS_OUT must be <= WORDS_PER_FRAME");
    end

    adc_frame_to_fifo #(
        .WORDS_IN(WORDS_PER_FRAME),
        .WORDS_OUT(WORDS_OUT)
    ) u_frame_to_fifo (
        .clk(clk),
        .rst(rst),
        .frame_valid(frame_valid),
        .frame_words_packed(frame_words_packed),
        .push_valid(push_valid),
        .push_data(push_data),
        .push_ready(push_ready),
        .busy(push_seq_busy),
        .frame_dropped(frame_dropped)
    );

    // ---------------------------------------------------------------------
    // FIFO (drop-on-full via push_valid && !push_ready)
    // ---------------------------------------------------------------------
    adc_stream_fifo #(
        .DEPTH_WORDS(FIFO_DEPTH_WORDS)
    ) u_fifo (
        .clk(clk),
        .rst(rst),
        .push_valid(push_valid),
        .push_data(push_data),
        .push_ready(push_ready),
        .pop_valid(pop_valid),
        .pop_data(pop_data),
        .pop_ready(pop_ready),
        .level_words(fifo_level_words),
        .overrun_sticky(fifo_overrun_sticky),
        .overrun_clear(fifo_overrun_clear)
    );

    // NOTE: frame_dropped indicates the push sequencer had to drop a whole frame
    // because more than 1 back-to-back frame arrived while busy. For v1, the
    // regbank may optionally OR this into an overrun condition.
    // (We don't wire it here because overrun_sticky is owned by the FIFO.)
    wire _unused_frame_dropped = frame_dropped;
    wire _unused_push_seq_busy = push_seq_busy;

endmodule

`default_nettype wire
