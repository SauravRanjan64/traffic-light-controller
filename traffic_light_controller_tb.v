`timescale 1ns / 1ps
//==============================================================================
// Self-checking testbench for Traffic_Light_Controller.
// - 10 ns clock; each clock cycle represents one second.
// - Checks that every state lasts its specified duration (7,2,5,2,3,2).
// - Checks the light outputs in every state.
// - Applies a mid-run reset and checks recovery to S1.
// - Prints PASS / FAIL at the end.
//
// Note: the checkers sample 1 ns after each rising edge, so they see the
//       updated value of ps. Reset forces S1 asynchronously (no clock edge
//       "enters" S1), so a sample taken while rst is high counts as the first
//       cycle of S1.
//==============================================================================
module Traffic_Light_Controller_TB;

    localparam [2:0] RED = 3'b100, YEL = 3'b010, GRN = 3'b001;

    reg        clk, rst;
    wire [2:0] light_M1, light_MT, light_M2, light_S;

    Traffic_Light_Controller dut (
        .clk(clk),
        .rst(rst),
        .light_M1(light_M1),
        .light_MT(light_MT),
        .light_M2(light_M2),
        .light_S(light_S)
    );

    // Hierarchical references (for monitoring)
    wire [2:0] ps    = dut.ps;
    wire [3:0] count = dut.count;

    // ---------------- Clock (10 ns period) ----------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---------------- Expected durations ----------------
    integer expected_len [0:5];
    initial begin
        expected_len[0] = 7;  // S1
        expected_len[1] = 2;  // S2
        expected_len[2] = 5;  // S3
        expected_len[3] = 2;  // S4
        expected_len[4] = 3;  // S5
        expected_len[5] = 2;  // S6
    end

    integer errors  = 0;
    integer checks  = 0;
    integer run_len = 0;
    integer prev_ps = -1;     // -1 = no valid previous state

    // ---------------- Duration checker ----------------
    // Sample after the NBA region so we see the NEW value of ps
    // on the transition edge.
    always @(posedge clk) begin
        #1;                                 // let non-blocking updates complete
        if (rst) begin
            prev_ps = 0;                    // reset forces S1: count this cycle
            run_len = 1;                    // as the first cycle of S1
        end else begin
            if (ps == prev_ps) begin
                run_len = run_len + 1;
            end else begin
                if (prev_ps >= 0) begin
                    checks = checks + 1;
                    if (run_len !== expected_len[prev_ps]) begin
                        errors = errors + 1;
                        $display("FAIL t=%0t: S%0d lasted %0d s, expected %0d s",
                                 $time, prev_ps + 1, run_len, expected_len[prev_ps]);
                    end else begin
                        $display("ok   t=%0t: S%0d lasted %0d s",
                                 $time, prev_ps + 1, run_len);
                    end
                end
                run_len = 1;
            end
            prev_ps = ps;
        end
    end

    // ---------------- Output checker ----------------
    task check_lights;
        input [2:0] m1, mt, m2, s;
        begin
            checks = checks + 1;
            if ({light_M1, light_MT, light_M2, light_S} !== {m1, mt, m2, s}) begin
                errors = errors + 1;
                $display("FAIL t=%0t: S%0d lights M1=%b MT=%b M2=%b S=%b  (expected %b %b %b %b)",
                         $time, ps + 1,
                         light_M1, light_MT, light_M2, light_S,
                         m1, mt, m2, s);
            end
        end
    endtask

    // Sample outputs shortly after each rising edge
    always @(posedge clk) begin
        #1;
        if (!rst) begin
            case (ps)
                3'd0: check_lights(GRN, RED, GRN, RED);  // S1
                3'd1: check_lights(GRN, RED, YEL, RED);  // S2
                3'd2: check_lights(GRN, GRN, RED, RED);  // S3
                3'd3: check_lights(YEL, YEL, RED, RED);  // S4
                3'd4: check_lights(RED, RED, RED, GRN);  // S5
                3'd5: check_lights(RED, RED, RED, YEL);  // S6
                default: begin
                    errors = errors + 1;
                    $display("FAIL t=%0t: illegal state %0d", $time, ps);
                end
            endcase
        end
    end

    // ---------------- Stimulus ----------------
    initial begin
        $dumpfile("build/waves.vcd");
        $dumpvars(0, Traffic_Light_Controller_TB);

        // Apply reset
        rst = 1'b1;
        #22;
        rst = 1'b0;

        // Three full 21-second cycles
        repeat (21 * 3) @(posedge clk);

        // Mid-run asynchronous reset: must return to S1 with count = 0
        #3  rst = 1'b1;
        #10;                                // hold reset across a clock edge
        checks = checks + 1;
        if (ps !== 3'd0 || count !== 4'd0) begin
            errors = errors + 1;
            $display("FAIL: reset did not return FSM to S1 (ps=%0d count=%0d)",
                     ps, count);
        end
        rst = 1'b0;

        // One more full cycle after reset
        repeat (21 + 2) @(posedge clk);

        $display("------------------------------------------------");
        if (errors == 0)
            $display("PASS: %0d checks, 0 errors", checks);
        else
            $display("FAIL: %0d checks, %0d errors", checks, errors);
        $display("------------------------------------------------");
        $finish;
    end

endmodule
