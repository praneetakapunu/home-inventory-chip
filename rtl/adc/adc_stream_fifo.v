// adc_stream_fifo.v
//
// Simple synchronous FIFO for streaming 32-bit ADC words into a firmware-drained
// Wishbone register interface.
//
// Features (v1):
// - push/pop handshake
// - level_words output (0..DEPTH_WORDS)
// - sticky overrun flag when push attempted while full
// - explicit clear for overrun flag (W1C at reg-level)

`default_nettype none

module adc_stream_fifo #(
    parameter integer DEPTH_WORDS = 64
) (
    input  wire        clk,
    input  wire        rst,

    // Push side
    input  wire        push_valid,
    input  wire [31:0] push_data,
    output wire        push_ready,

    // Pop side
    output wire        pop_valid,
    output wire [31:0] pop_data,
    input  wire        pop_ready,

    // Status
    // Use an explicit $clog2() expression here so the width is legal in the port list.
    output wire [$clog2(DEPTH_WORDS+1)-1:0] level_words,
    output wire        overrun_sticky,
    input  wire        overrun_clear
);

    localparam integer COUNT_W = $clog2(DEPTH_WORDS+1);

    // Synthesis-time guardrail.
    initial begin
        if (DEPTH_WORDS < 2) $fatal(1, "DEPTH_WORDS must be >= 2");
    end

    localparam integer ADDR_W = $clog2(DEPTH_WORDS);

    reg [31:0] mem [0:DEPTH_WORDS-1];

    reg [ADDR_W-1:0] rd_ptr;
    reg [ADDR_W-1:0] wr_ptr;
    reg [COUNT_W-1:0] count;

    reg overrun;

    wire full  = (count == DEPTH_WORDS[COUNT_W-1:0]);
    wire empty = (count == {COUNT_W{1'b0}});

    assign push_ready = ~full;
    assign pop_valid  = ~empty;
    assign pop_data   = mem[rd_ptr];

    assign level_words    = count;
    assign overrun_sticky = overrun;

    wire do_push = push_valid && push_ready;
    wire do_pop  = pop_valid && pop_ready;

    always @(posedge clk) begin
        if (rst) begin
            rd_ptr  <= {ADDR_W{1'b0}};
            wr_ptr  <= {ADDR_W{1'b0}};
            count   <= {COUNT_W{1'b0}};
            overrun <= 1'b0;
        end else begin
            // Clear sticky overrun (reg-level W1C drives overrun_clear)
            if (overrun_clear) overrun <= 1'b0;

            // Detect overflow attempt
            if (push_valid && ~push_ready) overrun <= 1'b1;

            // Write
            if (do_push) begin
                mem[wr_ptr] <= push_data;
                wr_ptr <= wr_ptr + {{(ADDR_W-1){1'b0}}, 1'b1};
            end

            // Read pointer advance
            if (do_pop) begin
                rd_ptr <= rd_ptr + {{(ADDR_W-1){1'b0}}, 1'b1};
            end

            // Count update
            case ({do_push, do_pop})
                2'b10: count <= count + {{(COUNT_W-1){1'b0}}, 1'b1};
                2'b01: count <= count - {{(COUNT_W-1){1'b0}}, 1'b1};
                default: count <= count;
            endcase
        end
    end

endmodule

`default_nettype wire
