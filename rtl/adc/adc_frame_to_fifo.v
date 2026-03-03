// adc_frame_to_fifo.v
//
// Small "push sequencer" that converts a packed ADC frame into a sequence of
// FIFO push beats (1 word per accepted cycle).
//
// v1 intent:
// - Latch a completed frame (frame_valid pulse) and then attempt to push
//   WORDS_OUT words in-order into the downstream FIFO (1 word/cycle).
// - If the FIFO is full (push_ready==0), the word is dropped (drop-on-full).
// - Includes a 1-frame skid buffer: if a new frame_valid arrives while we're
//   still draining the current frame, we queue exactly one pending frame.
// - If more than one additional frame arrives while both current+pending are
//   occupied, frame_dropped pulses (integration may choose to treat this as an
//   overrun condition).
//
// This is a wiring primitive used by the ADC streaming path described in:
//   docs/ADC_STREAM_CONTRACT.md
//
`timescale 1ns/1ps
`default_nettype none

module adc_frame_to_fifo #(
    parameter integer WORDS_IN  = 10,  // packed frame words provided
    parameter integer WORDS_OUT = 9,   // words to push to FIFO (e.g. drop CRC)

    // Optional sign-extension policy for captured words.
    // Rationale: some ADCs (incl. ADS131M08 in default 24-bit mode) provide
    // two's-complement conversion samples that must be sign-extended to 32b.
    // The capture block zero-extends into 32b slots; this sequencer can
    // re-apply sign-extension on a per-word-index range.
    parameter bit     SIGN_EXTEND_EN        = 1'b0,
    parameter integer SIGN_EXTEND_BITS      = 24,
    parameter integer SIGN_EXTEND_START_IDX = 1,
    parameter integer SIGN_EXTEND_END_IDX   = WORDS_OUT-1
) (
    input  wire                     clk,
    input  wire                     rst,

    // Input frame
    input  wire                     frame_valid,  // 1-cycle pulse
    input  wire [32*WORDS_IN-1:0]    frame_words_packed,

    // FIFO push interface
    output wire                     push_valid,
    output wire [31:0]              push_data,
    input  wire                     push_ready,

    // Status
    output wire                     busy,
    output reg                      frame_dropped
);

    // Latch only the words we will ever push (word0..word(WORDS_OUT-1)).
    reg [32*WORDS_OUT-1:0] latched_words;

    // Parameter sanity (elaboration-time).
    initial begin
        if (WORDS_IN < 1) $fatal(1, "adc_frame_to_fifo: WORDS_IN must be >= 1");
        if (WORDS_OUT < 1) $fatal(1, "adc_frame_to_fifo: WORDS_OUT must be >= 1");
        if (WORDS_OUT > WORDS_IN) $fatal(1, "adc_frame_to_fifo: WORDS_OUT must be <= WORDS_IN");

        if (SIGN_EXTEND_EN) begin
            if (SIGN_EXTEND_BITS < 1)  $fatal(1, "adc_frame_to_fifo: SIGN_EXTEND_BITS must be >= 1");
            if (SIGN_EXTEND_BITS > 32) $fatal(1, "adc_frame_to_fifo: SIGN_EXTEND_BITS must be <= 32");
            if (SIGN_EXTEND_START_IDX < 0) $fatal(1, "adc_frame_to_fifo: SIGN_EXTEND_START_IDX must be >= 0");
            if (SIGN_EXTEND_END_IDX < SIGN_EXTEND_START_IDX) $fatal(1, "adc_frame_to_fifo: SIGN_EXTEND_END_IDX must be >= SIGN_EXTEND_START_IDX");
        end
    end

    // 1-frame skid buffer so back-to-back frame_valid pulses aren't dropped.
    // (If a third frame arrives while both current+pending are occupied, we drop it.)
    reg                   pending_valid;
    reg [32*WORDS_OUT-1:0] pending_words;

    // Push sequencing
    localparam integer IDX_W = (WORDS_OUT <= 2) ? 1 : $clog2(WORDS_OUT);
    reg                  active;
    reg [IDX_W-1:0]       idx;

    assign busy = active | pending_valid;

    // Present current word.
    // Word0 is [31:0], word1 is [63:32], ...
    wire [31:0] cur_word = latched_words[32*idx +: 32];

    // Optional sign-extension for a range of words.
    // NOTE: We interpret the lower SIGN_EXTEND_BITS as a signed two's-complement value.
    wire in_signext_range = (idx >= SIGN_EXTEND_START_IDX[IDX_W-1:0]) && (idx <= SIGN_EXTEND_END_IDX[IDX_W-1:0]);
    wire sign_bit = (SIGN_EXTEND_BITS >= 1) ? cur_word[SIGN_EXTEND_BITS-1] : 1'b0;
    wire [31:0] signext_word = (SIGN_EXTEND_BITS >= 32) ? cur_word
        : {{(32-SIGN_EXTEND_BITS){sign_bit}}, cur_word[SIGN_EXTEND_BITS-1:0]};

    assign push_data  = (SIGN_EXTEND_EN && in_signext_range) ? signext_word : cur_word;
    assign push_valid = active;

    always @(posedge clk) begin
        if (rst) begin
            latched_words  <= {32*WORDS_OUT{1'b0}};
            pending_valid  <= 1'b0;
            pending_words  <= {32*WORDS_OUT{1'b0}};
            active         <= 1'b0;
            idx            <= {IDX_W{1'b0}};
            frame_dropped  <= 1'b0;
        end else begin
            frame_dropped <= 1'b0;

            // Frame accept / buffering policy
            if (frame_valid) begin
                if (!active) begin
                    // Idle: accept immediately as the current frame.
                    latched_words <= frame_words_packed[32*WORDS_OUT-1:0];
                    active        <= 1'b1;
                    idx           <= {IDX_W{1'b0}};
                end else if (!pending_valid) begin
                    // Busy: buffer exactly one upcoming frame.
                    pending_words <= frame_words_packed[32*WORDS_OUT-1:0];
                    pending_valid <= 1'b1;
                end else begin
                    // Can't accept more than one pending frame.
                    frame_dropped <= 1'b1;
                end
            end

            // Push sequencing while active.
            // v1 policy: 1 word/cycle. If push_ready==0, the word is dropped.
            if (active) begin
                if (idx == WORDS_OUT-1) begin
                    if (pending_valid) begin
                        // Immediately start pushing the pending frame next.
                        latched_words <= pending_words;
                        pending_valid <= 1'b0;
                        idx           <= {IDX_W{1'b0}};
                        active        <= 1'b1;
                    end else begin
                        active <= 1'b0;
                        idx    <= {IDX_W{1'b0}};
                    end
                end else begin
                    idx <= idx + 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
