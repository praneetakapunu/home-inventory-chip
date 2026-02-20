# Wishbone Integration Notes (Caravel / OpenMPW)

This doc is the *practical* contract for talking to `rtl/home_inventory_wb.v` from:
- the OpenMPW harness wrapper (`user_project_wrapper.v`),
- cocotb smoke tests, and
- firmware running on the Caravel management core.

It complements (does not replace) the canonical register map:
- `spec/regmap.md` (human-readable)
- `spec/regmap_v1.yaml` (single source-of-truth)

## 1) Bus basics

Module: `home_inventory_wb`

- **Clock:** `wb_clk_i`
- **Reset:** `wb_rst_i` (active-high)
- **Handshake:** classic Wishbone single-cycle ACK pulse

Notes:
- `wbs_ack_o` is asserted as a **one-cycle pulse per request**.
- The block is intended to be used with a simple master that waits for `ack`.

## 2) Addressing rules

- **Addresses are byte addresses** (Wishbone convention).
- Internally, the block **aligns** the address to a 32-bit boundary:

```verilog
wb_adr_aligned = {wbs_adr_i[31:2], 2'b00};
```

So:
- `0x0000_0000`, `0x0000_0001`, `0x0000_0002`, `0x0000_0003` all target the same 32-bit register.
- Software should still use word-aligned addresses for clarity.

## 3) Byte enables (`wbs_sel_i`)

- Writes should use `wbs_sel_i` to indicate which byte lanes are valid.
- Multi-byte writes are supported.
- Some fields are **lane-sensitive** (see W1C below).

## 4) Special write semantics

### 4.1 CTRL.START is write-1-to-pulse

Register: `ADR_CTRL`

- `CTRL.ENABLE` is sticky RW.
- `CTRL.START` is **write-1-to-pulse**, not sticky, and is not readable.

Implementation detail:
- The pulse (`ctrl_start`) is generated **one cycle after** the Wishbone write is accepted.

### 4.2 ADC_CMD.SNAPSHOT is write-1-to-pulse

Register: `ADR_ADC_CMD`

- Writing bit[0]=1 triggers a snapshot behavior (currently a stub that updates raw regs and pushes a synthetic frame into the FIFO).

### 4.3 ADC_FIFO_STATUS.OVERRUN is W1C (write-1-to-clear)

Register: `ADR_ADC_FIFO_STATUS`

- `OVERRUN` is bit[16] and is **W1C**.
- Because this bit lives in byte lane 2, clearing it requires:
  - `wbs_sel_i[2] = 1` **and**
  - `wbs_dat_i[16] = 1`

This is intentional: it matches realistic bus behavior and prevents accidental clears from byte-lane writes.

## 5) FIFO read behavior

Register: `ADR_ADC_FIFO_DATA`

- Reading pops one word *if the FIFO is non-empty*.
- If empty, read returns `0` and does not change pointers.

The FIFO frame packing (current stub) is:
- status word
- CH0..CH7 words

## 6) Recommended DV smoke sequence

A minimal cocotb or firmware sanity should:

1. Read `ID` and `VERSION`.
2. Write `CTRL.ENABLE=1`.
3. Trigger a snapshot (`ADC_CMD.SNAPSHOT=1`).
4. Read `ADC_RAW_CH0..CH7` and confirm they change across snapshots.
5. Read `ADC_FIFO_STATUS` and drain `ADC_FIFO_DATA` until empty.
6. Force/observe `OVERRUN` if you fill the FIFO (optional), then clear it using the lane-correct W1C write.

## 7) Known limitations

- ADC capture is **stubbed** until the ADS131M08 SPI capture module is implemented.
- IRQ behavior is not wired end-to-end yet (reg exists; top-level integration pending).
