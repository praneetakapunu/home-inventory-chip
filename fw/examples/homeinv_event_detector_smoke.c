// homeinv_event_detector_smoke.c
//
// Minimal bring-up snippet for the Home Inventory chip event detector registers.
//
// Demonstrates:
// - enabling event detection on a channel
// - programming an event threshold
// - triggering a sample update via ADC_CMD.SNAPSHOT (current RTL stub)
// - reading EVT_COUNT / EVT_LAST_DELTA / EVT_LAST_TS
//
// This file is intentionally SDK-agnostic; you must provide the correct base
// address for your platform/harness.

#include <stdint.h>

#include "../include/home_inventory_regmap.h"

// -----------------------------------------------------------------------------
// Platform glue (adjust as needed)
// -----------------------------------------------------------------------------
#ifndef HOMEINV_BASE
// TODO: Set this to the user project base address for your platform.
// Common Caravel harnesses map user project Wishbone at 0x3000_0000, but do not
// assume; confirm in the harness repository.
#define HOMEINV_BASE (0x30000000u)
#endif

static inline void mmio_write32(uint32_t addr, uint32_t v) {
    *(volatile uint32_t *)addr = v;
}

static inline uint32_t mmio_read32(uint32_t addr) {
    return *(volatile uint32_t *)addr;
}

static inline uint32_t homeinv_read(uint32_t off) {
    return mmio_read32(HOMEINV_BASE + off);
}

static inline void homeinv_write(uint32_t off, uint32_t v) {
    mmio_write32(HOMEINV_BASE + off, v);
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
static inline void adc_snapshot(void) {
    // In the current RTL, SNAPSHOT also drives the event detector sample_valid.
    homeinv_write(HOMEINV_REG_ADC_CMD, HOMEINV_ADC_CMD_SNAPSHOT_MASK);
}

// -----------------------------------------------------------------------------
// Example entrypoint
// -----------------------------------------------------------------------------
// Call this from your platform's main() once UART/logging is set up.
// (This file intentionally does not include any print routines.)
void homeinv_example_event_detector_smoke(void) {
    // 1) Optional: enable chip block (CTRL.ENABLE)
    uint32_t ctrl = homeinv_read(HOMEINV_REG_CTRL);
    ctrl |= HOMEINV_CTRL_ENABLE_MASK;
    homeinv_write(HOMEINV_REG_CTRL, ctrl);

    // 2) Configure: enable events on CH0, threshold below the stub sample
    //
    // Current RTL stub sample for CH0 on the Nth snapshot is:
    //   0x0000_1000 + (snapshot_count+1) + 0
    // So a threshold of 0x0000_1000 guarantees a hit on every snapshot.
    homeinv_write(HOMEINV_REG_EVT_THRESH_CH0, 0x00001000u);
    homeinv_write(HOMEINV_REG_EVT_CFG, 0x00000001u); // EVT_EN[0]=1

    // 3) Trigger two snapshots so we can observe count increment + delta update.
    adc_snapshot();
    adc_snapshot();

    // 4) Read back state (caller should print/log these values)
    uint32_t c0   = homeinv_read(HOMEINV_REG_EVT_COUNT_CH0);
    uint32_t d0   = homeinv_read(HOMEINV_REG_EVT_LAST_DELTA_CH0);
    uint32_t ts_g = homeinv_read(HOMEINV_REG_EVT_LAST_TS);
    uint32_t ts0  = homeinv_read(HOMEINV_REG_EVT_LAST_TS_CH0);

    // TODO: print/log c0, d0, ts_g, ts0.
    (void)c0;
    (void)d0;
    (void)ts_g;
    (void)ts0;
}
