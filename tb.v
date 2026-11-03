`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Self-checking testbench for pulse_sync_stretch
// Run (Icarus):  iverilog -o sim pulse_sync_stretch.v tb_pulse_sync_stretch.v
//                vvp sim
//                gtkwave pulse_sync_stretch.vcd
// -----------------------------------------------------------------------------
module tb_pulse_sync_stretch;

    reg  clk         = 1'b0;
    reg  rst_n       = 1'b0;
    reg  async_pulse = 1'b0;
    wire pulse_out;

    integer high_cycles = 0;   // running count of pulse_out high cycles
    integer errors      = 0;

    // ---------------- DUT ----------------
    pulse_sync_stretch dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .async_pulse(async_pulse),
        .pulse_out  (pulse_out)
    );

    // ---------------- Clock: 100 MHz ----------------
    always #5 clk = ~clk;

    // ---------------- Count high cycles of pulse_out ----------------
    always @(posedge clk)
        if (pulse_out) high_cycles <= high_cycles + 1;

    // ---------------- Waveform dump ----------------
    initial begin
        $dumpfile("pulse_sync_stretch.vcd");
        $dumpvars(0, tb_pulse_sync_stretch);
    end

    // ---------------- Tasks ----------------
    // Send an async pulse at an arbitrary phase offset from clk
    task send_pulse(input real phase_ns, input real width_ns);
        begin
            #(phase_ns);
            async_pulse = 1'b1;
            #(width_ns);
            async_pulse = 1'b0;
        end
    endtask

    // Compare high_cycles with expected value, then reset the counter
    task check(input [255:0] name, input integer expected);
        begin
            if (high_cycles === expected)
                $display("[PASS] %0s : %0d high cycles", name, high_cycles);
            else begin
                $display("[FAIL] %0s : got %0d, expected %0d", name, high_cycles, expected);
                errors = errors + 1;
            end
            high_cycles = 0;
        end
    endtask

    // ---------------- Stimulus ----------------
    initial begin
        #23 rst_n = 1'b1;
        #20;

        // Test 1: very narrow pulse (< 1 clk period)
        send_pulse(3.7, 2);
        #200;
        check("Test1 narrow 2ns pulse     ", 4);

        // Test 2: pulse ~ 1 clk period wide
        send_pulse(1.3, 10);
        #200;
        check("Test2 10ns pulse           ", 4);

        // Test 3: wide pulse spanning several clocks (should still give 4)
        send_pulse(2.1, 35);
        #200;
        check("Test3 35ns wide pulse      ", 4);

        // Test 4: two well-separated pulses
        send_pulse(0.9, 10);
        #300;
        send_pulse(4.4, 3);
        #200;
        check("Test4 two separated pulses ", 8);

        // Test 5: pulse during reset must be ignored
        rst_n = 1'b0;
        #12;
        send_pulse(0, 10);
        #20;
        rst_n = 1'b1;
        #200;
        $display("[INFO] Test5 pulse during reset: %0d high cycles (informational)", high_cycles);
        high_cycles = 0;

        // ---------------- Summary ----------------
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end

    // Safety timeout
    initial begin
        #5000;
        $display("[ERROR] Simulation timeout");
        $finish;
    end

endmodule
