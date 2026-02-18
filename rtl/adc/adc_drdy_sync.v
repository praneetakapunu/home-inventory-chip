// adc_drdy_sync.v
//
// Synchronize an asynchronous active-low DRDY signal into `clk` domain
// and emit a single-cycle pulse on each falling edge (data-ready).
//
// v1 intent: used for ADS131M08-like ADCs where DRDY paces frames.

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

    always @(posedge clk) begin
        if (rst) begin
            drdy_meta   <= 1'b1;
            drdy_sync   <= 1'b1;
            drdy_sync_d <= 1'b1;
        end else begin
            drdy_meta   <= adc_drdy_n_async;
            drdy_sync   <= drdy_meta;
            drdy_sync_d <= drdy_sync;
        end
    end

    // Falling edge detect (1 -> 0)
    assign drdy_fall_pulse = (drdy_sync_d == 1'b1) && (drdy_sync == 1'b0);

endmodule

`default_nettype wire
