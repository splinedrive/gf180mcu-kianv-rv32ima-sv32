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
module extend (
    input  wire [31:7] instr,
    input  wire [ 2:0] immsrc,
    output reg  [31:0] immext
);

  always @(*) begin
    case (immsrc)
      `IMMSRC_ITYPE: immext = {{20{instr[31]}}, instr[31:20]};
      `IMMSRC_STYPE: immext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
      `IMMSRC_BTYPE: immext = {{20{instr[31]}}, instr[7:7], instr[30:25], instr[11:8], 1'b0};
      `IMMSRC_JTYPE: immext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
      `IMMSRC_UTYPE: immext = {instr[31:12], 12'b0};
      default:       immext = 32'b0;
    endcase
  end
endmodule
