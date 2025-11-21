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
module load_alignment (
    input  wire [                 1:0] addr,
    input  wire [`LOAD_OP_WIDTH  -1:0] LOADop,
    input  wire [                31:0] data,
    output reg  [                31:0] result
);

  wire is_lb = `LOAD_OP_LB == LOADop;
  wire is_lbu = `LOAD_OP_LBU == LOADop;

  wire is_lh = `LOAD_OP_LH == LOADop;
  wire is_lhu = `LOAD_OP_LHU == LOADop;

  wire is_lw = `LOAD_OP_LW == LOADop;

  always @* begin
    result = 0;

    if (is_lb | is_lbu) begin
      result[7:0] =
                  addr[1:0] == 2'b00 ? data[7  :0] :
                  addr[1:0] == 2'b01 ? data[15 :8] :
                  addr[1:0] == 2'b10 ? data[23:16] :
                  addr[1:0] == 2'b11 ? data[31:24] : 8'hx;
      result = {is_lbu ? 24'b0 : {24{result[7]}}, result[7:0]};
    end

    if (is_lh | is_lhu) begin
      result[15:0] = ~addr[1] ? data[15 : 0] : addr[1] ? data[31 : 16] : 16'hx;
      result = {is_lhu ? 16'b0 : {16{result[15]}}, result[15:0]};
    end

    if (is_lw) begin
      result = data;
    end
  end

endmodule
