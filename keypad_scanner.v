`timescale 1ns/1ps
// ============================================================================
// keypad_scanner : Digilent Pmod KYPD (4x4 hex keypad)
//   col_n[k] = COL(k+1)  (driven, active low)
//   row_n[k] = ROW(k+1)  (input, low = pressed, needs pull-up)
//   Keys:   COL1 COL2 COL3 COL4
//    ROW1 :   1    2    3    A
//    ROW2 :   4    5    6    B
//    ROW3 :   7    8    9    C
//    ROW4 :   0    F    E    D
//   key_valid pulses for one clock when a debounced key press is accepted.
// ============================================================================
module keypad_scanner #(
    parameter SETTLE = 12500,      // 100 us @125 MHz
    parameter DEB    = 1250000     // 10 ms  @125 MHz
) (
    input  wire       clk,
    input  wire       rst,
    output reg  [3:0] col_n,
    input  wire [3:0] row_n,
    output reg  [3:0] key,
    output reg        key_valid
);
    reg [3:0] rs1, rs2;
    always @(posedge clk) begin rs1 <= row_n; rs2 <= rs1; end

    function [3:0] decode(input [1:0] c, input [3:0] r);
        reg [1:0] ri;
        begin
            if      (!r[0]) ri = 2'd0;
            else if (!r[1]) ri = 2'd1;
            else if (!r[2]) ri = 2'd2;
            else            ri = 2'd3;
            case ({c, ri})
                4'b00_00: decode = 4'h1;  4'b00_01: decode = 4'h4;
                4'b00_10: decode = 4'h7;  4'b00_11: decode = 4'h0;
                4'b01_00: decode = 4'h2;  4'b01_01: decode = 4'h5;
                4'b01_10: decode = 4'h8;  4'b01_11: decode = 4'hF;
                4'b10_00: decode = 4'h3;  4'b10_01: decode = 4'h6;
                4'b10_10: decode = 4'h9;  4'b10_11: decode = 4'hE;
                4'b11_00: decode = 4'hA;  4'b11_01: decode = 4'hB;
                4'b11_10: decode = 4'hC;  4'b11_11: decode = 4'hD;
                default : decode = 4'h0;
            endcase
        end
    endfunction

    localparam S_SETTLE = 2'd0, S_SAMPLE = 2'd1, S_DEBOUNCE = 2'd2, S_RELEASE = 2'd3;
    reg [1:0]  st;
    reg [1:0]  col;
    reg [21:0] cnt;

    always @(posedge clk) begin
        key_valid <= 1'b0;
        if (rst) begin
            st <= S_SETTLE; col <= 2'd0; cnt <= 22'd0;
            col_n <= 4'b1111; key <= 4'h0;
        end else begin
            col_n <= ~(4'b0001 << col);          // active column driven low
            case (st)
                S_SETTLE: begin
                    if (cnt == SETTLE) begin cnt <= 0; st <= S_SAMPLE; end
                    else cnt <= cnt + 1'b1;
                end
                S_SAMPLE: begin
                    if (rs2 != 4'b1111) begin cnt <= 0; st <= S_DEBOUNCE; end
                    else begin col <= col + 1'b1; cnt <= 0; st <= S_SETTLE; end
                end
                S_DEBOUNCE: begin
                    if (cnt == DEB) begin
                        cnt <= 0;
                        if (rs2 != 4'b1111) begin
                            key <= decode(col, rs2);
                            key_valid <= 1'b1;
                            st <= S_RELEASE;
                        end else begin
                            col <= col + 1'b1; st <= S_SETTLE;
                        end
                    end else cnt <= cnt + 1'b1;
                end
                S_RELEASE: begin                       // wait for key release + debounce
                    if (rs2 == 4'b1111) begin
                        if (cnt == DEB) begin cnt <= 0; col <= col + 1'b1; st <= S_SETTLE; end
                        else cnt <= cnt + 1'b1;
                    end else cnt <= 0;
                end
            endcase
        end
    end
endmodule
