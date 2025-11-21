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
module divider_decoder (
    input  wire [               2:0] funct3,
    output reg  [`DIV_OP_WIDTH -1:0] DIVop,
    input  wire                      mul_ext_valid,
    output wire                      div_valid
);

  wire is_div = funct3 == 3'b100;
  wire is_divu = funct3 == 3'b101;
  wire is_rem = funct3 == 3'b110;
  wire is_remu = funct3 == 3'b111;
  reg  valid;

  assign div_valid = valid & mul_ext_valid;

  always @(*) begin
    valid = 1'b1;
    case (1'b1)
      is_div:  DIVop = `DIV_OP_DIV;
      is_divu: DIVop = `DIV_OP_DIVU;
      is_rem:  DIVop = `DIV_OP_REM;
      is_remu: DIVop = `DIV_OP_REMU;
      default: begin

        DIVop = 'hxx;

        valid = 1'b0;
      end
    endcase
  end

endmodule
