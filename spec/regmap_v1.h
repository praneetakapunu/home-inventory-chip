// AUTO-GENERATED FILE. DO NOT EDIT BY HAND.
// Source: spec/regmap_v1.yaml
// Generated: 2026-03-14T14:31:29Z
// Regmap version: 1

#ifndef HIP_REGMAP_V1_H_
#define HIP_REGMAP_V1_H_

#include <stdint.h>

// All addresses are byte offsets from the IP base address.

// ---- block: id_version (base 0x00000000u) ----
#define HIP_REG_ID                       0x00000000u
#define HIP_REG_VERSION                  0x00000004u

// ---- block: ctrl_status (base 0x00000100u) ----
#define HIP_REG_CTRL                     0x00000100u
#define HIP_CTRL_ENABLE_SHIFT         0u
#define HIP_CTRL_ENABLE_MASK          0x00000001u
#define HIP_CTRL_START_SHIFT         1u
#define HIP_CTRL_START_MASK          0x00000002u
#define HIP_REG_IRQ_EN                   0x00000104u
#define HIP_IRQ_EN_IRQ_EN_SHIFT         0u
#define HIP_IRQ_EN_IRQ_EN_MASK          0x00000007u
#define HIP_REG_STATUS                   0x00000108u
#define HIP_STATUS_CORE_STATUS_SHIFT         0u
#define HIP_STATUS_CORE_STATUS_MASK          0x000000FFu
#define HIP_REG_TIME_NOW                 0x0000010Cu

// ---- block: adc (base 0x00000200u) ----
#define HIP_REG_ADC_CFG                  0x00000200u
#define HIP_ADC_CFG_NUM_CH_SHIFT         0u
#define HIP_ADC_CFG_NUM_CH_MASK          0x0000000Fu
#define HIP_REG_ADC_CMD                  0x00000204u
#define HIP_ADC_CMD_SNAPSHOT_SHIFT         0u
#define HIP_ADC_CMD_SNAPSHOT_MASK          0x00000001u
#define HIP_REG_ADC_FIFO_STATUS          0x00000208u
#define HIP_ADC_FIFO_STATUS_LEVEL_WORDS_SHIFT         0u
#define HIP_ADC_FIFO_STATUS_LEVEL_WORDS_MASK          0x0000FFFFu
#define HIP_ADC_FIFO_STATUS_OVERRUN_SHIFT         16u
#define HIP_ADC_FIFO_STATUS_OVERRUN_MASK          0x00010000u
#define HIP_ADC_FIFO_STATUS_CAPTURE_BUSY_SHIFT         17u
#define HIP_ADC_FIFO_STATUS_CAPTURE_BUSY_MASK          0x00020000u
#define HIP_REG_ADC_FIFO_DATA            0x0000020Cu
#define HIP_REG_ADC_RAW_CH0              0x00000210u
#define HIP_REG_ADC_RAW_CH1              0x00000214u
#define HIP_REG_ADC_RAW_CH2              0x00000218u
#define HIP_REG_ADC_RAW_CH3              0x0000021Cu
#define HIP_REG_ADC_RAW_CH4              0x00000220u
#define HIP_REG_ADC_RAW_CH5              0x00000224u
#define HIP_REG_ADC_RAW_CH6              0x00000228u
#define HIP_REG_ADC_RAW_CH7              0x0000022Cu
#define HIP_REG_ADC_SNAPSHOT_COUNT       0x00000230u

// ---- block: calibration (base 0x00000300u) ----
#define HIP_REG_TARE_CH0                 0x00000300u
#define HIP_REG_TARE_CH1                 0x00000304u
#define HIP_REG_TARE_CH2                 0x00000308u
#define HIP_REG_TARE_CH3                 0x0000030Cu
#define HIP_REG_TARE_CH4                 0x00000310u
#define HIP_REG_TARE_CH5                 0x00000314u
#define HIP_REG_TARE_CH6                 0x00000318u
#define HIP_REG_TARE_CH7                 0x0000031Cu
#define HIP_REG_SCALE_CH0                0x00000320u
#define HIP_REG_SCALE_CH1                0x00000324u
#define HIP_REG_SCALE_CH2                0x00000328u
#define HIP_REG_SCALE_CH3                0x0000032Cu
#define HIP_REG_SCALE_CH4                0x00000330u
#define HIP_REG_SCALE_CH5                0x00000334u
#define HIP_REG_SCALE_CH6                0x00000338u
#define HIP_REG_SCALE_CH7                0x0000033Cu

// ---- block: events (base 0x00000400u) ----
#define HIP_REG_EVT_COUNT_CH0            0x00000400u
#define HIP_REG_EVT_COUNT_CH1            0x00000404u
#define HIP_REG_EVT_COUNT_CH2            0x00000408u
#define HIP_REG_EVT_COUNT_CH3            0x0000040Cu
#define HIP_REG_EVT_COUNT_CH4            0x00000410u
#define HIP_REG_EVT_COUNT_CH5            0x00000414u
#define HIP_REG_EVT_COUNT_CH6            0x00000418u
#define HIP_REG_EVT_COUNT_CH7            0x0000041Cu
#define HIP_REG_EVT_LAST_DELTA_CH0       0x00000420u
#define HIP_REG_EVT_LAST_DELTA_CH1       0x00000424u
#define HIP_REG_EVT_LAST_DELTA_CH2       0x00000428u
#define HIP_REG_EVT_LAST_DELTA_CH3       0x0000042Cu
#define HIP_REG_EVT_LAST_DELTA_CH4       0x00000430u
#define HIP_REG_EVT_LAST_DELTA_CH5       0x00000434u
#define HIP_REG_EVT_LAST_DELTA_CH6       0x00000438u
#define HIP_REG_EVT_LAST_DELTA_CH7       0x0000043Cu
#define HIP_REG_EVT_LAST_TS              0x00000440u
#define HIP_REG_EVT_CFG                  0x00000444u
#define HIP_EVT_CFG_EVT_EN_SHIFT         0u
#define HIP_EVT_CFG_EVT_EN_MASK          0x000000FFu
#define HIP_EVT_CFG_CLEAR_COUNTS_SHIFT         8u
#define HIP_EVT_CFG_CLEAR_COUNTS_MASK          0x00000100u
#define HIP_EVT_CFG_CLEAR_HISTORY_SHIFT         9u
#define HIP_EVT_CFG_CLEAR_HISTORY_MASK          0x00000200u
#define HIP_REG_EVT_LAST_TS_CH0          0x00000448u
#define HIP_REG_EVT_LAST_TS_CH1          0x0000044Cu
#define HIP_REG_EVT_LAST_TS_CH2          0x00000450u
#define HIP_REG_EVT_LAST_TS_CH3          0x00000454u
#define HIP_REG_EVT_LAST_TS_CH4          0x00000458u
#define HIP_REG_EVT_LAST_TS_CH5          0x0000045Cu
#define HIP_REG_EVT_LAST_TS_CH6          0x00000460u
#define HIP_REG_EVT_LAST_TS_CH7          0x00000464u
#define HIP_REG_EVT_THRESH_CH0           0x00000480u
#define HIP_REG_EVT_THRESH_CH1           0x00000484u
#define HIP_REG_EVT_THRESH_CH2           0x00000488u
#define HIP_REG_EVT_THRESH_CH3           0x0000048Cu
#define HIP_REG_EVT_THRESH_CH4           0x00000490u
#define HIP_REG_EVT_THRESH_CH5           0x00000494u
#define HIP_REG_EVT_THRESH_CH6           0x00000498u
#define HIP_REG_EVT_THRESH_CH7           0x0000049Cu

#endif
