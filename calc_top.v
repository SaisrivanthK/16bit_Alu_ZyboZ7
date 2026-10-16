`timescale 1ns/1ps
// ============================================================================
// calc_top : 16-bit ALU calculator (Zybo Z7, 125 MHz)
//   Pmod KYPD  -> hex digit entry (shifts into the selected operand)
//   Pmod OLED  -> shows A, B, Y (decimal + hex), opcode and flags
//   sw[3:0]    -> ALU opcode
//   ext_sw[0]  -> reset (hold high = reset, flip low to run)
//   ext_sw[1]  -> 0 = edit A, 1 = edit B
//   btn[0]     -> clear selected operand
//   btn[1]     -> clear A and B
//   btn[2]     -> backspace (drop last hex digit of selected operand)
//   btn[3]     -> system reset (same as ext_sw[0])
//   Display is signed automatically for the signed opcodes (1000..1011).
//   led[3:0]   -> last key pressed
// ============================================================================

// ---------------------------------------------------------------------------
// Button: 2-FF sync, rising-edge pulse, lockout debounce
// ---------------------------------------------------------------------------
module btn_pulse #(parameter LOCK = 2_000_000) (
    input  wire clk,
    input  wire din,
    output reg  pulse
);
    reg s1 = 1'b0, s2 = 1'b0, s3 = 1'b0;
    reg [21:0] lock = 22'd0;
    initial pulse = 1'b0;
    always @(posedge clk) begin
        s1 <= din; s2 <= s1; s3 <= s2;
        pulse <= 1'b0;
        if (lock != 0) lock <= lock - 1'b1;
        else if (s2 && !s3) begin pulse <= 1'b1; lock <= LOCK; end
    end
endmodule

// ---------------------------------------------------------------------------
// Sequential binary -> BCD (double dabble), free running, ~18 clocks/convert
// ---------------------------------------------------------------------------
module bin2dec (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] val,
    input  wire        is_signed,
    output reg  [19:0] bcd,
    output reg         neg
);
    reg [4:0]  i   = 5'd0;
    reg [15:0] sh  = 16'd0;
    reg [19:0] acc = 20'd0;
    reg        ng  = 1'b0;
    initial begin bcd = 20'd0; neg = 1'b0; end

    function [3:0] add3(input [3:0] n);
        add3 = (n >= 4'd5) ? n + 4'd3 : n;
    endfunction

    wire [19:0] adj = {add3(acc[19:16]), add3(acc[15:12]), add3(acc[11:8]),
                       add3(acc[7:4]),   add3(acc[3:0])};

    always @(posedge clk) begin
        if (rst) begin
            i <= 5'd0; sh <= 16'd0; acc <= 20'd0; ng <= 1'b0;
            bcd <= 20'd0; neg <= 1'b0;
        end else if (i == 5'd0) begin
            ng  <= is_signed & val[15];
            sh  <= (is_signed & val[15]) ? (~val + 1'b1) : val;
            acc <= 20'd0;
            i   <= 5'd1;
        end else if (i <= 5'd16) begin
            acc <= {adj[18:0], sh[15]};
            sh  <= {sh[14:0], 1'b0};
            i   <= i + 1'b1;
        end else begin
            bcd <= acc;
            neg <= ng;
            i   <= 5'd0;
        end
    end
endmodule

// ---------------------------------------------------------------------------
// Top
// ---------------------------------------------------------------------------
module calc_top (
    input  wire       clk,
    input  wire [3:0] sw,
    input  wire [3:0] btn,
    input  wire [3:0] ext_sw,
    output wire [3:0] led,
    output wire [3:0] kypd_col,
    input  wire [3:0] kypd_row,
    output wire       oled_cs,
    output wire       oled_sdin,
    output wire       oled_sclk,
    output wire       oled_dc,
    output wire       oled_res,
    output wire       oled_vbatc,
    output wire       oled_vddc
);
    // ---------------- power-on + button reset ----------------
    reg [3:0] por_cnt = 4'd0;
    always @(posedge clk) if (!(&por_cnt)) por_cnt <= por_cnt + 1'b1;

    reg rb1 = 1'b0, rb2 = 1'b0;
    always @(posedge clk) begin rb1 <= btn[3] | ext_sw[0]; rb2 <= rb1; end
    wire rst = ~(&por_cnt) | rb2;

    // ---------------- input synchronisers ----------------
    reg [3:0] sw_s1 = 4'd0, sw_s2 = 4'd0;
    reg [3:0] ex_s1 = 4'd0, ex_s2 = 4'd0;
    always @(posedge clk) begin
        sw_s1 <= sw;     sw_s2 <= sw_s1;
        ex_s1 <= ext_sw; ex_s2 <= ex_s1;
    end
    wire view_signed = (sw_s2[3:2] == 2'b10);   // SADD/SSUB/SMUL/SDIV
    wire sel_b       = ex_s2[1];

    // ---------------- buttons ----------------
    wire clr_sel, clr_all, bksp;
    btn_pulse u_b0 (.clk(clk), .din(btn[0]), .pulse(clr_sel));
    btn_pulse u_b1 (.clk(clk), .din(btn[1]), .pulse(clr_all));
    btn_pulse u_b2 (.clk(clk), .din(btn[2]), .pulse(bksp));

    // ---------------- keypad ----------------
    wire [3:0] key;
    wire       key_valid;
    keypad_scanner u_kp (
        .clk(clk), .rst(rst),
        .col_n(kypd_col), .row_n(kypd_row),
        .key(key), .key_valid(key_valid)
    );

    reg [3:0] last_key = 4'd0;
    assign led = last_key;

    // ---------------- operand registers ----------------
    reg [15:0] a_reg = 16'd0;
    reg [15:0] b_reg = 16'd0;

    always @(posedge clk) begin
        if (rst || clr_all) begin
            a_reg <= 16'd0; b_reg <= 16'd0;
            if (rst) last_key <= 4'd0;
        end else if (clr_sel) begin
            if (sel_b) b_reg <= 16'd0; else a_reg <= 16'd0;
        end else if (bksp) begin
            if (sel_b) b_reg <= {4'd0, b_reg[15:4]};
            else       a_reg <= {4'd0, a_reg[15:4]};
        end else if (key_valid) begin
            last_key <= key;
            if (sel_b) b_reg <= {b_reg[11:0], key};
            else       a_reg <= {a_reg[11:0], key};
        end
    end

    // ---------------- ALU (combinational) ----------------
    wire [15:0] alu_y;
    wire        alu_z, alu_c, alu_v, alu_n;
    alu_16bit u_alu (
        .A(a_reg), .B(b_reg), .ALU_Sel(sw_s2),
        .ALU_Out(alu_y), .Zero(alu_z), .Carry(alu_c),
        .OverFlow(alu_v), .Negative(alu_n)
    );

    // Result captured once every 256 clocks (matches multicycle constraint)
    reg [7:0]  cap_cnt = 8'd0;
    reg [15:0] y_cap   = 16'd0;
    reg [3:0]  flg_cap = 4'd0;            // {N, V, C, Z}
    always @(posedge clk) begin
        cap_cnt <= cap_cnt + 1'b1;
        if (&cap_cnt) begin
            y_cap   <= alu_y;
            flg_cap <= {alu_n, alu_v, alu_c, alu_z};
        end
    end

    // ---------------- binary -> decimal ----------------
    wire [19:0] bcd_a, bcd_b, bcd_y;
    wire        neg_a, neg_b, neg_y;
    bin2dec u_da (.clk(clk), .rst(rst), .val(a_reg), .is_signed(view_signed), .bcd(bcd_a), .neg(neg_a));
    bin2dec u_db (.clk(clk), .rst(rst), .val(b_reg), .is_signed(view_signed), .bcd(bcd_b), .neg(neg_b));
    bin2dec u_dy (.clk(clk), .rst(rst), .val(y_cap), .is_signed(view_signed), .bcd(bcd_y), .neg(neg_y));

    // ---------------- text formatting ----------------
    function [7:0] dg(input [3:0] n);
        dg = 8'h30 + {4'd0, n};
    endfunction
    function [7:0] hx(input [3:0] n);
        hx = (n < 4'd10) ? (8'h30 + {4'd0, n}) : (8'h37 + {4'd0, n});
    endfunction
    function [7:0] bc(input b);
        bc = b ? "1" : "0";
    endfunction

    // 16 chars: "<c0>A:-12345 HHHH  "
    function [127:0] numline(input [7:0] c0, input [7:0] c1,
                             input [15:0] v, input [19:0] d,
                             input ng, input sg);
        reg [7:0] sc;
        begin
            sc = ng ? "-" : (sg ? "+" : " ");
            numline = {c0, c1, ":", sc,
                       dg(d[19:16]), dg(d[15:12]), dg(d[11:8]), dg(d[7:4]), dg(d[3:0]),
                       " ", hx(v[15:12]), hx(v[11:8]), hx(v[7:4]), hx(v[3:0]), " ", " "};
        end
    endfunction

    function [31:0] opname(input [3:0] s);
        case (s)
            4'b0000: opname = "ADD ";
            4'b0001: opname = "SUB ";
            4'b0010: opname = "MUL ";
            4'b0011: opname = "DIV ";
            4'b0100: opname = "AND ";
            4'b0101: opname = "OR  ";
            4'b0110: opname = "XOR ";
            4'b0111: opname = "NOT ";
            4'b1000: opname = "SADD";
            4'b1001: opname = "SSUB";
            4'b1010: opname = "SMUL";
            4'b1011: opname = "SDIV";
            4'b1100: opname = "SHL ";
            4'b1101: opname = "SHR ";
            4'b1110: opname = "ROL ";
            default: opname = "ROR ";
        endcase
    endfunction

    wire [127:0] line0 = numline(sel_b ? " " : ">", "A", a_reg, bcd_a, neg_a, view_signed);
    wire [127:0] line1 = numline(sel_b ? ">" : " ", "B", b_reg, bcd_b, neg_b, view_signed);
    wire [127:0] line2 = numline(" ",               "Y", y_cap, bcd_y, neg_y, view_signed);
    wire [127:0] line3 = {"O", "P", ":", opname(sw_s2), " ",
                          "Z", bc(flg_cap[0]), "C", bc(flg_cap[1]),
                          "V", bc(flg_cap[2]), "N", bc(flg_cap[3])};

    // line l lives at text[128*l +: 128]
    wire [511:0] text = {line3, line2, line1, line0};

    // ---------------- OLED ----------------
    wire oled_ready;
    oled_ctrl u_oled (
        .clk(clk), .rst(rst), .text(text),
        .oled_cs(oled_cs), .oled_sdin(oled_sdin), .oled_sclk(oled_sclk),
        .oled_dc(oled_dc), .oled_res(oled_res),
        .oled_vbatc(oled_vbatc), .oled_vddc(oled_vddc),
        .ready(oled_ready)
    );
endmodule
