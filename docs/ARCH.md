# Architecture (v1) — Home Inventory Chip

This is the top-level architecture snapshot for the v1 tapeout.

## Block diagram (logical)

```
           +-------------------------------+
           |           Host / MCU          |
           | (Wishbone master via Caravel) |
           +---------------+---------------+
                           |
                           | Wishbone
                           v
+--------------------------+--------------------------+
|                 home_inventory_top                  |
|                                                      |
|  +------------------+     +-----------------------+  |
|  | Wishbone regbank |<--->|  ADC capture + FIFO   |  |
|  | (control/status) |     | (DRDY sync, packer)   |  |
|  +------------------+     +-----------------------+  |
|             |                          |             |
|             |                          v             |
|             |                +------------------+    |
|             |                | Event detector   |    |
|             |                | (delta + time)   |    |
|             |                +------------------+    |
|             |                                          
+-------------+----------------------------------------+
              |
              | SPI (to external ADC)
              v
        +-----------+
        | ADS131M08 |
        +-----------+
```

## External interfaces

### Wishbone
- File: `rtl/home_inventory_wb.v`
- Address map: `spec/regmap.md` (generated YAML: `spec/regmap_v1.yaml`)
- Policy notes:
  - `ack` behavior: must not deadlock.
  - Byte enables: document supported policy (see `docs/CDC_RESET_CHECKLIST.md`).

### ADC SPI (ADS131M08)
- Interface contract: `spec/ads131m08_interface.md`
- Assumptions:
  - DRDY is treated as async and is synchronized before edge detect.
  - Frame packing is 32-bit words into a FIFO exposed over Wishbone.

## Clocks and resets

- Clock domain plan: track in `docs/CDC_RESET_CHECKLIST.md`.
- Goal for v1: minimize domains (prefer 1 clock where feasible).

## RTL structure (current)

- `rtl/home_inventory_top.v` — top-level wrapper
- `rtl/home_inventory_wb.v` — Wishbone regbank
- `rtl/adc/*` — ADC capture + DRDY sync + FIFO

## Verification hooks

- Regmap consistency gate: `make -C verify regmap-check`
- Smoke DV: directed cocotb tests in harness repo.

## Open items

- Finalize event detector RTL and its exact observability surface in regmap.
- Lock byte-enable policy and document it in regmap + limitations.
