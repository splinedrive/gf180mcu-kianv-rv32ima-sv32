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
module clint (
    input  wire        clk,
    input  wire        resetn,
    input  wire        valid,
    input  wire [23:0] addr,
    input  wire [ 3:0] wmask,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output wire        is_valid,
    output reg         ready,
    output wire        IRQ3,
    output wire        IRQ7,
    input  wire [63:0] timer_counter
);

  wire is_msip = (addr == 24'h00_0000);
  wire is_mtimecmpl = (addr == 24'h00_4000);
  wire is_mtimecmph = (addr == 24'h00_4004);
  wire is_mtimel = (addr == 24'h00_bff8);
  wire is_mtimeh = (addr == 24'h00_bffc);

  assign is_valid = !ready && valid &&
                    (is_msip | is_mtimecmpl | is_mtimecmph | is_mtimel | is_mtimeh);

  always @(posedge clk) begin
    if (!resetn) ready <= 1'b0;
    else ready <= is_valid;
  end

  wire [63:0] mtime = timer_counter;

  reg  [63:0] mtimecmp;
  reg         msip;

  always @(posedge clk) begin
    if (!resetn) begin

      mtimecmp <= 64'hFFFF_FFFF_FFFF_FFFF;
      msip     <= 1'b0;
    end else begin
      if (is_mtimecmpl && is_valid) begin
        if (wmask[0]) mtimecmp[7:0] <= wdata[7:0];
        if (wmask[1]) mtimecmp[15:8] <= wdata[15:8];
        if (wmask[2]) mtimecmp[23:16] <= wdata[23:16];
        if (wmask[3]) mtimecmp[31:24] <= wdata[31:24];
      end
      if (is_mtimecmph && is_valid) begin
        if (wmask[0]) mtimecmp[39:32] <= wdata[7:0];
        if (wmask[1]) mtimecmp[47:40] <= wdata[15:8];
        if (wmask[2]) mtimecmp[55:48] <= wdata[23:16];
        if (wmask[3]) mtimecmp[63:56] <= wdata[31:24];
      end
      if (is_msip && is_valid) begin
        if (wmask[0]) msip <= wdata[0];
      end
    end
  end

  always @* begin
    case (1'b1)
      is_mtimecmpl: rdata = mtimecmp[31:0];
      is_mtimecmph: rdata = mtimecmp[63:32];
      is_mtimel:    rdata = mtime[31:0];
      is_mtimeh:    rdata = mtime[63:32];
      is_msip:      rdata = {31'b0, msip};
      default:      rdata = 32'h0;
    endcase
  end

  assign IRQ3 = msip;
  assign IRQ7 = (mtime >= mtimecmp);

endmodule
`default_nettype wire
