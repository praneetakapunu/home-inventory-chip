// adc_soc_frame_unpack.v
//
// Pure-combinational helper: unpack a captured ADC wire-frame into the
// firmware/SoC-visible "STATUS + CH0..CH7" words.
//
// This is primarily used to:
// - wire the event detector to the *real* ADC samples (CH0..CH7)
// - keep the STATUS/CH indexing rule explicit and reusable
//
// Normative contract: docs/ADC_STREAM_CONTRACT.md
//
// Assumptions (v1 / ADS131M08):
// - word0 = STATUS/RESPONSE
// - word1..8 = CH0..CH7
// - (optional) trailing words (e.g., OUTPUT_CRC) may exist and are ignored here
//
`default_nettype none

module adc_soc_frame_unpack #(
    // Number of bits in each input word. Must be 1..32.
    parameter int unsigned BITS_PER_WORD   = 32,

    // Number of words in the packed vector. Must be >= 9.
    parameter int unsigned WORDS_PER_FRAME = 10
) (
    input  wire [32*WORDS_PER_FRAME-1:0] frame_words_packed,

    output wire [31:0] status_word,
    output wire [31:0] ch0,
    output wire [31:0] ch1,
    output wire [31:0] ch2,
    output wire [31:0] ch3,
    output wire [31:0] ch4,
    output wire [31:0] ch5,
    output wire [31:0] ch6,
    output wire [31:0] ch7
);

    initial begin
        if (BITS_PER_WORD < 1)   $fatal(1, "BITS_PER_WORD must be >= 1");
        if (BITS_PER_WORD > 32)  $fatal(1, "BITS_PER_WORD must be <= 32");
        if (WORDS_PER_FRAME < 9) $fatal(1, "WORDS_PER_FRAME must be >= 9 (STATUS + 8 channels)");
    end

    function automatic [31:0] sx_to_32(input [31:0] w);
        // Sign-extend the low BITS_PER_WORD bits to 32.
        // - For BITS_PER_WORD==32, this is a no-op.
        // - For smaller widths (e.g., 24), sign bit is w[BITS_PER_WORD-1].
        reg sign;
        begin
            sign = w[BITS_PER_WORD-1];
            if (BITS_PER_WORD == 32) begin
                sx_to_32 = w;
            end else begin
                sx_to_32 = {{(32-BITS_PER_WORD){sign}}, w[BITS_PER_WORD-1:0]};
            end
        end
    endfunction

    // Packed format: word0 in [31:0], word1 in [63:32], etc.
    wire [31:0] w0 = frame_words_packed[ 32*0 +: 32];
    wire [31:0] w1 = frame_words_packed[ 32*1 +: 32];
    wire [31:0] w2 = frame_words_packed[ 32*2 +: 32];
    wire [31:0] w3 = frame_words_packed[ 32*3 +: 32];
    wire [31:0] w4 = frame_words_packed[ 32*4 +: 32];
    wire [31:0] w5 = frame_words_packed[ 32*5 +: 32];
    wire [31:0] w6 = frame_words_packed[ 32*6 +: 32];
    wire [31:0] w7 = frame_words_packed[ 32*7 +: 32];
    wire [31:0] w8 = frame_words_packed[ 32*8 +: 32];

    assign status_word = w0;

    assign ch0 = sx_to_32(w1);
    assign ch1 = sx_to_32(w2);
    assign ch2 = sx_to_32(w3);
    assign ch3 = sx_to_32(w4);
    assign ch4 = sx_to_32(w5);
    assign ch5 = sx_to_32(w6);
    assign ch6 = sx_to_32(w7);
    assign ch7 = sx_to_32(w8);

endmodule

`default_nettype wire
