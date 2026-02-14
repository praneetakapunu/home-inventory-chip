// Home Inventory Chip - Wishbone register block (OpenMPW / Caravel)
//
// This module is meant to be instantiated by the OpenMPW harness repo
// (home-inventory-chip-openmpw) as the design-under-test.
//
// Current scope:
// - Provide a stable Wishbone register file for bring-up
// - Expose a minimal control plane (CTRL/IRQ_EN) and status readback
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

    // ---------------------------------------------------------------------
    // Registers
    // ---------------------------------------------------------------------
    reg [31:0] r_ctrl;
    reg [31:0] r_irq_en;

    // Decode fields
    assign ctrl_enable = r_ctrl[0];
    assign ctrl_start  = r_ctrl[1];
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

    // Read mux (combinational)
    reg [31:0] rd_data;
    always @(*) begin
        rd_data = 32'h0;
        case (wbs_adr_i)
            ADR_ID:      rd_data = 32'h4849_4348; // 'HICH' (Home Inventory CHip)
            ADR_VERSION: rd_data = 32'h0000_0001;

            ADR_CTRL:    rd_data = r_ctrl;
            ADR_IRQ_EN:  rd_data = r_irq_en;
            ADR_STATUS:  rd_data = {24'h0, core_status};
            default:     rd_data = 32'h0;
        endcase
    end

    always @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            wbs_ack_o <= 1'b0;
            wbs_dat_o <= 32'h0;
            r_ctrl    <= 32'h0;
            r_irq_en  <= 32'h0;
        end else begin
            // ACK pulse for each accepted request.
            wbs_ack_o <= wb_valid & ~wbs_ack_o;

            // Latch read data on accept (works for both reads and writes).
            if (wb_fire) begin
                wbs_dat_o <= rd_data;
            end

            // Writes
            if (wb_fire && wbs_we_i) begin
                case (wbs_adr_i)
                    ADR_CTRL:   r_ctrl   <= apply_wstrb(r_ctrl,   wbs_dat_i, wbs_sel_i);
                    ADR_IRQ_EN: r_irq_en <= apply_wstrb(r_irq_en, wbs_dat_i, wbs_sel_i);
                    default: ;
                endcase
            end
        end
    end

endmodule

`default_nettype wire
