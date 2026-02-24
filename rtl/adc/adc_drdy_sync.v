// adc_drdy_sync.v
//
// Synchronize an asynchronous active-low DRDY signal into `clk` domain
// and emit a single-cycle pulse on each falling edge (data-ready).
//
// v1 intent: used for ADS131M08-like ADCs where DRDY paces frames.
//
// Reset / bring-up nuance:
// If the external DRDY pin is held low during reset, a naive edge-detector
// will often emit a "fake" falling-edge pulse right after reset deasserts
// (because the synchronizer flops reset to 1, then sample 0).
//
// Policy (v1): only emit pulses *after* we've observed DRDY high at least once
// post-reset (i.e., the edge detector is "armed").

`default_nettype none

module adc_drdy_sync (
    input  wire clk,
    input  wire rst,

    input  wire adc_drdy_n_async,

    output wire drdy_fall_pulse
);

    // 2-flop synchronizer (treat DRDY as asynchronous)
    reg drdy_meta;
    reg drdy_sync;

    // previous synced value for edge detection
    reg drdy_sync_d;

    // Armed once we've seen DRDY high after reset.
    reg armed;

    // Warmup cycles after reset deassert, to avoid "arming" based solely on
    // reset-initialized flop values.
    reg [1:0] warmup;

    always @(posedge clk) begin
        if (rst) begin
            drdy_meta   <= 1'b1;
            drdy_sync   <= 1'b1;
            drdy_sync_d <= 1'b1;
            armed       <= 1'b0;
            warmup      <= 2'd2;
        end else begin
            drdy_meta   <= adc_drdy_n_async;
            drdy_sync   <= drdy_meta;
            drdy_sync_d <= drdy_sync;

            if (warmup != 2'd0) begin
                warmup <= warmup - 2'd1;
            end else begin
                // Arm once we have observed an inactive-high level after warmup.
                if (!armed && (drdy_sync == 1'b1)) begin
                    armed <= 1'b1;
                end
            end
        end
    end

    // Falling edge detect (1 -> 0), gated by warmup+"armed".
    assign drdy_fall_pulse = (warmup == 2'd0) && armed && (drdy_sync_d == 1'b1) && (drdy_sync == 1'b0);

endmodule

`default_nettype wire
