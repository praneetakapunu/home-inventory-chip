// adc_spi_frame_capture_stub.v
//
// v1 stub for a framed SPI capture block intended for ADS131M08-like ADCs.
// This is deliberately a *non-functional placeholder* that defines the interface
// contract so other RTL/DV can be wired up without blocking on datasheet-level
// details (SPI mode, word alignment, STATUS/CRC presence).
//
// When implementing:
// - keep framing parameterized (words/word-width)
// - sample MISO edge selectable (CPOL/CPHA)
// - produce a clean `frame_valid` pulse + an array of 32-bit right-justified words

`default_nettype none

module adc_spi_frame_capture_stub #(
    parameter int BITS_PER_WORD   = 24,
    parameter int WORDS_PER_FRAME = 9
) (
    input  wire                         clk,
    input  wire                         rst,

    // Start capture for one frame (pulse)
    input  wire                         start,

    // SPI pins (direction is from our SoC perspective)
    output wire                         adc_sclk,
    output wire                         adc_cs_n,
    output wire                         adc_mosi,
    input  wire                         adc_miso,

    // Frame result
    output wire                         frame_valid,
    output wire [32*WORDS_PER_FRAME-1:0] frame_words_packed,

    output wire                         busy
);

    // Stub behavior: drive safe idle values and never assert valid.
    // This keeps synthesis/sim clean until the real implementation lands.
    assign adc_sclk = 1'b0;
    assign adc_cs_n = 1'b1;
    assign adc_mosi = 1'b0;

    assign frame_valid       = 1'b0;
    assign frame_words_packed = { (32*WORDS_PER_FRAME){1'b0} };
    assign busy              = 1'b0;

    // TODO(implementation):
    // - generate adc_sclk/cs_n sequence on `start`
    // - shift in `BITS_PER_WORD` x `WORDS_PER_FRAME` bits from adc_miso
    // - right-justify each word into 32b slots in frame_words_packed
    // - assert frame_valid for 1 clk when all words are captured

endmodule

`default_nettype wire
