`timescale 1ns/1ps
module tb_pulse_sync_stretch;

    reg  clk = 0;
    reg  rst_n = 0;
    reg  async_pulse = 0;
    wire pulse_out;

    pulse_sync_stretch dut (
        .clk(clk), .rst_n(rst_n),
        .async_pulse(async_pulse), .pulse_out(pulse_out)
    );

    always #5 clk = ~clk;   // 100 MHz

    // Count high cycles of pulse_out
    integer high_cycles = 0;
    always @(posedge clk) if (pulse_out) high_cycles <= high_cycles + 1;

    task send_pulse(input integer width_ns);
        begin
            #(3.7);                 // arbitrary phase vs. clk
            async_pulse = 1;
            #(width_ns);
            async_pulse = 0;
        end
    endtask

    initial begin
        $dumpfile("pulse_sync_stretch.vcd");
        $dumpvars(0, tb_pulse_sync_stretch);

        #23 rst_n = 1;

        // Test 1: very narrow pulse (shorter than a clk period)
        send_pulse(2);
        #200;
        $display("Test1 (2ns pulse)  : pulse_out high cycles = %0d (expect 4)", high_cycles);

        // Test 2: pulse about one clk period wide
        high_cycles = 0;
        send_pulse(10);
        #200;
        $display("Test2 (10ns pulse) : pulse_out high cycles = %0d (expect 4)", high_cycles);

        // Test 3: two well-separated pulses
        high_cycles = 0;
        send_pulse(10);
        #300;
        send_pulse(10);
        #200;
        $display("Test3 (2 pulses)   : pulse_out high cycles = %0d (expect 8)", high_cycles);

        $finish;
    end

endmodule
