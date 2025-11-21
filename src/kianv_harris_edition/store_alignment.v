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

module store_alignment (
    input  wire [                 1:0] addr,
    input  wire [`STORE_OP_WIDTH -1:0] STOREop,
    input  wire [                31:0] data,
    output reg  [                31:0] result,
    output reg  [                 3:0] wmask
);

  always @* begin
    wmask  = 0;
    result = 0;

    case (STOREop)
      (`STORE_OP_SB): begin
        result[7:0] = addr[1:0] == 2'b00 ? data[7:0] : 8'hx;
        result[15:8] = addr[1:0] == 2'b01 ? data[7:0] : 8'hx;
        result[23:16] = addr[1:0] == 2'b10 ? data[7:0] : 8'hx;
        result[31:24] = addr[1:0] == 2'b11 ? data[7:0] : 8'hx;
        wmask          = addr[1:0] == 2'b00 ? 4'b 0001 :
                    addr[1:0] == 2'b01 ? 4'b 0010 :
                        addr[1:0] == 2'b10 ? 4'b 0100 : 4'b 1000;
      end
      (`STORE_OP_SH): begin
        result[15:0]  = ~addr[1] ? data[15:0] : 16'hx;
        result[31:16] = addr[1] ? data[15:0] : 16'hx;
        wmask         = addr[1] ? 4'b1100 : 4'b0011;
      end
      (`STORE_OP_SW): begin
        result = data;
        wmask  = 4'b1111;
      end
      default: begin
        result = 'hx;
        wmask  = 4'b0000;
      end
    endcase

  end
endmodule
