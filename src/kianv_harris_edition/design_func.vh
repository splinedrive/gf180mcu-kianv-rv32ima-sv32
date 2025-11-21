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

function automatic [5:0] clz32;
  input [31:0] x;
  reg [31:0] y;
  reg [ 5:0] n;
  begin
    if (x == 32'b0) clz32 = 6'd32;
    else begin
      y = x;
      n = 6'd0;
      if (y[31:16] == 0) begin
        n = n + 16;
        y = y << 16;
      end
      if (y[31:24] == 0) begin
        n = n + 8;
        y = y << 8;
      end
      if (y[31:28] == 0) begin
        n = n + 4;
        y = y << 4;
      end
      if (y[31:30] == 0) begin
        n = n + 2;
        y = y << 2;
      end
      if (y[31] == 0) begin
        n = n + 1;
      end
      clz32 = n;
    end
  end
endfunction

function automatic [5:0] ctz32;
  input [31:0] x;
  reg [31:0] y;
  reg [ 5:0] n;
  begin
    if (x == 32'b0) ctz32 = 6'd32;
    else begin
      y = x;
      n = 6'd0;
      if (y[15:0] == 0) begin
        n = n + 16;
        y = y >> 16;
      end
      if (y[7:0] == 0) begin
        n = n + 8;
        y = y >> 8;
      end
      if (y[3:0] == 0) begin
        n = n + 4;
        y = y >> 4;
      end
      if (y[1:0] == 0) begin
        n = n + 2;
        y = y >> 2;
      end
      if (y[0] == 0) begin
        n = n + 1;
      end
      ctz32 = n;
    end
  end
endfunction
