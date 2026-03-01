// adc_soc_frame_unpack_tb.v
//
// Directed smoke test for adc_soc_frame_unpack:
// - word indexing STATUS + CH0..CH7
// - sign-extension behavior for 24-bit samples

`timescale 1ns/1ps
`default_nettype none

module adc_soc_frame_unpack_tb;

    localparam int unsigned WORDS = 10;

    reg  [32*WORDS-1:0] frame_words_packed;
    wire [31:0] status_word;
    wire [31:0] ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7;

    adc_soc_frame_unpack #(
        .BITS_PER_WORD(24),
        .WORDS_PER_FRAME(WORDS)
    ) dut (
        .frame_words_packed(frame_words_packed),
        .status_word(status_word),
        .ch0(ch0), .ch1(ch1), .ch2(ch2), .ch3(ch3),
        .ch4(ch4), .ch5(ch5), .ch6(ch6), .ch7(ch7)
    );

    task automatic expect32(input [31:0] got, input [31:0] exp, input [1023:0] msg);
        begin
            if (got !== exp) begin
                $display("FAIL: %0s got=0x%08x exp=0x%08x", msg, got, exp);
                $finish;
            end
        end
    endtask

    initial begin
        $display("adc_soc_frame_unpack_tb: start");

        // Pack words: word0 at [31:0], word1 at [63:32], etc.
        frame_words_packed = '0;

        // STATUS
        frame_words_packed[ 32*0 +: 32] = 32'hA5A5_5A5A;

        // CH0..CH7 in low 24 bits. Mix positive and negative to test sign-ext.
        frame_words_packed[ 32*1 +: 32] = 32'h0000_0001; // +1
        frame_words_packed[ 32*2 +: 32] = 32'h0000_7FFF; // +0x7FFF
        frame_words_packed[ 32*3 +: 32] = 32'h0000_8000; // +0x8000
        frame_words_packed[ 32*4 +: 32] = 32'h0000_FFFF; // +0xFFFF

        frame_words_packed[ 32*5 +: 32] = 32'h0080_0000; // -0x800000 in 24b
        frame_words_packed[ 32*6 +: 32] = 32'h00FF_FFFF; // -1 in 24b
        frame_words_packed[ 32*7 +: 32] = 32'h0090_0000; // negative pattern in 24b
        frame_words_packed[ 32*8 +: 32] = 32'h0000_0000; // 0

        #1;

        expect32(status_word, 32'hA5A5_5A5A, "status");

        expect32(ch0, 32'h0000_0001, "ch0");
        expect32(ch1, 32'h0000_7FFF, "ch1");
        expect32(ch2, 32'h0000_8000, "ch2");
        expect32(ch3, 32'h0000_FFFF, "ch3");

        // 24-bit sign extension expectations:
        // 0x800000 -> 0xFF800000
        // 0xFFFFFF -> 0xFFFFFFFF
        // 0x900000 -> 0xFF900000
        expect32(ch4, 32'hFF80_0000, "ch4 sign-ext");
        expect32(ch5, 32'hFFFF_FFFF, "ch5 sign-ext -1");
        expect32(ch6, 32'hFF90_0000, "ch6 sign-ext");
        expect32(ch7, 32'h0000_0000, "ch7");

        $display("adc_soc_frame_unpack_tb: PASS");
        $finish;
    end

endmodule

`default_nettype wire
