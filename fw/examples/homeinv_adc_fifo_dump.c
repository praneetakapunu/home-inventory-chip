// homeinv_adc_fifo_dump.c
//
// Minimal bring-up snippet for the Home Inventory chip Wishbone register block.
//
// Demonstrates:
// - clearing FIFO overrun (W1C)
// - triggering a capture (ADC_CMD.SNAPSHOT for stub builds, or CTRL.START for real ingest)
// - waiting for CAPTURE_BUSY (when applicable)
// - draining ADC_FIFO_DATA until ADC_FIFO_STATUS.LEVEL_WORDS==0
//
// This file is intentionally SDK-agnostic; you must provide the correct base
// address for your platform/harness.

#include <stdint.h>
#include <stddef.h>

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
static inline uint16_t adc_fifo_level_words(uint32_t st) {
    return (uint16_t)((st & HOMEINV_ADC_FIFO_STATUS_LEVEL_WORDS_MASK) >> HOMEINV_ADC_FIFO_STATUS_LEVEL_WORDS_SHIFT);
}

static inline uint8_t adc_fifo_overrun(uint32_t st) {
    return (uint8_t)((st & HOMEINV_ADC_FIFO_STATUS_OVERRUN_MASK) ? 1u : 0u);
}

static inline uint8_t adc_fifo_capture_busy(uint32_t st) {
    return (uint8_t)((st & HOMEINV_ADC_FIFO_STATUS_CAPTURE_BUSY_MASK) ? 1u : 0u);
}

// Clear the OVERRUN sticky flag (write-1-to-clear OVERRUN).
static inline void adc_fifo_clear_overrun(void) {
    homeinv_write(HOMEINV_REG_ADC_FIFO_STATUS, HOMEINV_ADC_FIFO_STATUS_OVERRUN_MASK);
}

// Trigger a stub "snapshot" capture via write-1-to-pulse.
static inline void adc_snapshot(void) {
    homeinv_write(HOMEINV_REG_ADC_CMD, HOMEINV_ADC_CMD_SNAPSHOT_MASK);
}

// Trigger a real ADC ingest capture (USE_REAL_ADC_INGEST build) via CTRL.START (W1P).
static inline void adc_start_capture(void) {
    // START is W1P; don't RMW CTRL (reserved bits may exist). Just write the pulse bit.
    homeinv_write(HOMEINV_REG_CTRL, HOMEINV_CTRL_START_MASK);
}

// Drain FIFO into a caller-provided buffer.
// Returns number of 32-bit words written.
static size_t adc_fifo_drain(uint32_t *out_words, size_t max_words) {
    size_t n = 0;

    while (n < max_words) {
        uint32_t st = homeinv_read(HOMEINV_REG_ADC_FIFO_STATUS);
        uint16_t level = adc_fifo_level_words(st);
        if (level == 0) break;

        // Reading ADC_FIFO_DATA pops one word when the FIFO is non-empty.
        out_words[n++] = homeinv_read(HOMEINV_REG_ADC_FIFO_DATA);
    }

    return n;
}

// Wait (with a bounded spin) for CAPTURE_BUSY to assert at least once and then deassert.
// This helps firmware avoid racing on slow SPI capture.
static int adc_wait_capture_done(uint32_t timeout_iters) {
    uint32_t i;
    uint8_t saw_busy = 0u;

    for (i = 0; i < timeout_iters; i++) {
        uint32_t st = homeinv_read(HOMEINV_REG_ADC_FIFO_STATUS);
        if (adc_fifo_capture_busy(st)) {
            saw_busy = 1u;
        } else if (saw_busy) {
            // We saw busy high before, and now it's low.
            return 0;
        }
    }

    return -1;
}

// -----------------------------------------------------------------------------
// Example entrypoint
// -----------------------------------------------------------------------------
// Call this from your platform's main() once UART/logging is set up.
// (This file intentionally does not include any print routines.)
void homeinv_example_adc_fifo_dump(void) {
    // 1) Optional: enable chip block (CTRL.ENABLE)
    // ENABLE is a normal R/W bit.
    uint32_t ctrl = homeinv_read(HOMEINV_REG_CTRL);
    ctrl |= HOMEINV_CTRL_ENABLE_MASK;
    homeinv_write(HOMEINV_REG_CTRL, ctrl);

    // 2) Clear overrun before starting
    if (adc_fifo_overrun(homeinv_read(HOMEINV_REG_ADC_FIFO_STATUS))) {
        adc_fifo_clear_overrun();
    }

    // 3) Trigger a capture.
    // - Stub path: ADC_CMD.SNAPSHOT pushes 9 words (STATUS + CH0..CH7) via RTL helper.
    // - Real ingest path: CTRL.START kicks off SPI capture, which will push 9 words.
#ifdef USE_REAL_ADC_INGEST
    adc_start_capture();

    // Wait for capture to complete. If this times out on real silicon,
    // investigate SPI wiring/clocking or decrease the timeout for your CPU speed.
    (void)adc_wait_capture_done(200000u);
#else
    adc_snapshot();
#endif

    // 4) Drain FIFO (caller can decode frames; see fw/tools/decode_adc_fifo.py)
    uint32_t words[64];
    size_t n = adc_fifo_drain(words, sizeof(words) / sizeof(words[0]));

    // TODO: print/log `n` and `words[]` using your platform logging.
    (void)n;
    (void)words;

    // 5) If overrun set, clear + investigate drain loop speed.
    if (adc_fifo_overrun(homeinv_read(HOMEINV_REG_ADC_FIFO_STATUS))) {
        adc_fifo_clear_overrun();
    }
}
