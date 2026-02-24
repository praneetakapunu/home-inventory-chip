// home_inventory_regmap_pkg.sv
//
// AUTO-GENERATED FILE. DO NOT EDIT BY HAND.
// Generated from: spec/regmap_v1.yaml
// Generated at:   (omitted for deterministic builds)
//
// Notes:
//   - Addresses are byte addresses (Wishbone wbs_adr_i).
//   - Registers are 32-bit.

package home_inventory_regmap_pkg;

  // -----------------------------
  // Registers (byte addresses)
  // -----------------------------
  localparam logic [31:0] HOMEINV_ADR_ID = 32'h00000000;
  localparam logic [31:0] HOMEINV_ADR_VERSION = 32'h00000004;
  localparam logic [31:0] HOMEINV_ADR_CTRL = 32'h00000100;
  localparam logic [31:0] HOMEINV_ADR_IRQ_EN = 32'h00000104;
  localparam logic [31:0] HOMEINV_ADR_STATUS = 32'h00000108;
  localparam logic [31:0] HOMEINV_ADR_TIME_NOW = 32'h0000010C;
  localparam logic [31:0] HOMEINV_ADR_ADC_CFG = 32'h00000200;
  localparam logic [31:0] HOMEINV_ADR_ADC_CMD = 32'h00000204;
  localparam logic [31:0] HOMEINV_ADR_ADC_FIFO_STATUS = 32'h00000208;
  localparam logic [31:0] HOMEINV_ADR_ADC_FIFO_DATA = 32'h0000020C;
  localparam logic [31:0] HOMEINV_ADR_ADC_RAW_CH0 = 32'h00000210;
  localparam logic [31:0] HOMEINV_ADR_ADC_RAW_CH1 = 32'h00000214;
  localparam logic [31:0] HOMEINV_ADR_ADC_RAW_CH2 = 32'h00000218;
  localparam logic [31:0] HOMEINV_ADR_ADC_RAW_CH3 = 32'h0000021C;
  localparam logic [31:0] HOMEINV_ADR_ADC_RAW_CH4 = 32'h00000220;
  localparam logic [31:0] HOMEINV_ADR_ADC_RAW_CH5 = 32'h00000224;
  localparam logic [31:0] HOMEINV_ADR_ADC_RAW_CH6 = 32'h00000228;
  localparam logic [31:0] HOMEINV_ADR_ADC_RAW_CH7 = 32'h0000022C;
  localparam logic [31:0] HOMEINV_ADR_ADC_SNAPSHOT_COUNT = 32'h00000230;
  localparam logic [31:0] HOMEINV_ADR_TARE_CH0 = 32'h00000300;
  localparam logic [31:0] HOMEINV_ADR_TARE_CH1 = 32'h00000304;
  localparam logic [31:0] HOMEINV_ADR_TARE_CH2 = 32'h00000308;
  localparam logic [31:0] HOMEINV_ADR_TARE_CH3 = 32'h0000030C;
  localparam logic [31:0] HOMEINV_ADR_TARE_CH4 = 32'h00000310;
  localparam logic [31:0] HOMEINV_ADR_TARE_CH5 = 32'h00000314;
  localparam logic [31:0] HOMEINV_ADR_TARE_CH6 = 32'h00000318;
  localparam logic [31:0] HOMEINV_ADR_TARE_CH7 = 32'h0000031C;
  localparam logic [31:0] HOMEINV_ADR_SCALE_CH0 = 32'h00000320;
  localparam logic [31:0] HOMEINV_ADR_SCALE_CH1 = 32'h00000324;
  localparam logic [31:0] HOMEINV_ADR_SCALE_CH2 = 32'h00000328;
  localparam logic [31:0] HOMEINV_ADR_SCALE_CH3 = 32'h0000032C;
  localparam logic [31:0] HOMEINV_ADR_SCALE_CH4 = 32'h00000330;
  localparam logic [31:0] HOMEINV_ADR_SCALE_CH5 = 32'h00000334;
  localparam logic [31:0] HOMEINV_ADR_SCALE_CH6 = 32'h00000338;
  localparam logic [31:0] HOMEINV_ADR_SCALE_CH7 = 32'h0000033C;
  localparam logic [31:0] HOMEINV_ADR_EVT_COUNT_CH0 = 32'h00000400;
  localparam logic [31:0] HOMEINV_ADR_EVT_COUNT_CH1 = 32'h00000404;
  localparam logic [31:0] HOMEINV_ADR_EVT_COUNT_CH2 = 32'h00000408;
  localparam logic [31:0] HOMEINV_ADR_EVT_COUNT_CH3 = 32'h0000040C;
  localparam logic [31:0] HOMEINV_ADR_EVT_COUNT_CH4 = 32'h00000410;
  localparam logic [31:0] HOMEINV_ADR_EVT_COUNT_CH5 = 32'h00000414;
  localparam logic [31:0] HOMEINV_ADR_EVT_COUNT_CH6 = 32'h00000418;
  localparam logic [31:0] HOMEINV_ADR_EVT_COUNT_CH7 = 32'h0000041C;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_DELTA_CH0 = 32'h00000420;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_DELTA_CH1 = 32'h00000424;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_DELTA_CH2 = 32'h00000428;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_DELTA_CH3 = 32'h0000042C;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_DELTA_CH4 = 32'h00000430;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_DELTA_CH5 = 32'h00000434;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_DELTA_CH6 = 32'h00000438;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_DELTA_CH7 = 32'h0000043C;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_TS = 32'h00000440;
  localparam logic [31:0] HOMEINV_ADR_EVT_CFG = 32'h00000444;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_TS_CH0 = 32'h00000448;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_TS_CH1 = 32'h0000044C;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_TS_CH2 = 32'h00000450;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_TS_CH3 = 32'h00000454;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_TS_CH4 = 32'h00000458;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_TS_CH5 = 32'h0000045C;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_TS_CH6 = 32'h00000460;
  localparam logic [31:0] HOMEINV_ADR_EVT_LAST_TS_CH7 = 32'h00000464;
  localparam logic [31:0] HOMEINV_ADR_EVT_THRESH_CH0 = 32'h00000480;
  localparam logic [31:0] HOMEINV_ADR_EVT_THRESH_CH1 = 32'h00000484;
  localparam logic [31:0] HOMEINV_ADR_EVT_THRESH_CH2 = 32'h00000488;
  localparam logic [31:0] HOMEINV_ADR_EVT_THRESH_CH3 = 32'h0000048C;
  localparam logic [31:0] HOMEINV_ADR_EVT_THRESH_CH4 = 32'h00000490;
  localparam logic [31:0] HOMEINV_ADR_EVT_THRESH_CH5 = 32'h00000494;
  localparam logic [31:0] HOMEINV_ADR_EVT_THRESH_CH6 = 32'h00000498;
  localparam logic [31:0] HOMEINV_ADR_EVT_THRESH_CH7 = 32'h0000049C;

  // -----------------------------
  // Bitfields
  // -----------------------------

  // CTRL fields
  localparam int unsigned HOMEINV_CTRL_ENABLE_BIT = 0;
  localparam logic [31:0] HOMEINV_CTRL_ENABLE_MASK = (32'h1 << HOMEINV_CTRL_ENABLE_BIT);
  localparam int unsigned HOMEINV_CTRL_START_BIT = 1;
  localparam logic [31:0] HOMEINV_CTRL_START_MASK = (32'h1 << HOMEINV_CTRL_START_BIT);

  // IRQ_EN fields
  localparam int unsigned HOMEINV_IRQ_EN_IRQ_EN_LSB  = 0;
  localparam logic [31:0] HOMEINV_IRQ_EN_IRQ_EN_MASK = 32'h00000007;

  // STATUS fields
  localparam int unsigned HOMEINV_STATUS_CORE_STATUS_LSB  = 0;
  localparam logic [31:0] HOMEINV_STATUS_CORE_STATUS_MASK = 32'h000000FF;

  // ADC_CFG fields
  localparam int unsigned HOMEINV_ADC_CFG_NUM_CH_LSB  = 0;
  localparam logic [31:0] HOMEINV_ADC_CFG_NUM_CH_MASK = 32'h0000000F;

  // ADC_CMD fields
  localparam int unsigned HOMEINV_ADC_CMD_SNAPSHOT_BIT = 0;
  localparam logic [31:0] HOMEINV_ADC_CMD_SNAPSHOT_MASK = (32'h1 << HOMEINV_ADC_CMD_SNAPSHOT_BIT);

  // ADC_FIFO_STATUS fields
  localparam int unsigned HOMEINV_ADC_FIFO_STATUS_LEVEL_WORDS_LSB  = 0;
  localparam logic [31:0] HOMEINV_ADC_FIFO_STATUS_LEVEL_WORDS_MASK = 32'h0000FFFF;
  localparam int unsigned HOMEINV_ADC_FIFO_STATUS_OVERRUN_BIT = 16;
  localparam logic [31:0] HOMEINV_ADC_FIFO_STATUS_OVERRUN_MASK = (32'h1 << HOMEINV_ADC_FIFO_STATUS_OVERRUN_BIT);

  // EVT_CFG fields
  localparam int unsigned HOMEINV_EVT_CFG_EVT_EN_LSB  = 0;
  localparam logic [31:0] HOMEINV_EVT_CFG_EVT_EN_MASK = 32'h000000FF;

  // -----------------------------
  // Handy constants
  // -----------------------------
  // Q16.16 representation of 1.0 (matches SCALE_CHx reset)
  localparam logic [31:0] HOMEINV_SCALE_Q16_16_ONE = 32'h0001_0000;

endpackage

