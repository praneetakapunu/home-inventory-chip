// Home Inventory Chip - Wishbone register block (OpenMPW / Caravel)
//
// This module is meant to be instantiated by the OpenMPW harness repo
// (home-inventory-chip-openmpw) as the design-under-test.
//
// Current scope:
// - Provide a stable Wishbone register file for bring-up
// - Expose a minimal control plane (CTRL/IRQ_EN) and status readback
// - Provide stubbed ADC + calibration register file for firmware bring-up
//
// NOTE: Addressing is byte-addressed (Wishbone). See spec/regmap.md.

`default_nettype none

module home_inventory_wb (
    input  wire        wb_clk_i,
    input  wire        wb_rst_i,
    input  wire        wbs_stb_i,
    input  wire        wbs_cyc_i,
    input  wire        wbs_we_i,
    input  wire [3:0]  wbs_sel_i,
    input  wire [31:0] wbs_dat_i,
    input  wire [31:0] wbs_adr_i,
    output reg         wbs_ack_o,
    output reg  [31:0] wbs_dat_o,

    // Optional: core status input (can be tied off until integrated)
    input  wire [7:0]  core_status,

    // Control outputs (for future integration)
    output wire        ctrl_enable,
    output wire        ctrl_start,
    output wire [2:0]  irq_en
);

    // ---------------------------------------------------------------------
    // Address map (byte addresses)
    // ---------------------------------------------------------------------
    localparam [31:0] ADR_ID      = 32'h0000_0000;
    localparam [31:0] ADR_VERSION = 32'h0000_0004;

    localparam [31:0] ADR_CTRL    = 32'h0000_0100;
    localparam [31:0] ADR_IRQ_EN  = 32'h0000_0104;
    localparam [31:0] ADR_STATUS  = 32'h0000_0108;

    // ADC block (see spec/regmap_v1.yaml)
    localparam [31:0] ADR_ADC_CFG     = 32'h0000_0200;
    localparam [31:0] ADR_ADC_CMD     = 32'h0000_0204;
    localparam [31:0] ADR_ADC_RAW_CH0 = 32'h0000_0210;
    localparam [31:0] ADR_ADC_RAW_CH1 = 32'h0000_0214;
    localparam [31:0] ADR_ADC_RAW_CH2 = 32'h0000_0218;
    localparam [31:0] ADR_ADC_RAW_CH3 = 32'h0000_021C;
    localparam [31:0] ADR_ADC_RAW_CH4 = 32'h0000_0220;
    localparam [31:0] ADR_ADC_RAW_CH5 = 32'h0000_0224;
    localparam [31:0] ADR_ADC_RAW_CH6 = 32'h0000_0228;
    localparam [31:0] ADR_ADC_RAW_CH7 = 32'h0000_022C;

    // Calibration block (see spec/regmap_v1.yaml)
    localparam [31:0] ADR_TARE_CH0  = 32'h0000_0300;
    localparam [31:0] ADR_TARE_CH1  = 32'h0000_0304;
    localparam [31:0] ADR_TARE_CH2  = 32'h0000_0308;
    localparam [31:0] ADR_TARE_CH3  = 32'h0000_030C;
    localparam [31:0] ADR_TARE_CH4  = 32'h0000_0310;
    localparam [31:0] ADR_TARE_CH5  = 32'h0000_0314;
    localparam [31:0] ADR_TARE_CH6  = 32'h0000_0318;
    localparam [31:0] ADR_TARE_CH7  = 32'h0000_031C;

    localparam [31:0] ADR_SCALE_CH0 = 32'h0000_0320;
    localparam [31:0] ADR_SCALE_CH1 = 32'h0000_0324;
    localparam [31:0] ADR_SCALE_CH2 = 32'h0000_0328;
    localparam [31:0] ADR_SCALE_CH3 = 32'h0000_032C;
    localparam [31:0] ADR_SCALE_CH4 = 32'h0000_0330;
    localparam [31:0] ADR_SCALE_CH5 = 32'h0000_0334;
    localparam [31:0] ADR_SCALE_CH6 = 32'h0000_0338;
    localparam [31:0] ADR_SCALE_CH7 = 32'h0000_033C;

    // Events block (see spec/regmap_v1.yaml)
    localparam [31:0] ADR_EVT_COUNT_CH0      = 32'h0000_0400;
    localparam [31:0] ADR_EVT_COUNT_CH1      = 32'h0000_0404;
    localparam [31:0] ADR_EVT_COUNT_CH2      = 32'h0000_0408;
    localparam [31:0] ADR_EVT_COUNT_CH3      = 32'h0000_040C;
    localparam [31:0] ADR_EVT_COUNT_CH4      = 32'h0000_0410;
    localparam [31:0] ADR_EVT_COUNT_CH5      = 32'h0000_0414;
    localparam [31:0] ADR_EVT_COUNT_CH6      = 32'h0000_0418;
    localparam [31:0] ADR_EVT_COUNT_CH7      = 32'h0000_041C;

    localparam [31:0] ADR_EVT_LAST_DELTA_CH0 = 32'h0000_0420;
    localparam [31:0] ADR_EVT_LAST_DELTA_CH1 = 32'h0000_0424;
    localparam [31:0] ADR_EVT_LAST_DELTA_CH2 = 32'h0000_0428;
    localparam [31:0] ADR_EVT_LAST_DELTA_CH3 = 32'h0000_042C;
    localparam [31:0] ADR_EVT_LAST_DELTA_CH4 = 32'h0000_0430;
    localparam [31:0] ADR_EVT_LAST_DELTA_CH5 = 32'h0000_0434;
    localparam [31:0] ADR_EVT_LAST_DELTA_CH6 = 32'h0000_0438;
    localparam [31:0] ADR_EVT_LAST_DELTA_CH7 = 32'h0000_043C;

    localparam [31:0] ADR_EVT_LAST_TS        = 32'h0000_0440;

    // ---------------------------------------------------------------------
    // Registers
    // ---------------------------------------------------------------------
    reg        r_enable;
    reg        r_start_pulse;
    reg [31:0] r_irq_en;

    // ADC regs (stubbed for now; enough for firmware to enumerate + latch)
    reg [3:0]  r_adc_num_ch;
    reg        r_adc_snapshot_pulse;
    reg [31:0] r_adc_raw [0:7];

    // Calibration regs
    reg [31:0] r_tare  [0:7];
    reg [31:0] r_scale [0:7];

    // Events regs (read-only for now; will be driven by the core later)
    reg [31:0] r_evt_count      [0:7];
    reg [31:0] r_evt_last_delta [0:7];
    reg [31:0] r_evt_last_ts;

    // Decode fields
    assign ctrl_enable = r_enable;
    // START is a 1-cycle pulse generated on a write of CTRL.START=1.
    assign ctrl_start  = r_start_pulse;
    assign irq_en      = r_irq_en[2:0];

    // ---------------------------------------------------------------------
    // Wishbone handshake
    // ---------------------------------------------------------------------
    wire wb_valid = wbs_cyc_i & wbs_stb_i;
    wire wb_fire  = wb_valid & ~wbs_ack_o; // single-cycle accept

    // Byte-write helper
    function automatic [31:0] apply_wstrb(
        input [31:0] oldv,
        input [31:0] newv,
        input [3:0]  sel
    );
        begin
            apply_wstrb = oldv;
            if (sel[0]) apply_wstrb[7:0]   = newv[7:0];
            if (sel[1]) apply_wstrb[15:8]  = newv[15:8];
            if (sel[2]) apply_wstrb[23:16] = newv[23:16];
            if (sel[3]) apply_wstrb[31:24] = newv[31:24];
        end
    endfunction

    // Align address to 32-bit word boundary for decode.
    // Caravel/Wishbone masters sometimes present byte addresses; we treat
    // registers as 32-bit word-aligned and ignore adr[1:0] for decode.
    wire [31:0] wb_adr_aligned = {wbs_adr_i[31:2], 2'b00};

    // Read mux (combinational)
    reg [31:0] rd_data;
    always @(*) begin
        rd_data = 32'h0;
        case (wb_adr_aligned)
            ADR_ID:      rd_data = 32'h4849_4348; // 'HICH' (Home Inventory CHip)
            ADR_VERSION: rd_data = 32'h0000_0001;

            ADR_CTRL:    rd_data = {30'h0, 1'b0, r_enable};
            ADR_IRQ_EN:  rd_data = r_irq_en;
            ADR_STATUS:  rd_data = {24'h0, core_status};

            // ADC
            ADR_ADC_CFG:     rd_data = {28'h0, r_adc_num_ch};
            ADR_ADC_CMD:     rd_data = 32'h0; // write-only pulse bits
            ADR_ADC_RAW_CH0: rd_data = r_adc_raw[0];
            ADR_ADC_RAW_CH1: rd_data = r_adc_raw[1];
            ADR_ADC_RAW_CH2: rd_data = r_adc_raw[2];
            ADR_ADC_RAW_CH3: rd_data = r_adc_raw[3];
            ADR_ADC_RAW_CH4: rd_data = r_adc_raw[4];
            ADR_ADC_RAW_CH5: rd_data = r_adc_raw[5];
            ADR_ADC_RAW_CH6: rd_data = r_adc_raw[6];
            ADR_ADC_RAW_CH7: rd_data = r_adc_raw[7];

            // Calibration
            ADR_TARE_CH0:  rd_data = r_tare[0];
            ADR_TARE_CH1:  rd_data = r_tare[1];
            ADR_TARE_CH2:  rd_data = r_tare[2];
            ADR_TARE_CH3:  rd_data = r_tare[3];
            ADR_TARE_CH4:  rd_data = r_tare[4];
            ADR_TARE_CH5:  rd_data = r_tare[5];
            ADR_TARE_CH6:  rd_data = r_tare[6];
            ADR_TARE_CH7:  rd_data = r_tare[7];

            ADR_SCALE_CH0: rd_data = r_scale[0];
            ADR_SCALE_CH1: rd_data = r_scale[1];
            ADR_SCALE_CH2: rd_data = r_scale[2];
            ADR_SCALE_CH3: rd_data = r_scale[3];
            ADR_SCALE_CH4: rd_data = r_scale[4];
            ADR_SCALE_CH5: rd_data = r_scale[5];
            ADR_SCALE_CH6: rd_data = r_scale[6];
            ADR_SCALE_CH7: rd_data = r_scale[7];

            // Events (read-only)
            ADR_EVT_COUNT_CH0:      rd_data = r_evt_count[0];
            ADR_EVT_COUNT_CH1:      rd_data = r_evt_count[1];
            ADR_EVT_COUNT_CH2:      rd_data = r_evt_count[2];
            ADR_EVT_COUNT_CH3:      rd_data = r_evt_count[3];
            ADR_EVT_COUNT_CH4:      rd_data = r_evt_count[4];
            ADR_EVT_COUNT_CH5:      rd_data = r_evt_count[5];
            ADR_EVT_COUNT_CH6:      rd_data = r_evt_count[6];
            ADR_EVT_COUNT_CH7:      rd_data = r_evt_count[7];

            ADR_EVT_LAST_DELTA_CH0: rd_data = r_evt_last_delta[0];
            ADR_EVT_LAST_DELTA_CH1: rd_data = r_evt_last_delta[1];
            ADR_EVT_LAST_DELTA_CH2: rd_data = r_evt_last_delta[2];
            ADR_EVT_LAST_DELTA_CH3: rd_data = r_evt_last_delta[3];
            ADR_EVT_LAST_DELTA_CH4: rd_data = r_evt_last_delta[4];
            ADR_EVT_LAST_DELTA_CH5: rd_data = r_evt_last_delta[5];
            ADR_EVT_LAST_DELTA_CH6: rd_data = r_evt_last_delta[6];
            ADR_EVT_LAST_DELTA_CH7: rd_data = r_evt_last_delta[7];

            ADR_EVT_LAST_TS:        rd_data = r_evt_last_ts;

            default:     rd_data = 32'h0;
        endcase
    end

    integer i;
    always @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            wbs_ack_o       <= 1'b0;
            wbs_dat_o       <= 32'h0;
            r_enable        <= 1'b0;
            r_start_pulse   <= 1'b0;
            r_irq_en        <= 32'h0;

            r_adc_num_ch    <= 4'h0;
            r_adc_snapshot_pulse <= 1'b0;

            r_evt_last_ts <= 32'h0;

            for (i = 0; i < 8; i = i + 1) begin
                r_adc_raw[i] <= 32'h0;
                r_tare[i]    <= 32'h0;
                r_scale[i]   <= 32'h0001_0000; // Q16.16 1.0

                r_evt_count[i]      <= 32'h0;
                r_evt_last_delta[i] <= 32'h0;
            end
        end else begin
            // Default: clear 1-cycle pulse outputs.
            r_start_pulse <= 1'b0;
            r_adc_snapshot_pulse <= 1'b0;

            // ACK pulse for each accepted request.
            wbs_ack_o <= wb_valid & ~wbs_ack_o;

            // Latch read data on accept (works for both reads and writes).
            if (wb_fire) begin
                wbs_dat_o <= rd_data;
            end

            // Writes
            if (wb_fire && wbs_we_i) begin
                case (wb_adr_aligned)
                    ADR_CTRL: begin
                        // ENABLE is a sticky RW bit.
                        if (wbs_sel_i[0]) r_enable <= wbs_dat_i[0];
                        // START is write-1-to-pulse (not sticky, not readable).
                        if (wbs_sel_i[0] && wbs_dat_i[1]) r_start_pulse <= 1'b1;
                    end
                    ADR_IRQ_EN: r_irq_en <= apply_wstrb(r_irq_en, wbs_dat_i, wbs_sel_i);

                    // ADC
                    ADR_ADC_CFG: begin
                        if (wbs_sel_i[0]) r_adc_num_ch <= wbs_dat_i[3:0];
                    end
                    ADR_ADC_CMD: begin
                        // SNAPSHOT is write-1-to-pulse on bit[0]
                        if (wbs_sel_i[0] && wbs_dat_i[0]) r_adc_snapshot_pulse <= 1'b1;
                    end

                    // Calibration
                    ADR_TARE_CH0:  r_tare[0]  <= apply_wstrb(r_tare[0],  wbs_dat_i, wbs_sel_i);
                    ADR_TARE_CH1:  r_tare[1]  <= apply_wstrb(r_tare[1],  wbs_dat_i, wbs_sel_i);
                    ADR_TARE_CH2:  r_tare[2]  <= apply_wstrb(r_tare[2],  wbs_dat_i, wbs_sel_i);
                    ADR_TARE_CH3:  r_tare[3]  <= apply_wstrb(r_tare[3],  wbs_dat_i, wbs_sel_i);
                    ADR_TARE_CH4:  r_tare[4]  <= apply_wstrb(r_tare[4],  wbs_dat_i, wbs_sel_i);
                    ADR_TARE_CH5:  r_tare[5]  <= apply_wstrb(r_tare[5],  wbs_dat_i, wbs_sel_i);
                    ADR_TARE_CH6:  r_tare[6]  <= apply_wstrb(r_tare[6],  wbs_dat_i, wbs_sel_i);
                    ADR_TARE_CH7:  r_tare[7]  <= apply_wstrb(r_tare[7],  wbs_dat_i, wbs_sel_i);

                    ADR_SCALE_CH0: r_scale[0] <= apply_wstrb(r_scale[0], wbs_dat_i, wbs_sel_i);
                    ADR_SCALE_CH1: r_scale[1] <= apply_wstrb(r_scale[1], wbs_dat_i, wbs_sel_i);
                    ADR_SCALE_CH2: r_scale[2] <= apply_wstrb(r_scale[2], wbs_dat_i, wbs_sel_i);
                    ADR_SCALE_CH3: r_scale[3] <= apply_wstrb(r_scale[3], wbs_dat_i, wbs_sel_i);
                    ADR_SCALE_CH4: r_scale[4] <= apply_wstrb(r_scale[4], wbs_dat_i, wbs_sel_i);
                    ADR_SCALE_CH5: r_scale[5] <= apply_wstrb(r_scale[5], wbs_dat_i, wbs_sel_i);
                    ADR_SCALE_CH6: r_scale[6] <= apply_wstrb(r_scale[6], wbs_dat_i, wbs_sel_i);
                    ADR_SCALE_CH7: r_scale[7] <= apply_wstrb(r_scale[7], wbs_dat_i, wbs_sel_i);

                    default: ;
                endcase
            end
        end
    end

endmodule

`default_nettype wire
