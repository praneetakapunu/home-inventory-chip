// home_inventory_regmap.h
//
// AUTO-GENERATED FILE. DO NOT EDIT BY HAND.
// Generated from: spec/regmap_v1.yaml
// Generated at:   (omitted for deterministic builds)
//
// Notes:
//   - Offsets are byte offsets (Wishbone byte addresses).
//   - Registers are 32-bit.
//   - wbs_sel_i byte-enables must be honored on writes.
//
#pragma once

#include <stdint.h>

// -----------------------------
// Registers (byte offsets)
// -----------------------------
#define HOMEINV_REG_ID               0x00000000u
#define HOMEINV_REG_VERSION          0x00000004u
#define HOMEINV_REG_CTRL             0x00000100u
#define HOMEINV_REG_IRQ_EN           0x00000104u
#define HOMEINV_REG_STATUS           0x00000108u
#define HOMEINV_REG_ADC_CFG          0x00000200u
#define HOMEINV_REG_ADC_CMD          0x00000204u
#define HOMEINV_REG_ADC_RAW_CH0      0x00000210u
#define HOMEINV_REG_ADC_RAW_CH1      0x00000214u
#define HOMEINV_REG_ADC_RAW_CH2      0x00000218u
#define HOMEINV_REG_ADC_RAW_CH3      0x0000021Cu
#define HOMEINV_REG_ADC_RAW_CH4      0x00000220u
#define HOMEINV_REG_ADC_RAW_CH5      0x00000224u
#define HOMEINV_REG_ADC_RAW_CH6      0x00000228u
#define HOMEINV_REG_ADC_RAW_CH7      0x0000022Cu
#define HOMEINV_REG_TARE_CH0         0x00000300u
#define HOMEINV_REG_TARE_CH1         0x00000304u
#define HOMEINV_REG_TARE_CH2         0x00000308u
#define HOMEINV_REG_TARE_CH3         0x0000030Cu
#define HOMEINV_REG_TARE_CH4         0x00000310u
#define HOMEINV_REG_TARE_CH5         0x00000314u
#define HOMEINV_REG_TARE_CH6         0x00000318u
#define HOMEINV_REG_TARE_CH7         0x0000031Cu
#define HOMEINV_REG_SCALE_CH0        0x00000320u
#define HOMEINV_REG_SCALE_CH1        0x00000324u
#define HOMEINV_REG_SCALE_CH2        0x00000328u
#define HOMEINV_REG_SCALE_CH3        0x0000032Cu
#define HOMEINV_REG_SCALE_CH4        0x00000330u
#define HOMEINV_REG_SCALE_CH5        0x00000334u
#define HOMEINV_REG_SCALE_CH6        0x00000338u
#define HOMEINV_REG_SCALE_CH7        0x0000033Cu
#define HOMEINV_REG_EVT_COUNT_CH0    0x00000400u
#define HOMEINV_REG_EVT_COUNT_CH1    0x00000404u
#define HOMEINV_REG_EVT_COUNT_CH2    0x00000408u
#define HOMEINV_REG_EVT_COUNT_CH3    0x0000040Cu
#define HOMEINV_REG_EVT_COUNT_CH4    0x00000410u
#define HOMEINV_REG_EVT_COUNT_CH5    0x00000414u
#define HOMEINV_REG_EVT_COUNT_CH6    0x00000418u
#define HOMEINV_REG_EVT_COUNT_CH7    0x0000041Cu
#define HOMEINV_REG_EVT_LAST_DELTA_CH0 0x00000420u
#define HOMEINV_REG_EVT_LAST_DELTA_CH1 0x00000424u
#define HOMEINV_REG_EVT_LAST_DELTA_CH2 0x00000428u
#define HOMEINV_REG_EVT_LAST_DELTA_CH3 0x0000042Cu
#define HOMEINV_REG_EVT_LAST_DELTA_CH4 0x00000430u
#define HOMEINV_REG_EVT_LAST_DELTA_CH5 0x00000434u
#define HOMEINV_REG_EVT_LAST_DELTA_CH6 0x00000438u
#define HOMEINV_REG_EVT_LAST_DELTA_CH7 0x0000043Cu
#define HOMEINV_REG_EVT_LAST_TS      0x00000440u

// -----------------------------
// Bitfields
// -----------------------------

// CTRL fields
#define HOMEINV_CTRL_ENABLE_BIT   0u
#define HOMEINV_CTRL_ENABLE_MASK  (1u << HOMEINV_CTRL_ENABLE_BIT)
#define HOMEINV_CTRL_START_BIT   1u
#define HOMEINV_CTRL_START_MASK  (1u << HOMEINV_CTRL_START_BIT)

// IRQ_EN fields
#define HOMEINV_IRQ_EN_IRQ_EN_LSB   0u
#define HOMEINV_IRQ_EN_IRQ_EN_MASK  0x00000007u

// STATUS fields
#define HOMEINV_STATUS_CORE_STATUS_LSB   0u
#define HOMEINV_STATUS_CORE_STATUS_MASK  0x000000FFu

// ADC_CFG fields
#define HOMEINV_ADC_CFG_NUM_CH_LSB   0u
#define HOMEINV_ADC_CFG_NUM_CH_MASK  0x0000000Fu

// ADC_CMD fields
#define HOMEINV_ADC_CMD_SNAPSHOT_BIT   0u
#define HOMEINV_ADC_CMD_SNAPSHOT_MASK  (1u << HOMEINV_ADC_CMD_SNAPSHOT_BIT)

// -----------------------------
// Handy constants
// -----------------------------
// Q16.16 representation of 1.0 (matches SCALE_CHx reset)
#define HOMEINV_SCALE_Q16_16_ONE  0x00010000u

