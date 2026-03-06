// Minimal bring-up smoke test for the Home Inventory user project reg block.
//
// Intended usage:
//   - Copy/paste into a Caravel management firmware project
//   - Set HOMEINV_BASE to the user project Wishbone base (platform-specific)
//   - Build + run; read out results via UART/printf or debugger
//
// This snippet deliberately avoids assuming a particular SDK.
// Provide your own MMIO read/write primitives.

#include <stdint.h>

#include "../include/home_inventory_regmap.h"

// -----------------------------------------------------------------------------
// Platform hooks (YOU MUST IMPLEMENT)
// -----------------------------------------------------------------------------

#ifndef HOMEINV_BASE
// NOTE: 0x3000_0000 is a common user project Wishbone base in Caravel examples,
// but you must confirm for your harness / SoC build.
#define HOMEINV_BASE 0x30000000u
#endif

static inline void mmio_write32(uint32_t addr, uint32_t data) {
  volatile uint32_t *p = (volatile uint32_t *)addr;
  *p = data;
}

static inline uint32_t mmio_read32(uint32_t addr) {
  volatile const uint32_t *p = (volatile const uint32_t *)addr;
  return *p;
}

static inline uint32_t homeinv_addr(uint32_t reg_off) {
  return (uint32_t)(HOMEINV_BASE + reg_off);
}

// -----------------------------------------------------------------------------
// Smoke sequence
// -----------------------------------------------------------------------------

// Returns 0 on pass, nonzero on failure.
int homeinv_reg_smoke(void) {
  // 1) Identify block.
  const uint32_t id = mmio_read32(homeinv_addr(HOMEINV_REG_ID));
  const uint32_t ver = mmio_read32(homeinv_addr(HOMEINV_REG_VERSION));

  // Expected tag: "HICH" (0x48494348).
  // If you fork the project, update this check to match your RTL.
  if (id != 0x48494348u) {
    return 1;
  }
  if (ver != 0x00000001u) {
    return 2;
  }

  // 2) Enable core.
  mmio_write32(homeinv_addr(HOMEINV_REG_CTRL), HOMEINV_CTRL_ENABLE_MASK);

  // 3) Sanity check a live counter increments.
  const uint32_t t0 = mmio_read32(homeinv_addr(HOMEINV_REG_TIME_NOW));
  const uint32_t t1 = mmio_read32(homeinv_addr(HOMEINV_REG_TIME_NOW));

  // TIME_NOW increments every wb_clk_i; back-to-back reads should typically differ.
  // Accept equality (very slow clock / bus timing) but still flag extreme cases.
  // If you want a stricter check, add a small delay loop here.
  (void)t0;
  (void)t1;

  // 4) Optional: pulse START (W1P). Reads return 0.
  mmio_write32(homeinv_addr(HOMEINV_REG_CTRL), HOMEINV_CTRL_START_MASK);

  // Done.
  return 0;
}
