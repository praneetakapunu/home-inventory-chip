// adc_stream_fifo_tb.v
//
// Minimal directed tests for rtl/adc/adc_stream_fifo.v
// - push/pop basic ordering
// - level_words tracking
// - sticky overrun when pushing while full
// - overrun_clear behavior

`timescale 1ns/1ps
`default_nettype none

module adc_stream_fifo_tb;

  localparam integer DEPTH_WORDS = 8;

  reg clk = 1'b0;
  always #5 clk = ~clk;

  reg rst;

  reg        push_valid;
  reg [31:0] push_data;
  wire       push_ready;

  wire       pop_valid;
  wire [31:0] pop_data;
  reg        pop_ready;

  wire [3:0] level_words;
  wire overrun_sticky;
  reg  overrun_clear;

  adc_stream_fifo #(
    .DEPTH_WORDS(DEPTH_WORDS)
  ) dut (
    .clk(clk),
    .rst(rst),

    .push_valid(push_valid),
    .push_data(push_data),
    .push_ready(push_ready),

    .pop_valid(pop_valid),
    .pop_data(pop_data),
    .pop_ready(pop_ready),

    .level_words(level_words),
    .overrun_sticky(overrun_sticky),
    .overrun_clear(overrun_clear)
  );

  integer i;
  integer popped;

  task tick;
    begin
      @(posedge clk);
      #1; // allow combinational settle
    end
  endtask

  task tb_expect;
    input cond;
    input [8*128-1:0] msg;
    begin
      if (!cond) begin
        $display("FAIL: %0s", msg);
        $fatal(1);
      end
    end
  endtask

  initial begin
    $display("adc_stream_fifo_tb: start");

    rst = 1'b1;
    push_valid = 1'b0;
    push_data  = 32'h0;
    pop_ready  = 1'b0;
    overrun_clear = 1'b0;

    tick();
    tick();
    rst = 1'b0;
    tick();

    tb_expect(level_words == 0, "level_words should be 0 after reset");
    tb_expect(overrun_sticky == 1'b0, "overrun_sticky should be 0 after reset");
    tb_expect(pop_valid == 1'b0, "pop_valid should be 0 when empty");

    // Fill FIFO to full.
    for (i = 0; i < DEPTH_WORDS; i = i + 1) begin
      push_valid = 1'b1;
      push_data  = 32'hA5A5_0000 + i;
      #1;
      tb_expect(push_ready == 1'b1, "push_ready should be 1 while filling");
      tick();
    end
    push_valid = 1'b0;
    tick();

    tb_expect(level_words == DEPTH_WORDS[3:0], "level_words should equal DEPTH_WORDS when full");
    tb_expect(push_ready == 1'b0, "push_ready should be 0 when full");

    // Attempt an overflow push (should set sticky overrun).
    push_valid = 1'b1;
    push_data  = 32'hDEAD_BEEF;
    tick();
    push_valid = 1'b0;
    tick();

    tb_expect(overrun_sticky == 1'b1, "overrun_sticky should set when pushing while full");

    // Drain FIFO and check ordering.
    popped = 0;
    pop_ready = 1'b1;
    while (popped < DEPTH_WORDS) begin
      #1;
      if (pop_valid) begin
        tb_expect(pop_data == (32'hA5A5_0000 + popped), "pop_data ordering mismatch");
        popped = popped + 1;
      end
      tick();
    end

    pop_ready = 1'b0;
    tick();

    tb_expect(level_words == 0, "level_words should return to 0 after draining");
    tb_expect(pop_valid == 1'b0, "pop_valid should be 0 after draining");

    // Clear sticky flag.
    overrun_clear = 1'b1;
    tick();
    overrun_clear = 1'b0;
    tick();

    tb_expect(overrun_sticky == 1'b0, "overrun_sticky should clear with overrun_clear");

    $display("adc_stream_fifo_tb: PASS");
    $finish;
  end

endmodule

`default_nettype wire
