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
    // Single source-of-truth is spec/regmap_v1.yaml.
    // The localparams below are generated into rtl/include/regmap_params.vh.
`include "include/regmap_params.vh"

    // ---------------------------------------------------------------------
    // Registers
    // ---------------------------------------------------------------------
    reg        r_enable;
    reg        r_start_pulse;
    reg        r_start_pending;
    reg [31:0] r_irq_en;

    // ADC regs (stubbed for now; enough for firmware to enumerate + latch)
    reg [3:0]  r_adc_num_ch;
    reg [31:0] r_adc_snapshot_count;
    reg [31:0] r_adc_raw [0:7];

    // ADC streaming FIFO (stubbed, but matches regmap_v1.yaml semantics)
    localparam integer ADC_FIFO_DEPTH = 16;
    localparam integer ADC_FIFO_AW    = 4; // log2(16)
    reg [31:0] r_adc_fifo_mem [0:ADC_FIFO_DEPTH-1];
    reg [ADC_FIFO_AW-1:0] r_adc_fifo_wr;
    reg [ADC_FIFO_AW-1:0] r_adc_fifo_rd;
    reg [15:0] r_adc_fifo_level;
    reg        r_adc_fifo_overrun;

    // Calibration regs
    reg [31:0] r_tare  [0:7];
    reg [31:0] r_scale [0:7];

    // Events regs (status readback driven by core later)
    reg [31:0] r_evt_count      [0:7];
    reg [31:0] r_evt_last_delta [0:7];
    reg [31:0] r_evt_last_ts;

    // Events regs (config, writable now so firmware can bring-up its control path)
    reg [7:0]  r_evt_en;           // EVT_CFG.EVT_EN
    reg [31:0] r_evt_thresh [0:7]; // EVT_THRESH_CHx

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

    // ---------------------------------------------------------------------
    // ADC FIFO helpers
    // ---------------------------------------------------------------------
    // NOTE on assignment style:
    // This task may be called multiple times in the same clocked always block
    // (e.g., pushing an entire ADC frame). If we used nonblocking assignments
    // (<=) to update the pointers/level, only the *last* increment would win.
    // We therefore use blocking assignments for the pointer/level bookkeeping
    // so multiple pushes in one cycle accumulate correctly; the final values
    // still settle to flops at the clock edge.
    task automatic adc_fifo_push(input [31:0] word);
        begin
            if (r_adc_fifo_level == ADC_FIFO_DEPTH) begin
                r_adc_fifo_overrun <= 1'b1;
            end else begin
                r_adc_fifo_mem[r_adc_fifo_wr] <= word;
                r_adc_fifo_wr    = r_adc_fifo_wr + {{(ADC_FIFO_AW-1){1'b0}},1'b1};
                r_adc_fifo_level = r_adc_fifo_level + 16'h1;
            end
        end
    endtask

    // Align address to 32-bit word boundary for decode.
    // Caravel/Wishbone masters sometimes present byte addresses; we treat
    // registers as 32-bit word-aligned and ignore adr[1:0] for decode.
    wire [31:0] wb_adr_aligned = {wbs_adr_i[31:2], 2'b00};

    // Write-1-to-pulse detections on the accepted write beat.
    wire ctrl_start_fire   = (wb_fire && wbs_we_i && (wb_adr_aligned == ADR_CTRL)    && wbs_sel_i[0] && wbs_dat_i[1]);
    wire adc_snapshot_fire = (wb_fire && wbs_we_i && (wb_adr_aligned == ADR_ADC_CMD) && wbs_sel_i[0] && wbs_dat_i[0]);

    // Read mux (combinational)
    reg [31:0] rd_data;
    always @(*) begin
        rd_data = 32'h0;
        case (wb_adr_aligned)
            ADR_ID:      rd_data = 32'h4849_4348; // 'HICH' (Home Inventory CHip)
            ADR_VERSION: rd_data = 32'h0000_0001;

            ADR_CTRL:    rd_data = {30'h0, 1'b0, r_enable};
            // Only bits [2:0] are defined; reserved bits read as 0.
            ADR_IRQ_EN:  rd_data = {29'h0, r_irq_en[2:0]};
            ADR_STATUS:  rd_data = {24'h0, core_status};

            // ADC
            ADR_ADC_CFG:        rd_data = {28'h0, r_adc_num_ch};
            ADR_ADC_CMD:        rd_data = 32'h0; // write-only pulse bits
            ADR_ADC_FIFO_STATUS: rd_data = {15'h0, r_adc_fifo_overrun, r_adc_fifo_level};
            ADR_ADC_FIFO_DATA:   rd_data = (r_adc_fifo_level != 16'h0) ? r_adc_fifo_mem[r_adc_fifo_rd] : 32'h0;
            ADR_ADC_RAW_CH0:    rd_data = r_adc_raw[0];
            ADR_ADC_RAW_CH1:    rd_data = r_adc_raw[1];
            ADR_ADC_RAW_CH2:    rd_data = r_adc_raw[2];
            ADR_ADC_RAW_CH3:    rd_data = r_adc_raw[3];
            ADR_ADC_RAW_CH4:    rd_data = r_adc_raw[4];
            ADR_ADC_RAW_CH5:    rd_data = r_adc_raw[5];
            ADR_ADC_RAW_CH6:           rd_data = r_adc_raw[6];
            ADR_ADC_RAW_CH7:           rd_data = r_adc_raw[7];
            ADR_ADC_SNAPSHOT_COUNT:    rd_data = r_adc_snapshot_count;

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

            // Events config
            ADR_EVT_CFG:            rd_data = {24'h0, r_evt_en};
            ADR_EVT_THRESH_CH0:     rd_data = r_evt_thresh[0];
            ADR_EVT_THRESH_CH1:     rd_data = r_evt_thresh[1];
            ADR_EVT_THRESH_CH2:     rd_data = r_evt_thresh[2];
            ADR_EVT_THRESH_CH3:     rd_data = r_evt_thresh[3];
            ADR_EVT_THRESH_CH4:     rd_data = r_evt_thresh[4];
            ADR_EVT_THRESH_CH5:     rd_data = r_evt_thresh[5];
            ADR_EVT_THRESH_CH6:     rd_data = r_evt_thresh[6];
            ADR_EVT_THRESH_CH7:     rd_data = r_evt_thresh[7];

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
            r_start_pending <= 1'b0;
            r_irq_en        <= 32'h0;

            r_adc_num_ch    <= 4'h0;
            r_adc_snapshot_count <= 32'h0;

            r_adc_fifo_wr      <= {ADC_FIFO_AW{1'b0}};
            r_adc_fifo_rd      <= {ADC_FIFO_AW{1'b0}};
            r_adc_fifo_level   <= 16'h0;
            r_adc_fifo_overrun <= 1'b0;

            r_evt_last_ts <= 32'h0;
            r_evt_en      <= 8'h00;

            for (i = 0; i < 8; i = i + 1) begin
                r_adc_raw[i] <= 32'h0;
                r_tare[i]    <= 32'h0;
                r_scale[i]   <= 32'h0001_0000; // Q16.16 1.0

                r_evt_count[i]      <= 32'h0;
                r_evt_last_delta[i] <= 32'h0;

                r_evt_thresh[i] <= 32'h0;
            end
        end else begin
            // Pulse generation: delay write-1-to-pulse requests by 1 cycle so
            // downstream logic can observe a clean full-cycle pulse *after* the
            // Wishbone write has been accepted.
            r_start_pulse   <= r_start_pending;
            r_start_pending <= ctrl_start_fire;

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
                        // Pulse timing is handled by ctrl_start_fire + r_start_pending.
                    end
                    ADR_IRQ_EN: begin
                        // Only bits [2:0] are defined; reserved bits must ignore writes.
                        r_irq_en <= apply_wstrb(r_irq_en, wbs_dat_i, wbs_sel_i) & 32'h0000_0007;
                    end

                    // ADC
                    ADR_ADC_CFG: begin
                        if (wbs_sel_i[0]) r_adc_num_ch <= wbs_dat_i[3:0];
                    end
                    ADR_ADC_CMD: begin
                        // SNAPSHOT is write-1-to-pulse on bit[0]
                        // (pulse is handled by adc_snapshot_fire combinational detection)
                    end
                    ADR_ADC_FIFO_STATUS: begin
                        // W1C overrun flag at bit[16]
                        // Respect byte-enables: bit[16] lives in byte lane 2 (SEL[2]).
                        if (wbs_sel_i[2] && wbs_dat_i[16]) r_adc_fifo_overrun <= 1'b0;
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

                    // Events config
                    ADR_EVT_CFG: begin
                        // EVT_EN lives in bits [7:0]; reserved bits ignore writes.
                        // Honor byte-enables (all bits are in byte lane 0).
                        if (wbs_sel_i[0]) r_evt_en <= wbs_dat_i[7:0];
                    end

                    ADR_EVT_THRESH_CH0: r_evt_thresh[0] <= apply_wstrb(r_evt_thresh[0], wbs_dat_i, wbs_sel_i);
                    ADR_EVT_THRESH_CH1: r_evt_thresh[1] <= apply_wstrb(r_evt_thresh[1], wbs_dat_i, wbs_sel_i);
                    ADR_EVT_THRESH_CH2: r_evt_thresh[2] <= apply_wstrb(r_evt_thresh[2], wbs_dat_i, wbs_sel_i);
                    ADR_EVT_THRESH_CH3: r_evt_thresh[3] <= apply_wstrb(r_evt_thresh[3], wbs_dat_i, wbs_sel_i);
                    ADR_EVT_THRESH_CH4: r_evt_thresh[4] <= apply_wstrb(r_evt_thresh[4], wbs_dat_i, wbs_sel_i);
                    ADR_EVT_THRESH_CH5: r_evt_thresh[5] <= apply_wstrb(r_evt_thresh[5], wbs_dat_i, wbs_sel_i);
                    ADR_EVT_THRESH_CH6: r_evt_thresh[6] <= apply_wstrb(r_evt_thresh[6], wbs_dat_i, wbs_sel_i);
                    ADR_EVT_THRESH_CH7: r_evt_thresh[7] <= apply_wstrb(r_evt_thresh[7], wbs_dat_i, wbs_sel_i);

                    default: ;
                endcase
            end

            // FIFO pop on read of ADC_FIFO_DATA
            if (wb_fire && ~wbs_we_i && (wb_adr_aligned == ADR_ADC_FIFO_DATA)) begin
                if (r_adc_fifo_level != 16'h0) begin
                    r_adc_fifo_rd    <= r_adc_fifo_rd + {{(ADC_FIFO_AW-1){1'b0}},1'b1};
                    r_adc_fifo_level <= r_adc_fifo_level - 16'h1;
                end
            end

            // ADC snapshot behavior (stub): on SNAPSHOT pulse, update raw regs so
            // firmware can observe changing values even before ADC integration.
            if (adc_snapshot_fire) begin
                r_adc_snapshot_count <= r_adc_snapshot_count + 32'h1;
                for (i = 0; i < 8; i = i + 1) begin
                    // Deterministic pattern: base + snapshot_count + channel index
                    r_adc_raw[i] <= 32'h0000_1000 + (r_adc_snapshot_count + 32'h1) + i[31:0];
                end

                // Also push a frame into the streaming FIFO to exercise firmware
                // integration before the real ADC capture path lands.
                // Packing matches spec/regmap.md: status word then CH0..CH7.
                adc_fifo_push(32'h0);
                for (i = 0; i < 8; i = i + 1) begin
                    adc_fifo_push(32'h0000_1000 + (r_adc_snapshot_count + 32'h1) + i[31:0]);
                end
            end
        end
    end

endmodule

`default_nettype wire
