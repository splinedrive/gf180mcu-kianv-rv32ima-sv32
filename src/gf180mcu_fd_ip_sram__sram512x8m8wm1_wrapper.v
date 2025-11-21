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

module gf180mcu_fd_ip_sram__sram512x8m8wm1_wrapper (
`ifdef USE_POWER_PINS
    inout        VDD,
    inout        VSS,
`endif
    input        CLK,
    input        CEN,
    input        GWEN,
    input  [7:0] WEN,
    input  [8:0] A,
    input  [7:0] D,
    output [7:0] Q
);

`ifdef GF180

  (* keep *)
  gf180mcu_fd_ip_sram__sram512x8m8wm1 u_prim (
`ifdef USE_POWER_PINS
      .VDD (VDD),
      .VSS (VSS),
`endif
      .CLK (CLK),
      .CEN (CEN),
      .GWEN(GWEN),
      .WEN (WEN),
      .A   (A),
      .D   (D),
      .Q   (Q)
  );

`else

  (* ram_style = "block" *)
  reg [7:0] mem[0:511];
  reg [7:0] q_reg;
  assign Q = q_reg;

  integer i;
  always @(posedge CLK) begin
    if (!CEN) begin

      if (!GWEN) begin

        for (i = 0; i < 8; i = i + 1) if (!WEN[i]) mem[A][i] <= D[i];
      end

      q_reg <= mem[A];
    end else begin

      q_reg <= 8'hXX;
    end
  end

`endif

endmodule

`default_nettype wire

