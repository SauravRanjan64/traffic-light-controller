`timescale 1ns / 1ps
//==============================================================================
// Module  : Traffic_Light_Controller
// Purpose : Fixed-time traffic light controller for a T-junction.
// Type    : Moore FSM (6 states) + down-count style timer
//
// Light encoding (per output, 3 bits):  [2] = Red, [1] = Yellow, [0] = Green
//   3'b100 = RED     3'b010 = YELLOW     3'b001 = GREEN
//
// Timing  : One clk cycle represents one "second". Every state lasts exactly
//           its configured number of clock cycles.
//
// Reset   : Asynchronous, active high. Forces the FSM to S1 with timer = 0.
//==============================================================================
module Traffic_Light_Controller #(
    parameter [3:0] TMG = 4'd7,   // S1: main-road green time (M1 + M2)
    parameter [3:0] TY  = 4'd2,   // S2, S4, S6: yellow time
    parameter [3:0] TTG = 4'd5,   // S3: main-road turn green time (M1 + MT)
    parameter [3:0] TSG = 4'd3    // S5: side-road green time (S)
) (
    input            clk,
    input            rst,
    output reg [2:0] light_M1,    // main road, straight
    output reg [2:0] light_MT,    // main road, turning into side road
    output reg [2:0] light_M2,    // main road, opposite direction
    output reg [2:0] light_S      // side road
);

    // ---------------- State encoding ----------------
    localparam [2:0] S1 = 3'd0,   // M1 G, M2 G, MT R, S R
                     S2 = 3'd1,   // M1 G, M2 Y, MT R, S R
                     S3 = 3'd2,   // M1 G, M2 R, MT G, S R
                     S4 = 3'd3,   // M1 Y, M2 R, MT Y, S R
                     S5 = 3'd4,   // M1 R, M2 R, MT R, S G
                     S6 = 3'd5;   // M1 R, M2 R, MT R, S Y

    // ---------------- Light colours ----------------
    localparam [2:0] RED = 3'b100,
                     YEL = 3'b010,
                     GRN = 3'b001;

    reg [2:0] ps, ns;             // present state, next state
    reg [3:0] count;              // cycles elapsed in the current state
    reg [3:0] limit;              // duration (cycles) of the current state

    // ---------------- Duration of current state ----------------
    always @(*) begin
        case (ps)
            S1:      limit = TMG;
            S2:      limit = TY;
            S3:      limit = TTG;
            S4:      limit = TY;
            S5:      limit = TSG;
            S6:      limit = TY;
            default: limit = TMG;
        endcase
    end

    // ---------------- Next-state logic (strict cycle) ----------------
    always @(*) begin
        case (ps)
            S1:      ns = S2;
            S2:      ns = S3;
            S3:      ns = S4;
            S4:      ns = S5;
            S5:      ns = S6;
            S6:      ns = S1;
            default: ns = S1;
        endcase
    end

    // ---------------- State register + timer ----------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ps    <= S1;
            count <= 4'd0;
        end else if (count == limit - 4'd1) begin
            ps    <= ns;
            count <= 4'd0;
        end else begin
            count <= count + 4'd1;
        end
    end

    // ---------------- Output logic (Moore) ----------------
    always @(*) begin
        case (ps)
            S1: begin light_M1 = GRN; light_M2 = GRN; light_MT = RED; light_S = RED; end
            S2: begin light_M1 = GRN; light_M2 = YEL; light_MT = RED; light_S = RED; end
            S3: begin light_M1 = GRN; light_M2 = RED; light_MT = GRN; light_S = RED; end
            S4: begin light_M1 = YEL; light_M2 = RED; light_MT = YEL; light_S = RED; end
            S5: begin light_M1 = RED; light_M2 = RED; light_MT = RED; light_S = GRN; end
            S6: begin light_M1 = RED; light_M2 = RED; light_MT = RED; light_S = YEL; end
            default: begin
                light_M1 = RED; light_M2 = RED; light_MT = RED; light_S = RED;
            end
        endcase
    end

endmodule
