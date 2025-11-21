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

module store_decoder (
    input wire [2:0] funct3,
    input wire amo_operation_store,
    output reg [`STORE_OP_WIDTH-1:0] STOREop,
    input wire [1:0] addr_align_bits,
    output reg is_store_unaligned
);

  wire is_sb = funct3[1:0] == 2'b00;
  wire is_sh = funct3[1:0] == 2'b01;
  wire is_sw = funct3[1:0] == 2'b10;

  always @(*) begin
    is_store_unaligned = 1'b0;
    if (!amo_operation_store) begin
      case (1'b1)
        is_sb:   STOREop = `STORE_OP_SB;
        is_sh: begin
          STOREop = `STORE_OP_SH;
          is_store_unaligned = addr_align_bits[0];
        end
        is_sw: begin
          STOREop = `STORE_OP_SW;
          is_store_unaligned = |addr_align_bits;
        end
        default: STOREop = `STORE_OP_SB;
      endcase
    end else begin
      STOREop = `STORE_OP_SW;
      is_store_unaligned = |addr_align_bits;
    end
  end
endmodule

