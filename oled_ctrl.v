`timescale 1ns/1ps
// ============================================================================
// oled_ctrl : Digilent PmodOLED (SSD1306, 128x32) text-mode controller
//   text[511:0] = 4 lines x 16 chars, ASCII.
//   Line l occupies text[128*l +: 128], char 0 is the MSB (string-literal order)
//   Continuously refreshes the whole screen after init.
// ============================================================================

// ---------------------------------------------------------------------------
// SPI byte transmitter, mode 0, MSB first
// ---------------------------------------------------------------------------
module spi_tx #(parameter DIV = 16) (      // SCLK = clk / (2*DIV)
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [7:0] data,
    output reg        busy,
    output reg        cs_n,
    output reg        sclk,
    output reg        mosi
);
    localparam IDLE = 2'd0, SHIFT = 2'd1, GAP = 2'd2;
    reg [1:0] st;
    reg [7:0] sh;
    reg [2:0] bitcnt;
    reg [7:0] cnt;

    always @(posedge clk) begin
        if (rst) begin
            busy <= 1'b0; cs_n <= 1'b1; sclk <= 1'b0; mosi <= 1'b0;
            st <= IDLE; cnt <= 8'd0; bitcnt <= 3'd0; sh <= 8'd0;
        end else begin
            case (st)
                IDLE: if (start) begin
                    busy <= 1'b1; cs_n <= 1'b0; sh <= data; mosi <= data[7];
                    bitcnt <= 3'd0; cnt <= 8'd0; sclk <= 1'b0; st <= SHIFT;
                end
                SHIFT: begin
                    if (cnt == DIV-1) begin
                        cnt <= 8'd0;
                        if (!sclk) sclk <= 1'b1;            // slave samples here
                        else begin
                            sclk <= 1'b0;
                            if (bitcnt == 3'd7) begin
                                cs_n <= 1'b1; st <= GAP;
                            end else begin
                                bitcnt <= bitcnt + 1'b1;
                                sh     <= {sh[6:0], 1'b0};
                                mosi   <= sh[6];
                            end
                        end
                    end else cnt <= cnt + 1'b1;
                end
                GAP: begin                                   // CS-high gap
                    if (cnt == DIV-1) begin
                        cnt <= 8'd0; busy <= 1'b0; st <= IDLE;
                    end else cnt <= cnt + 1'b1;
                end
                default: st <= IDLE;
            endcase
        end
    end
endmodule


// ---------------------------------------------------------------------------
// OLED controller
// ---------------------------------------------------------------------------
`define SEND(b) spi_data <= (b); oled_dc <= 1'b0; spi_start <= 1'b1; pc <= pc + 1'b1;

