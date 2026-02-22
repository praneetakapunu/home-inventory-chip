// homeinv_adc_fifo_dump.c
//
// Minimal bring-up snippet for the Home Inventory chip Wishbone register block.
//
// Demonstrates:
// - clearing FIFO overrun (W1C)
// - issuing ADC_CMD.SNAPSHOT
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
// ADC_FIFO_STATUS layout (from regmap):
// - LEVEL_WORDS: [15:0]
// - OVERRUN:     [16] (sticky, W1C)
static inline uint16_t adc_fifo_level_words(uint32_t st) {
    return (uint16_t)(st & 0xFFFFu);
}

static inline uint8_t adc_fifo_overrun(uint32_t st) {
    return (uint8_t)((st >> 16) & 0x1u);
}

// Clear the OVERRUN sticky flag (write-1-to-clear bit[16]).
// NOTE: Bit[16] is in byte lane 2; the RTL respects byte enables. Most FW
// MMIO writes are full-word, so this is fine.
static inline void adc_fifo_clear_overrun(void) {
    homeinv_write(HOMEINV_ADC_FIFO_STATUS, (1u << 16));
}

// Trigger a stub "snapshot" (or later, a real capture) via write-1-to-pulse.
static inline void adc_snapshot(void) {
    homeinv_write(HOMEINV_ADC_CMD, HOMEINV_ADC_CMD_SNAPSHOT_MASK);
}

// Drain FIFO into a caller-provided buffer.
// Returns number of 32-bit words written.
static size_t adc_fifo_drain(uint32_t *out_words, size_t max_words) {
    size_t n = 0;

    while (n < max_words) {
        uint32_t st = homeinv_read(HOMEINV_ADC_FIFO_STATUS);
        uint16_t level = adc_fifo_level_words(st);
        if (level == 0) break;

        out_words[n++] = homeinv_read(HOMEINV_ADC_FIFO_DATA);
    }

    return n;
}

// -----------------------------------------------------------------------------
// Example entrypoint
// -----------------------------------------------------------------------------
// Call this from your platform's main() once UART/logging is set up.
// (This file intentionally does not include any print routines.)
void homeinv_example_adc_fifo_dump(void) {
    // 1) Optional: enable chip block (CTRL.ENABLE)
    uint32_t ctrl = homeinv_read(HOMEINV_CTRL);
    ctrl |= HOMEINV_CTRL_ENABLE_MASK;
    homeinv_write(HOMEINV_CTRL, ctrl);

    // 2) Clear overrun before starting
    if (adc_fifo_overrun(homeinv_read(HOMEINV_ADC_FIFO_STATUS))) {
        adc_fifo_clear_overrun();
    }

    // 3) Trigger a snapshot. In the current RTL stub, this pushes 9 words:
    //    STATUS_WORD + CH0..CH7.
    adc_snapshot();

    // 4) Drain FIFO (caller can decode frames; see fw/tools/decode_adc_fifo.py)
    uint32_t words[64];
    size_t n = adc_fifo_drain(words, sizeof(words) / sizeof(words[0]));

    // TODO: print/log `n` and `words[]` using your platform logging.
    (void)n;
    (void)words;

    // 5) If overrun set, clear + investigate drain loop speed.
    if (adc_fifo_overrun(homeinv_read(HOMEINV_ADC_FIFO_STATUS))) {
        adc_fifo_clear_overrun();
    }
}
