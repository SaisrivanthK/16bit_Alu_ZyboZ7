`timescale 1ns / 1ps
// 16-bit ALU
// ALU_Sel: 0000 ADD, 0001 SUB, 0010 MUL, 0011 DIV (unsigned)
//          0100 AND, 0101 OR, 0110 XOR, 0111 NOT A
//          1000 SADD, 1001 SSUB, 1010 SMUL, 1011 SDIV (signed)
//          1100 SHL, 1101 SHR, 1110 ROL, 1111 ROR (amount = B[3:0])
module alu_16bit (
    input  wire [15:0] A,
    input  wire [15:0] B,
    input  wire [3:0]  ALU_Sel,

    output reg [15:0] ALU_Out,
    output reg        Zero,
    output reg        Carry,
    output reg        OverFlow,
    output reg        Negative
);

    reg [16:0] temp;
    reg [31:0] unsigned_product;
    reg signed [31:0] signed_product;
    reg signed [16:0] signed_temp;
    reg [3:0] shamt;

    always @(*) begin
        // Default values
        ALU_Out = 16'b0;
        Zero = 1'b0;
        Carry = 1'b0;
        OverFlow = 1'b0;
        Negative = 1'b0;

        temp = 17'b0;
        unsigned_product = 32'b0;
        signed_product = 32'sd0;
        signed_temp = 17'sd0;

        shamt = B[3:0];

        case (ALU_Sel)

            4'b0000: begin // UNSIGNED ADD
                temp = {1'b0, A} + {1'b0, B};
                ALU_Out = temp[15:0];
                Carry = temp[16];
                OverFlow = 1'b0;
                Negative = 1'b0;
            end

            4'b0001: begin // UNSIGNED SUB
                ALU_Out = A - B;
                Carry = (A < B);
                OverFlow = 1'b0;
                Negative = 1'b0;
            end

            4'b0010: begin // UNSIGNED MUL
                unsigned_product = A * B;
                ALU_Out = unsigned_product[15:0];
                OverFlow = |unsigned_product[31:16];
                Carry = 1'b0;
                Negative = 1'b0;
            end

            4'b0011: begin // UNSIGNED DIV
                if (B == 16'b0) begin
                    ALU_Out = 16'hFFFF;
                    OverFlow = 1'b1;
                end else begin
                    ALU_Out = A / B;
                    OverFlow = 1'b0;
                end
                Carry = 1'b0;
                Negative = 1'b0;
            end

            4'b0100: begin // AND
                ALU_Out = A & B;
                Carry = 1'b0; OverFlow = 1'b0; Negative = 1'b0;
            end

            4'b0101: begin // OR
                ALU_Out = A | B;
                Carry = 1'b0; OverFlow = 1'b0; Negative = 1'b0;
            end

            4'b0110: begin // XOR
                ALU_Out = A ^ B;
                Carry = 1'b0; OverFlow = 1'b0; Negative = 1'b0;
            end

            4'b0111: begin // NOT A
                ALU_Out = ~A;
                Carry = 1'b0; OverFlow = 1'b0; Negative = 1'b0;
            end

            4'b1000: begin // SIGNED ADD
                signed_temp = $signed({A[15], A}) + $signed({B[15], B});
                ALU_Out = signed_temp[15:0];
                Carry = 1'b0;
                OverFlow = (A[15] == B[15]) && (ALU_Out[15] != A[15]);
                Negative = ALU_Out[15];
            end

            4'b1001: begin // SIGNED SUB
                signed_temp = $signed({A[15], A}) - $signed({B[15], B});
                ALU_Out = signed_temp[15:0];
                Carry = 1'b0;
                OverFlow = (A[15] != B[15]) && (ALU_Out[15] != A[15]);
                Negative = ALU_Out[15];
            end

            4'b1010: begin // SIGNED MUL
                signed_product = $signed(A) * $signed(B);
                ALU_Out = signed_product[15:0];
                Carry = 1'b0;
                OverFlow = (signed_product > 32'sd32767) ||
                           (signed_product < -32'sd32768);
                Negative = ALU_Out[15];
            end

            4'b1011: begin // SIGNED DIV
                if (B == 16'b0) begin
                    ALU_Out = 16'hFFFF;
                    OverFlow = 1'b1;
                end
                else if ((A == 16'h8000) && (B == 16'hFFFF)) begin
                    ALU_Out = 16'h8000;
                    OverFlow = 1'b1;
                end
                else begin
                    ALU_Out = $signed(A) / $signed(B);
                    OverFlow = 1'b0;
                end
                Carry = 1'b0;
                Negative = ALU_Out[15];
            end

            4'b1100: begin // LOGICAL SHIFT LEFT
                ALU_Out = A << shamt;
                if (shamt == 0) Carry = 1'b0;
                else            Carry = A[16 - shamt];
                OverFlow = 1'b0;
                Negative = 1'b0;
            end

            4'b1101: begin // LOGICAL SHIFT RIGHT
                ALU_Out = $unsigned(A) >> shamt;
                if (shamt == 0) Carry = 1'b0;
                else            Carry = A[shamt - 1];
                OverFlow = 1'b0;
                Negative = 1'b0;
            end

            4'b1110: begin // ROTATE LEFT
                if (shamt == 0) ALU_Out = A;
                else            ALU_Out = (A << shamt) | (A >> (16 - shamt));
                Carry = 1'b0; OverFlow = 1'b0; Negative = 1'b0;
            end

            4'b1111: begin // ROTATE RIGHT
                if (shamt == 0) ALU_Out = A;
                else            ALU_Out = (A >> shamt) | (A << (16 - shamt));
                Carry = 1'b0; OverFlow = 1'b0; Negative = 1'b0;
            end

            default: begin
                ALU_Out = 16'b0;
                Carry = 1'b0; OverFlow = 1'b0; Negative = 1'b0;
            end
        endcase

        Zero = (ALU_Out == 16'b0);
    end
endmodule
