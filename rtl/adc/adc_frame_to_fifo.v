// adc_frame_to_fifo.v
//
// Small "push sequencer" that converts a packed ADC frame into a sequence of
// FIFO push beats (1 word per accepted cycle).
//
// v1 intent:
// - Latch a completed frame (frame_valid pulse) and then push WORDS_OUT words
//   in-order into the downstream FIFO.
// - Downstream FIFO provides standard ready/valid backpressure.
// - If a new frame_valid arrives while we're still draining the previous frame,
//   the new frame is ignored and frame_dropped pulses (integration may choose
//   to treat this as an overrun condition).
//
// This is a wiring primitive used by the ADC streaming path described in:
//   docs/ADC_STREAM_CONTRACT.md
//
`timescale 1ns/1ps
`default_nettype none

module adc_frame_to_fifo #(
    parameter integer WORDS_IN  = 10,  // packed frame words provided
    parameter integer WORDS_OUT = 9    // words to push to FIFO (e.g. drop CRC)
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

    // Push sequencing
    localparam integer IDX_W = (WORDS_OUT <= 2) ? 1 : $clog2(WORDS_OUT);
    reg                  active;
    reg [IDX_W-1:0]       idx;

    assign busy = active;

    // Present current word.
    // Word0 is [31:0], word1 is [63:32], ...
    assign push_data  = latched_words[32*idx +: 32];
    assign push_valid = active;

    always @(posedge clk) begin
        if (rst) begin
            latched_words <= {32*WORDS_OUT{1'b0}};
            active        <= 1'b0;
            idx           <= {IDX_W{1'b0}};
            frame_dropped <= 1'b0;
        end else begin
            frame_dropped <= 1'b0;

            // Frame accept / drop policy
            if (frame_valid) begin
                if (!active) begin
                    latched_words <= frame_words_packed[32*WORDS_OUT-1:0];
                    active        <= 1'b1;
                    idx           <= {IDX_W{1'b0}};
                end else begin
                    // Can't accept a new frame until we're done pushing this one.
                    frame_dropped <= 1'b1;
                end
            end

            // Drive push handshakes while active.
            if (active && push_ready) begin
                if (idx == WORDS_OUT-1) begin
                    active <= 1'b0;
                    idx    <= {IDX_W{1'b0}};
                end else begin
                    idx <= idx + 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
