// -----------------------------------------------------------------------------
// Simple Pulse Synchronizer & Stretcher
//
// - async_pulse : asynchronous input pulse (can be shorter than one clk period)
// - pulse_out   : guaranteed 4-cycle high pulse in the clk domain
//
// Architecture:
//   1. Capture flop : set asynchronously by async_pulse so it can never be
//                     missed; cleared by the FSM once the event is consumed.
//   2. 2-FF sync    : brings the captured flag into the clk domain safely.
//   3. FSM          : IDLE -> P1 -> P2 -> P3 -> P4 -> WAIT_CLR -> IDLE
//                     pulse_out is high for exactly P1..P4 (4 cycles).
//   4. WAIT_CLR     : waits until the synchronized flag has dropped so the
//                     same pulse is never counted twice.
// -----------------------------------------------------------------------------
module pulse_sync_stretch (
    input  wire clk,
    input  wire rst_n,        // active-low synchronous reset (clk domain)
    input  wire async_pulse,  // asynchronous input pulse
    output reg  pulse_out     // 4-cycle stretched, synchronized output
);

    // ---------------- State encoding ----------------
    localparam [2:0] IDLE     = 3'd0,
                     P1       = 3'd1,
                     P2       = 3'd2,
                     P3       = 3'd3,
                     P4       = 3'd4,
                     WAIT_CLR = 3'd5;

    reg [2:0] state, next_state;

    // ---------------- 1. Async capture flop ----------------
    reg  cap;
    reg  clr_q;                       // registered clear request (clk domain)

    always @(posedge async_pulse or posedge clr_q) begin
        if (clr_q) cap <= 1'b0;
        else       cap <= 1'b1;
    end

    // ---------------- 2. Two-flop synchronizer ----------------
    reg sync1, sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
        end else begin
            sync1 <= cap;
            sync2 <= sync1;
        end
    end

    // ---------------- 3. FSM ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE:     if (sync2)  next_state = P1;
            P1:                   next_state = P2;
            P2:                   next_state = P3;
            P3:                   next_state = P4;
            P4:                   next_state = WAIT_CLR;
            WAIT_CLR: if (!sync2) next_state = IDLE;
            default:              next_state = IDLE;
        endcase
    end

    // ---------------- Registered outputs ----------------
    // pulse_out is registered from next_state so it is glitch-free and
    // aligned with the state: high during P1,P2,P3,P4 (exactly 4 cycles).
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pulse_out <= 1'b0;
            clr_q     <= 1'b0;
        end else begin
            pulse_out <= (next_state == P1) || (next_state == P2) ||
                         (next_state == P3) || (next_state == P4);
            // Clear the capture flop while the pulse is being produced
            clr_q     <= (next_state == P1) || (next_state == P2) ||
                         (next_state == P3);
        end
    end

endmodule
