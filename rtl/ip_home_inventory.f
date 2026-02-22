# Canonical RTL filelist for the Home Inventory IP (chip-inventory)
# Paths are relative to the chip-inventory repo root.
#
# Harness repo should either:
#   (a) maintain its own filelist that mirrors this one, OR
#   (b) generate a harness-relative filelist by prefixing each line with:
#       ip/home-inventory-chip/

rtl/include/home_inventory_regmap_pkg.sv
rtl/include/regmap_params.vh

rtl/home_inventory_wb.v
rtl/home_inventory_event_detector.v
rtl/adc/adc_drdy_sync.v
rtl/adc/adc_stream_fifo.v
rtl/adc/adc_spi_frame_capture.v
rtl/home_inventory_top.v
