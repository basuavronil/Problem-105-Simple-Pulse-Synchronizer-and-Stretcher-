// -----------------------------------------------------------------------------
// Pulse Synchronizer & Stretcher  --  FSM based
//
//   async_pulse -> [capture flop] -> [2-FF sync] -> FSM -> pulse_out (4 cycles)
//
// FSM (Moore, state[2] doubles as the output bit => glitch-free pulse_out):
//
//        sync2=1                                  sync2=0
//   IDLE ------> P1 -> P2 -> P3 -> P4 -> WAIT ------------> IDLE
//   (0_00)     (1_00)(1_01)(1_10)(1_11) (0_01)     (WAIT holds while sync2=1)
//
//   pulse_out = 1 in P1,P2,P3,P4  -> exactly 4 clk cycles
//   clr_req   = 1 in P1,P2,P3     -> clears the capture flop (handshake)
// -----------------------------------------------------------------------------
module pulse_sync_stretch (
    input  wire clk,
    input  wire rst_n,        // active-low async reset (clk domain)
    input  wire async_pulse,  // asynchronous input pulse (any width)
    output wire pulse_out     // 4-cycle stretched, synchronized output
);

    // ---------------- State encoding: {out, cnt[1:0]} ----------------
    localparam [2:0] IDLE = 3'b000,
                     WAIT = 3'b001,
                     P1   = 3'b100,
                     P2   = 3'b101,
                     P3   = 3'b110,
                     P4   = 3'b111;

    reg [2:0] state, next_state;

    // ---------------- Async event capture (never misses a pulse) ----------
    reg cap;
    reg clr_q;                       // FSM-driven clear (registered, glitch-free)

    always @(posedge async_pulse or posedge clr_q)
        if (clr_q) cap <= 1'b0;
        else       cap <= 1'b1;

    // ---------------- 2-FF synchronizer ----------------
    reg sync1, sync2;

    always @(posedge clk or negedge rst_n)
        if (!rst_n) {sync2, sync1} <= 2'b00;
        else        {sync2, sync1} <= {sync1, cap};

    // ---------------- FSM: state register ----------------
    always @(posedge clk or negedge rst_n)
        if (!rst_n) state <= IDLE;
        else        state <= next_state;

    // ---------------- FSM: next-state logic ----------------
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:    if (sync2)  next_state = P1;     // event detected
            P1:                  next_state = P2;
            P2:                  next_state = P3;
            P3:                  next_state = P4;
            P4:                  next_state = WAIT;
            WAIT:    if (!sync2) next_state = IDLE;   // flag cleared, re-arm
            default:             next_state = IDLE;
        endcase
    end

    // ---------------- FSM: output logic (Moore) ----------------
    assign pulse_out = state[2];                      // high in P1..P4

    always @(posedge clk or negedge rst_n)
        if (!rst_n) clr_q <= 1'b0;
        else        clr_q <= (next_state == P1) ||
                             (next_state == P2) ||
                             (next_state == P3);      // high during P1..P3

endmodule
