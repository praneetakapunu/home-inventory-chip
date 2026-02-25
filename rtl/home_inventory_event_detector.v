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
    reg [7:0] en_rise_pending;

    // Track whether each channel has ever fired since reset or since the last 0->1 enable.
    // This avoids using last_ts_ch==0 as a sentinel (ts_now could legitimately be 0).
    reg [7:0] seen_event;

    // Helper: saturating increment
    function automatic [31:0] sat_inc32(input [31:0] v);
        begin
            sat_inc32 = (v == 32'hFFFF_FFFF) ? 32'hFFFF_FFFF : (v + 32'h1);
        end
    endfunction

    // Per-channel hit signals (used only when sample_valid=1).
    wire hit0 = evt_en[0] && (sample_ch0 >= thresh_ch0);
    wire hit1 = evt_en[1] && (sample_ch1 >= thresh_ch1);
    wire hit2 = evt_en[2] && (sample_ch2 >= thresh_ch2);
    wire hit3 = evt_en[3] && (sample_ch3 >= thresh_ch3);
    wire hit4 = evt_en[4] && (sample_ch4 >= thresh_ch4);
    wire hit5 = evt_en[5] && (sample_ch5 >= thresh_ch5);
    wire hit6 = evt_en[6] && (sample_ch6 >= thresh_ch6);
    wire hit7 = evt_en[7] && (sample_ch7 >= thresh_ch7);

    always @(posedge clk) begin
        if (rst) begin
            prev_evt_en     <= 8'h00;
            en_rise_pending <= 8'h00;
            seen_event      <= 8'h00;

            evt_count_ch0 <= 32'h0; evt_count_ch1 <= 32'h0; evt_count_ch2 <= 32'h0; evt_count_ch3 <= 32'h0;
            evt_count_ch4 <= 32'h0; evt_count_ch5 <= 32'h0; evt_count_ch6 <= 32'h0; evt_count_ch7 <= 32'h0;

            last_delta_ch0 <= 32'h0; last_delta_ch1 <= 32'h0; last_delta_ch2 <= 32'h0; last_delta_ch3 <= 32'h0;
            last_delta_ch4 <= 32'h0; last_delta_ch5 <= 32'h0; last_delta_ch6 <= 32'h0; last_delta_ch7 <= 32'h0;

            last_ts <= 32'h0;

            last_ts_ch0 <= 32'h0; last_ts_ch1 <= 32'h0; last_ts_ch2 <= 32'h0; last_ts_ch3 <= 32'h0;
            last_ts_ch4 <= 32'h0; last_ts_ch5 <= 32'h0; last_ts_ch6 <= 32'h0; last_ts_ch7 <= 32'h0;
        end else begin
            // Capture 0->1 enable edges even if sample_valid is not asserted that cycle.
            // We then apply the "clear history on enable" behavior on the next sample_valid.
            //
            // Important: if a channel is disabled before we ever consume a sample (evt_en
            // returns to 0), we must *not* keep a pending enable-rise around.
            begin : en_rise_track
                reg [7:0] en_rise_new;
                reg [7:0] en_rise_pending_next;

                en_rise_new          = (~prev_evt_en) & evt_en;
                en_rise_pending_next = (en_rise_pending | en_rise_new) & evt_en;

                if (sample_valid) begin
                    // Apply "enable-rise clears history" at the same sample boundary.
                    // If an enable-rise and a hit occur in the same sample, delta must be 0.

                    // ch0
                    if (en_rise_pending_next[0]) begin
                        seen_event[0]  <= 1'b0;
                        last_ts_ch0    <= 32'h0;
                        last_delta_ch0 <= 32'h0;
                    end
                    if (hit0) begin
                        evt_count_ch0  <= sat_inc32(evt_count_ch0);
                        last_delta_ch0 <= (en_rise_pending_next[0]) ? 32'h0 : (seen_event[0] ? (ts_now - last_ts_ch0) : 32'h0);
                        last_ts_ch0    <= ts_now;
                        seen_event[0]  <= 1'b1;
                    end

                    // ch1
                    if (en_rise_pending_next[1]) begin
                        seen_event[1]  <= 1'b0;
                        last_ts_ch1    <= 32'h0;
                        last_delta_ch1 <= 32'h0;
                    end
                    if (hit1) begin
                        evt_count_ch1  <= sat_inc32(evt_count_ch1);
                        last_delta_ch1 <= (en_rise_pending_next[1]) ? 32'h0 : (seen_event[1] ? (ts_now - last_ts_ch1) : 32'h0);
                        last_ts_ch1    <= ts_now;
                        seen_event[1]  <= 1'b1;
                    end

                    // ch2
                    if (en_rise_pending_next[2]) begin
                        seen_event[2]  <= 1'b0;
                        last_ts_ch2    <= 32'h0;
                        last_delta_ch2 <= 32'h0;
                    end
                    if (hit2) begin
                        evt_count_ch2  <= sat_inc32(evt_count_ch2);
                        last_delta_ch2 <= (en_rise_pending_next[2]) ? 32'h0 : (seen_event[2] ? (ts_now - last_ts_ch2) : 32'h0);
                        last_ts_ch2    <= ts_now;
                        seen_event[2]  <= 1'b1;
                    end

                    // ch3
                    if (en_rise_pending_next[3]) begin
                        seen_event[3]  <= 1'b0;
                        last_ts_ch3    <= 32'h0;
                        last_delta_ch3 <= 32'h0;
                    end
                    if (hit3) begin
                        evt_count_ch3  <= sat_inc32(evt_count_ch3);
                        last_delta_ch3 <= (en_rise_pending_next[3]) ? 32'h0 : (seen_event[3] ? (ts_now - last_ts_ch3) : 32'h0);
                        last_ts_ch3    <= ts_now;
                        seen_event[3]  <= 1'b1;
                    end

                    // ch4
                    if (en_rise_pending_next[4]) begin
                        seen_event[4]  <= 1'b0;
                        last_ts_ch4    <= 32'h0;
                        last_delta_ch4 <= 32'h0;
                    end
                    if (hit4) begin
                        evt_count_ch4  <= sat_inc32(evt_count_ch4);
                        last_delta_ch4 <= (en_rise_pending_next[4]) ? 32'h0 : (seen_event[4] ? (ts_now - last_ts_ch4) : 32'h0);
                        last_ts_ch4    <= ts_now;
                        seen_event[4]  <= 1'b1;
                    end

                    // ch5
                    if (en_rise_pending_next[5]) begin
                        seen_event[5]  <= 1'b0;
                        last_ts_ch5    <= 32'h0;
                        last_delta_ch5 <= 32'h0;
                    end
                    if (hit5) begin
                        evt_count_ch5  <= sat_inc32(evt_count_ch5);
                        last_delta_ch5 <= (en_rise_pending_next[5]) ? 32'h0 : (seen_event[5] ? (ts_now - last_ts_ch5) : 32'h0);
                        last_ts_ch5    <= ts_now;
                        seen_event[5]  <= 1'b1;
                    end

                    // ch6
                    if (en_rise_pending_next[6]) begin
                        seen_event[6]  <= 1'b0;
                        last_ts_ch6    <= 32'h0;
                        last_delta_ch6 <= 32'h0;
                    end
                    if (hit6) begin
                        evt_count_ch6  <= sat_inc32(evt_count_ch6);
                        last_delta_ch6 <= (en_rise_pending_next[6]) ? 32'h0 : (seen_event[6] ? (ts_now - last_ts_ch6) : 32'h0);
                        last_ts_ch6    <= ts_now;
                        seen_event[6]  <= 1'b1;
                    end

                    // ch7
                    if (en_rise_pending_next[7]) begin
                        seen_event[7]  <= 1'b0;
                        last_ts_ch7    <= 32'h0;
                        last_delta_ch7 <= 32'h0;
                    end
                    if (hit7) begin
                        evt_count_ch7  <= sat_inc32(evt_count_ch7);
                        last_delta_ch7 <= (en_rise_pending_next[7]) ? 32'h0 : (seen_event[7] ? (ts_now - last_ts_ch7) : 32'h0);
                        last_ts_ch7    <= ts_now;
                        seen_event[7]  <= 1'b1;
                    end

                    if (hit0 | hit1 | hit2 | hit3 | hit4 | hit5 | hit6 | hit7) begin
                        last_ts <= ts_now;
                    end

                    // Clear any pending enable-rises once we have consumed a sample while enabled.
                    en_rise_pending_next = en_rise_pending_next & ~evt_en;
                end

                en_rise_pending <= en_rise_pending_next;
            end

            prev_evt_en <= evt_en;
        end
    end

endmodule

`default_nettype wire
