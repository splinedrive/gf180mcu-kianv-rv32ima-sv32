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
module load_decoder (
    input wire [2:0] funct3,
    input wire amo_data_load,
    output reg [`LOAD_OP_WIDTH -1:0] LOADop,
    input wire [1:0] addr_align_bits,
    output reg is_load_unaligned
);
  wire is_lb = funct3 == 3'b000;
  wire is_lh = funct3 == 3'b001;
  wire is_lw = funct3 == 3'b010;
  wire is_lbu = funct3 == 3'b100;
  wire is_lhu = funct3 == 3'b101;

  always @(*) begin
    is_load_unaligned = 1'b0;
    if (!amo_data_load) begin
      case (1'b1)
        is_lb:  LOADop = `LOAD_OP_LB;
        is_lbu: LOADop = `LOAD_OP_LBU;
        is_lhu: LOADop = `LOAD_OP_LHU;

        is_lh: begin
          LOADop = `LOAD_OP_LH;
          is_load_unaligned = addr_align_bits[0];
        end
        is_lw: begin
          LOADop = `LOAD_OP_LW;
          is_load_unaligned = |addr_align_bits;
        end
        default: LOADop = `LOAD_OP_LB;

      endcase
    end else begin
      LOADop = `LOAD_OP_LW;
      is_load_unaligned = |addr_align_bits;
    end
  end

endmodule
