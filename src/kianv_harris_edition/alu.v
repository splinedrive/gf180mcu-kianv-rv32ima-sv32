// SPDX-License-Identifier: Apache-2.0
/*
 * KianV RISC-V Linux/XV6 SoC
 * RISC-V SoC/ASIC Design
 *
 * Copyright (c) 2025 Hirosh Dabui <hirosh@dabui.de>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

`default_nettype none
`include "riscv_defines.vh"
module alu (
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [`ALU_CTRL_WIDTH -1:0] alucontrol,
    output reg [31:0] result,
    output wire zero
);

  wire signed [31:0] signed_a = $signed(a);
  wire signed [31:0] signed_b = $signed(b);

  always @* begin
    case (alucontrol)
      `ALU_CTRL_AUIPC, `ALU_CTRL_ADD_ADDI: result = a + b;
      `ALU_CTRL_SUB:                       result = a - b;
      `ALU_CTRL_XOR_XORI:                  result = a ^ b;
      `ALU_CTRL_OR_ORI:                    result = a | b;
      `ALU_CTRL_AND_ANDI:                  result = a & b;
      `ALU_CTRL_SLL_SLLI:                  result = a << b[4:0];
      `ALU_CTRL_SRL_SRLI:                  result = a >> b[4:0];
      `ALU_CTRL_SRA_SRAI:                  result = signed_a >>> b[4:0];
      `ALU_CTRL_SLT_SLTI:                  result = {31'b0, signed_a < signed_b};
      `ALU_CTRL_SLTU_SLTIU:                result = {31'b0, a < b};
      `ALU_CTRL_MIN:                       result = (signed_a < signed_b) ? a : b;
      `ALU_CTRL_MAX:                       result = (signed_a >= signed_b) ? a : b;
      `ALU_CTRL_MINU:                      result = (a < b) ? a : b;
      `ALU_CTRL_MAXU:                      result = (a >= b) ? a : b;
      `ALU_CTRL_LUI:                       result = b;
      `ALU_CTRL_BEQ:                       result = {31'b0, a == b};
      `ALU_CTRL_BNE:                       result = {31'b0, a != b};
      `ALU_CTRL_BGE:                       result = {31'b0, signed_a >= signed_b};
      `ALU_CTRL_BGEU:                      result = {31'b0, a >= b};
      `ALU_CTRL_BLT:                       result = {31'b0, signed_a < signed_b};
      `ALU_CTRL_BLTU:                      result = {31'b0, a < b};
      default:                             result = 32'b0;
    endcase
  end

  assign zero = !result[0];
endmodule
