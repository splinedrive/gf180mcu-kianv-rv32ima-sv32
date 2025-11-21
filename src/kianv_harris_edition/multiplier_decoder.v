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
module multiplier_decoder (
    input  wire [               2:0] funct3,
    output reg  [`MUL_OP_WIDTH -1:0] MULop,
    input  wire                      mul_ext_valid,
    output wire                      mul_valid
);

  wire is_mul = funct3 == 3'b000;
  wire is_mulh = funct3 == 3'b001;
  wire is_mulsu = funct3 == 3'b010;
  wire is_mulu = funct3 == 3'b011;
  reg  valid;

  assign mul_valid = valid & mul_ext_valid;
  always @(*) begin
    valid = 1'b1;
    case (1'b1)
      is_mul:   MULop = `MUL_OP_MUL;
      is_mulh:  MULop = `MUL_OP_MULH;
      is_mulsu: MULop = `MUL_OP_MULSU;
      is_mulu:  MULop = `MUL_OP_MULU;
      default: begin

        MULop = 'hxx;

        valid = 1'b0;
      end
    endcase
  end

endmodule