module oled_ctrl #(parameter SPI_DIV = 16) (
    input  wire         clk,          // 125 MHz
    input  wire         rst,
    input  wire [511:0] text,
    output wire         oled_cs,
    output wire         oled_sdin,
    output wire         oled_sclk,
    output reg          oled_dc,
    output reg          oled_res,
    output reg          oled_vbatc,   // active low
    output reg          oled_vddc,    // active low
    output reg          ready
);
    localparam MS = 125_000;          // clocks per millisecond @125 MHz

    // ---- 5x7 font (columns left->right, bit0 = top pixel) -----------------
    function [39:0] glyph(input [7:0] c);
        case (c)
            " ": glyph = 40'h0000000000;
            "+": glyph = 40'h08083E0808;
            "-": glyph = 40'h0808080808;
            ".": glyph = 40'h0060600000;
            "/": glyph = 40'h2010080402;
            "0": glyph = 40'h3E5149453E;
            "1": glyph = 40'h00427F4000;
            "2": glyph = 40'h4261514946;
            "3": glyph = 40'h2141454B31;
            "4": glyph = 40'h1814127F10;
            "5": glyph = 40'h2745454539;
            "6": glyph = 40'h3C4A494930;
            "7": glyph = 40'h0171090503;
            "8": glyph = 40'h3649494936;
            "9": glyph = 40'h064949291E;
            ":": glyph = 40'h0036360000;
            "<": glyph = 40'h0814224100;
            "=": glyph = 40'h1414141414;
            ">": glyph = 40'h0041221408;
            "*": glyph = 40'h14083E0814;
            "_": glyph = 40'h4040404040;
            "A": glyph = 40'h7E1111117E;
            "B": glyph = 40'h7F49494936;
            "C": glyph = 40'h3E41414122;
            "D": glyph = 40'h7F4141413E;
            "E": glyph = 40'h7F49494941;
            "F": glyph = 40'h7F09090901;
            "G": glyph = 40'h3E4149497A;
            "H": glyph = 40'h7F0808087F;
            "I": glyph = 40'h00417F4100;
            "J": glyph = 40'h2040413F01;
            "K": glyph = 40'h7F08142241;
            "L": glyph = 40'h7F40404040;
            "M": glyph = 40'h7F020C027F;
            "N": glyph = 40'h7F0408107F;
            "O": glyph = 40'h3E4141413E;
            "P": glyph = 40'h7F09090906;
            "Q": glyph = 40'h3E4151215E;
            "R": glyph = 40'h7F09192946;
            "S": glyph = 40'h4649494931;
            "T": glyph = 40'h01017F0101;
            "U": glyph = 40'h3F4040403F;
            "V": glyph = 40'h1F2040201F;
            "W": glyph = 40'h3F4038403F;
            "X": glyph = 40'h6314081463;
            "Y": glyph = 40'h0708700807;
            "Z": glyph = 40'h6151494543;
            default: glyph = 40'h0000000000;
        endcase
    endfunction

    // 8 columns per character cell: col0 blank, col1..5 glyph, col6..7 blank
    function [7:0] gcol(input [39:0] g, input [2:0] ci);
        case (ci)
            3'd1: gcol = g[39:32];
            3'd2: gcol = g[31:24];
            3'd3: gcol = g[23:16];
            3'd4: gcol = g[15:8];
            3'd5: gcol = g[7:0];
            default: gcol = 8'h00;
        endcase
    endfunction

    // ---- SPI engine --------------------------------------------------------
    reg        spi_start;
    reg  [7:0] spi_data;
    wire       spi_busy;

    spi_tx #(.DIV(SPI_DIV)) u_spi (
        .clk(clk), .rst(rst), .start(spi_start), .data(spi_data),
        .busy(spi_busy), .cs_n(oled_cs), .sclk(oled_sclk), .mosi(oled_sdin)
    );

    // ---- sequencer ---------------------------------------------------------
    reg [4:0]  pc;
    reg [23:0] dly;
    reg [8:0]  n;          // byte index within a frame (0..511)
    reg [7:0]  ch;

    wire [1:0] page = n[8:7];
    wire [3:0] colc = n[6:3];
    wire [2:0] ci   = n[2:0];
    wire [8:0] tbase = {page, 7'd0} + {(4'd15 - colc), 3'd0};

    always @(posedge clk) begin
        spi_start <= 1'b0;
        if (rst) begin
            pc <= 5'd0; dly <= 24'd0; n <= 9'd0; ch <= 8'h20; ready <= 1'b0;
            oled_dc <= 1'b0; oled_res <= 1'b1; oled_vbatc <= 1'b1; oled_vddc <= 1'b1;
            spi_data <= 8'd0;
        end else if (dly != 24'd0) begin
            dly <= dly - 1'b1;
        end else if (spi_busy || spi_start) begin
            // wait for byte to finish
        end else begin
            case (pc)
                5'd0 : begin oled_vddc <= 1'b0; dly <= 5*MS; pc <= 5'd1; end   // VDD on
                5'd1 : begin `SEND(8'hAE) end                                  // display off
                5'd2 : begin oled_res <= 1'b0; dly <= 2*MS; pc <= 5'd3; end    // reset low
                5'd3 : begin oled_res <= 1'b1; dly <= 2*MS; pc <= 5'd4; end    // reset high
                5'd4 : begin `SEND(8'h8D) end                                  // charge pump
                5'd5 : begin `SEND(8'h14) end
                5'd6 : begin `SEND(8'hD9) end                                  // pre-charge
                5'd7 : begin `SEND(8'hF1) end
                5'd8 : begin oled_vbatc <= 1'b0; dly <= 100*MS; pc <= 5'd9; end // VBAT on
                5'd9 : begin `SEND(8'h20) end                                  // horizontal addressing
                5'd10: begin `SEND(8'h00) end
                5'd11: begin `SEND(8'hA1) end                                  // segment remap
                5'd12: begin `SEND(8'hC8) end                                  // COM scan direction
                5'd13: begin `SEND(8'hDA) end                                  // COM pins
                5'd14: begin `SEND(8'h20) end
                5'd15: begin `SEND(8'h81) end                                  // contrast
                5'd16: begin `SEND(8'h8F) end
                5'd17: begin `SEND(8'hA4) end                                  // follow RAM
                5'd18: begin `SEND(8'hA6) end                                  // normal (not inverted)
                5'd19: begin `SEND(8'hAF) end                                  // display ON
                5'd20: begin ready <= 1'b1; dly <= 1*MS; pc <= 5'd21; end
                // ---- start of a frame: set window ----
                5'd21: begin `SEND(8'h21) end                                  // column range
                5'd22: begin `SEND(8'h00) end
                5'd23: begin `SEND(8'h7F) end
                5'd24: begin `SEND(8'h22) end                                  // page range
                5'd25: begin `SEND(8'h00) end
                5'd26: begin `SEND(8'h03) end
                // ---- 512 data bytes ----
                5'd27: begin ch <= text[tbase +: 8]; pc <= 5'd28; end
                5'd28: begin
                    spi_data  <= gcol(glyph(ch), ci);
                    oled_dc   <= 1'b1;
                    spi_start <= 1'b1;
                    n         <= n + 1'b1;
                    pc        <= (n == 9'd511) ? 5'd21 : 5'd27;
                end
                default: pc <= 5'd21;
            endcase
        end
    end
endmodule
