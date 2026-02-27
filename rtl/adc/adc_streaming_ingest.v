// adc_streaming_ingest.v
//
// Glue block: SPI framed capture -> streaming FIFO.
//
// Purpose:
// - Provide a stable, reusable integration point so the Wishbone block (or any
//   other consumer) can drain ADC frames as a word stream.
// - Keep the capture block generic (adc_spi_frame_capture) and keep FIFO logic
//   generic (adc_stream_fifo). This module owns the sequencing needed to push
//   an entire captured frame into the FIFO over multiple cycles.
//
// Notes:
// - This module does *not* interpret ADC words (no channel mapping). It simply
//   forwards the captured 32-bit packed words in order: word0, word1, ...
// - Backpressure: if the FIFO is full, pushing pauses until space is available.
//   A frame may therefore take multiple cycles to drain into the FIFO.
// - If the FIFO depth is smaller than WORDS_PER_FRAME, overrun is possible when
//   firmware does not drain fast enough. The FIFO exposes a sticky overrun flag.
//
`default_nettype none

module adc_streaming_ingest #(
    parameter int unsigned BITS_PER_WORD   = 24,
    parameter int unsigned WORDS_PER_FRAME = 9,
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
    wire                          frame_valid;
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
    // FIFO
    // ---------------------------------------------------------------------
    wire        push_ready;
    reg         push_valid;
    reg  [31:0] push_data;

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

    // ---------------------------------------------------------------------
    // Push sequencer
    // ---------------------------------------------------------------------
    localparam int unsigned WORD_IDX_W = (WORDS_PER_FRAME < 2) ? 1 : $clog2(WORDS_PER_FRAME);

    reg [32*WORDS_PER_FRAME-1:0] frame_hold;
    reg [WORD_IDX_W-1:0]         word_idx;
    reg                          have_frame;

    wire [31:0] hold_word = frame_hold[32*word_idx +: 32];

    always @(posedge clk) begin
        if (rst) begin
            frame_hold <= '0;
            word_idx   <= '0;
            have_frame <= 1'b0;
            push_valid <= 1'b0;
            push_data  <= 32'h0;
        end else begin
            // default
            push_valid <= 1'b0;

            // Latch a completed capture.
            // If we're still draining a prior frame, we currently drop the new one.
            // In v1, upstream should avoid starting a new capture until drained.
            if (frame_valid && !have_frame) begin
                frame_hold <= frame_words_packed;
                word_idx   <= '0;
                have_frame <= 1'b1;
            end

            // Drain the held frame into the FIFO, one word per cycle (when ready).
            if (have_frame) begin
                if (push_ready) begin
                    push_valid <= 1'b1;
                    push_data  <= hold_word;

                    if (word_idx == WORDS_PER_FRAME-1) begin
                        have_frame <= 1'b0;
                        word_idx   <= '0;
                    end else begin
                        word_idx <= word_idx + {{(WORD_IDX_W-1){1'b0}},1'b1};
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
