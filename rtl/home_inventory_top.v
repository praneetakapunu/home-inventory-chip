// Home Inventory Chip - top-level RTL (initial skeleton)

`default_nettype none

module home_inventory_top (
    input  wire        clk,
    input  wire        rst,

    // ADC interface (placeholder)
    output wire        adc_sck,
    output wire        adc_csn,
    output wire        adc_mosi,
    input  wire        adc_miso,

    // Simple debug/status
    output wire [7:0]  status
);

    // TODO: implement register map + ADC sampling + event detection.
    assign adc_sck  = 1'b0;
    assign adc_csn  = 1'b1;
    assign adc_mosi = 1'b0;
    assign status   = 8'h00;

endmodule

`default_nettype wire
