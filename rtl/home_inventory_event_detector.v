// Home Inventory Chip - Event detector
//
// Purpose: given per-channel samples + thresholds + enable bits, produce:
// - Saturating event counters
// - LAST_DELTA per channel (timestamp delta between events)
// - LAST_TS global (timestamp of most recent event across any channel)
// - LAST_TS per channel
//
// Timestamp semantics:
// - ts_now is provided by the upstream sample source and must be monotonic.
// - If a channel's first event occurs after reset OR after a 0->1 enable,
//   last_delta is defined as 0.
//
// This module is intentionally independent of the ADC implementation: it can
// be driven by stub snapshot samples during bring-up and later by the real ADC
// capture pipeline.

`default_nettype none

module home_inventory_event_detector (
    input  wire        clk,
    input  wire        rst,

    input  wire        sample_valid,
    input  wire [31:0] ts_now,

    input  wire [7:0]  evt_en,

    input  wire [31:0] thresh_ch0,
    input  wire [31:0] thresh_ch1,
    input  wire [31:0] thresh_ch2,
    input  wire [31:0] thresh_ch3,
    input  wire [31:0] thresh_ch4,
    input  wire [31:0] thresh_ch5,
    input  wire [31:0] thresh_ch6,
    input  wire [31:0] thresh_ch7,

    input  wire [31:0] sample_ch0,
    input  wire [31:0] sample_ch1,
    input  wire [31:0] sample_ch2,
    input  wire [31:0] sample_ch3,
    input  wire [31:0] sample_ch4,
    input  wire [31:0] sample_ch5,
    input  wire [31:0] sample_ch6,
    input  wire [31:0] sample_ch7,

    output reg  [31:0] evt_count_ch0,
    output reg  [31:0] evt_count_ch1,
    output reg  [31:0] evt_count_ch2,
    output reg  [31:0] evt_count_ch3,
    output reg  [31:0] evt_count_ch4,
    output reg  [31:0] evt_count_ch5,
    output reg  [31:0] evt_count_ch6,
    output reg  [31:0] evt_count_ch7,

    output reg  [31:0] last_delta_ch0,
    output reg  [31:0] last_delta_ch1,
    output reg  [31:0] last_delta_ch2,
    output reg  [31:0] last_delta_ch3,
    output reg  [31:0] last_delta_ch4,
    output reg  [31:0] last_delta_ch5,
    output reg  [31:0] last_delta_ch6,
    output reg  [31:0] last_delta_ch7,

    output reg  [31:0] last_ts,

    output reg  [31:0] last_ts_ch0,
    output reg  [31:0] last_ts_ch1,
    output reg  [31:0] last_ts_ch2,
    output reg  [31:0] last_ts_ch3,
    output reg  [31:0] last_ts_ch4,
    output reg  [31:0] last_ts_ch5,
    output reg  [31:0] last_ts_ch6,
    output reg  [31:0] last_ts_ch7
);

    reg [7:0] prev_evt_en;

    reg f0, f1, f2, f3, f4, f5, f6, f7;
    reg any_event;

    // Helper: saturating increment
    function automatic [31:0] sat_inc32(input [31:0] v);
        begin
            sat_inc32 = (v == 32'hFFFF_FFFF) ? 32'hFFFF_FFFF : (v + 32'h1);
        end
    endfunction

    // Helper: update one channel
    task automatic update_ch(
        input        en,
        input        en_rise,
        input [31:0] sample,
        input [31:0] thresh,
        inout [31:0] count,
        inout [31:0] last_delta,
        inout [31:0] last_ts_ch,
        output reg         fired
    );
        reg hit;
        begin
            hit = en && (sample >= thresh);
            if (en_rise) begin
                // On enable rising edge, clear history so the next event reports delta=0.
                last_ts_ch = 32'h0;
                last_delta = 32'h0;
            end

            if (hit) begin
                count = sat_inc32(count);
                if (last_ts_ch == 32'h0) begin
                    last_delta = 32'h0;
                end else begin
                    last_delta = ts_now - last_ts_ch;
                end
                last_ts_ch = ts_now;
            end
            fired = hit;
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            prev_evt_en <= 8'h00;

            evt_count_ch0 <= 32'h0; evt_count_ch1 <= 32'h0; evt_count_ch2 <= 32'h0; evt_count_ch3 <= 32'h0;
            evt_count_ch4 <= 32'h0; evt_count_ch5 <= 32'h0; evt_count_ch6 <= 32'h0; evt_count_ch7 <= 32'h0;

            last_delta_ch0 <= 32'h0; last_delta_ch1 <= 32'h0; last_delta_ch2 <= 32'h0; last_delta_ch3 <= 32'h0;
            last_delta_ch4 <= 32'h0; last_delta_ch5 <= 32'h0; last_delta_ch6 <= 32'h0; last_delta_ch7 <= 32'h0;

            last_ts <= 32'h0;

            last_ts_ch0 <= 32'h0; last_ts_ch1 <= 32'h0; last_ts_ch2 <= 32'h0; last_ts_ch3 <= 32'h0;
            last_ts_ch4 <= 32'h0; last_ts_ch5 <= 32'h0; last_ts_ch6 <= 32'h0; last_ts_ch7 <= 32'h0;
        end else begin
            prev_evt_en <= evt_en;

            if (sample_valid) begin
                any_event = 1'b0;

                update_ch(evt_en[0], (~prev_evt_en[0] & evt_en[0]), sample_ch0, thresh_ch0,
                          evt_count_ch0, last_delta_ch0, last_ts_ch0, f0);
                update_ch(evt_en[1], (~prev_evt_en[1] & evt_en[1]), sample_ch1, thresh_ch1,
                          evt_count_ch1, last_delta_ch1, last_ts_ch1, f1);
                update_ch(evt_en[2], (~prev_evt_en[2] & evt_en[2]), sample_ch2, thresh_ch2,
                          evt_count_ch2, last_delta_ch2, last_ts_ch2, f2);
                update_ch(evt_en[3], (~prev_evt_en[3] & evt_en[3]), sample_ch3, thresh_ch3,
                          evt_count_ch3, last_delta_ch3, last_ts_ch3, f3);
                update_ch(evt_en[4], (~prev_evt_en[4] & evt_en[4]), sample_ch4, thresh_ch4,
                          evt_count_ch4, last_delta_ch4, last_ts_ch4, f4);
                update_ch(evt_en[5], (~prev_evt_en[5] & evt_en[5]), sample_ch5, thresh_ch5,
                          evt_count_ch5, last_delta_ch5, last_ts_ch5, f5);
                update_ch(evt_en[6], (~prev_evt_en[6] & evt_en[6]), sample_ch6, thresh_ch6,
                          evt_count_ch6, last_delta_ch6, last_ts_ch6, f6);
                update_ch(evt_en[7], (~prev_evt_en[7] & evt_en[7]), sample_ch7, thresh_ch7,
                          evt_count_ch7, last_delta_ch7, last_ts_ch7, f7);

                any_event = f0|f1|f2|f3|f4|f5|f6|f7;
                if (any_event) begin
                    last_ts <= ts_now;
                end
            end
        end
    end

endmodule

`default_nettype wire
