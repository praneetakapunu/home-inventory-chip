// Smoke test for home_inventory_wb Wishbone register block
//
// Focus: basic read/write paths + pulse semantics.
//
// Run via:
//   make -C verify sim

`timescale 1ns/1ps
`default_nettype none

module wb_tb;
    reg         clk;
    reg         rst;

    reg         wbs_stb_i;
    reg         wbs_cyc_i;
    reg         wbs_we_i;
    reg  [3:0]  wbs_sel_i;
    reg  [31:0] wbs_dat_i;
    reg  [31:0] wbs_adr_i;
    wire        wbs_ack_o;
    wire [31:0] wbs_dat_o;

    reg  [7:0]  core_status;
    wire        ctrl_enable;
    wire        ctrl_start;
    wire [2:0]  irq_en;

    // DUT
    home_inventory_wb dut (
        .wb_clk_i(clk),
        .wb_rst_i(rst),
        .wbs_stb_i(wbs_stb_i),
        .wbs_cyc_i(wbs_cyc_i),
        .wbs_we_i(wbs_we_i),
        .wbs_sel_i(wbs_sel_i),
        .wbs_dat_i(wbs_dat_i),
        .wbs_adr_i(wbs_adr_i),
        .wbs_ack_o(wbs_ack_o),
        .wbs_dat_o(wbs_dat_o),
        .core_status(core_status),
        .ctrl_enable(ctrl_enable),
        .ctrl_start(ctrl_start),
        .irq_en(irq_en)
    );

    // Clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    localparam [31:0] ADR_ID      = 32'h0000_0000;
    localparam [31:0] ADR_VERSION = 32'h0000_0004;
    localparam [31:0] ADR_CTRL    = 32'h0000_0100;
    localparam [31:0] ADR_IRQ_EN  = 32'h0000_0104;
    localparam [31:0] ADR_STATUS  = 32'h0000_0108;

    task automatic wb_idle;
        begin
            wbs_stb_i = 1'b0;
            wbs_cyc_i = 1'b0;
            wbs_we_i  = 1'b0;
            wbs_sel_i = 4'h0;
            wbs_dat_i = 32'h0;
            wbs_adr_i = 32'h0;
        end
    endtask

    task automatic wb_write32(input [31:0] adr, input [31:0] data);
        begin
            @(negedge clk);
            wbs_adr_i = adr;
            wbs_dat_i = data;
            wbs_sel_i = 4'hF;
            wbs_we_i  = 1'b1;
            wbs_cyc_i = 1'b1;
            wbs_stb_i = 1'b1;

            // Wait for ack
            while (wbs_ack_o !== 1'b1) begin
                @(negedge clk);
            end

            // Deassert next cycle
            @(negedge clk);
            wb_idle();
        end
    endtask

    task automatic wb_read32(input [31:0] adr, output [31:0] data);
        begin
            @(negedge clk);
            wbs_adr_i = adr;
            wbs_sel_i = 4'hF;
            wbs_we_i  = 1'b0;
            wbs_cyc_i = 1'b1;
            wbs_stb_i = 1'b1;

            while (wbs_ack_o !== 1'b1) begin
                @(negedge clk);
            end

            data = wbs_dat_o;

            @(negedge clk);
            wb_idle();
        end
    endtask

    reg [31:0] rdata;

    initial begin
        $display("[tb] start");
        wb_idle();
        core_status = 8'hA5;

        // Reset
        rst = 1'b1;
        repeat (5) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        // ID/version reads
        wb_read32(ADR_ID, rdata);
        if (rdata !== 32'h4849_4348) begin
            $display("[tb] ERROR: ID mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        wb_read32(ADR_VERSION, rdata);
        if (rdata !== 32'h0000_0001) begin
            $display("[tb] ERROR: VERSION mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        // STATUS readback passes through core_status
        wb_read32(ADR_STATUS, rdata);
        if (rdata[7:0] !== 8'hA5) begin
            $display("[tb] ERROR: STATUS mismatch: got 0x%08x", rdata);
            $fatal(1);
        end

        // CTRL.ENABLE sticky bit
        wb_write32(ADR_CTRL, 32'h0000_0001);
        if (ctrl_enable !== 1'b1) begin
            $display("[tb] ERROR: ctrl_enable not set");
            $fatal(1);
        end

        // CTRL.START is a 1-cycle pulse on write-1
        // (We sample on posedge after write.)
        wb_write32(ADR_CTRL, 32'h0000_0002);
        @(posedge clk);
        if (ctrl_start !== 1'b1) begin
            $display("[tb] ERROR: ctrl_start did not pulse");
            $fatal(1);
        end
        @(posedge clk);
        if (ctrl_start !== 1'b0) begin
            $display("[tb] ERROR: ctrl_start did not clear");
            $fatal(1);
        end

        // IRQ_EN byte writes supported (check low byte)
        wb_write32(ADR_IRQ_EN, 32'h0000_0007);
        if (irq_en !== 3'b111) begin
            $display("[tb] ERROR: irq_en mismatch: got %b", irq_en);
            $fatal(1);
        end

        $display("[tb] PASS");
        $finish;
    end

endmodule

`default_nettype wire
