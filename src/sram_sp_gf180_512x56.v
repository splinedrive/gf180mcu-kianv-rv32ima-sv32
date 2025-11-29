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

module sram_sp_gf180_512x56 (
    input  wire        clk,
    input  wire        resetn,
    input  wire        we,
`ifdef USE_POWER_PINS
    inout              VDD,
    inout              VSS,
`endif
    input  wire [ 8:0] addr,
    input  wire [55:0] din,
    output wire [55:0] dout
);

  wire [8:0] row = addr;

  wire [7:0] q_byte[0:6];

  wire [7:0] din0 = din[7:0];
  wire [7:0] din1 = din[15:8];
  wire [7:0] din2 = din[23:16];
  wire [7:0] din3 = din[31:24];
  wire [7:0] din4 = din[39:32];
  wire [7:0] din5 = din[47:40];
  wire [7:0] din6 = din[55:48];

  wire we_this = we;

  wire cen = resetn ? 1'b0 : 1'b1;

  gf180mcu_fd_ip_sram__sram512x8m8wm1_wrapper u_tile_0 (
`ifdef USE_POWER_PINS
      .VDD (VDD),
      .VSS (VSS),
`endif
      .CLK (clk),
      .CEN (cen),
      .GWEN(~we_this),
      .WEN (we_this ? 8'h00 : 8'hFF),
      .A   (row),
      .D   (din0),
      .Q   (q_byte[0])
  );

  gf180mcu_fd_ip_sram__sram512x8m8wm1_wrapper u_tile_1 (
`ifdef USE_POWER_PINS
      .VDD (VDD),
      .VSS (VSS),
`endif
      .CLK (clk),
      .CEN (cen),
      .GWEN(~we_this),
      .WEN (we_this ? 8'h00 : 8'hFF),
      .A   (row),
      .D   (din1),
      .Q   (q_byte[1])
  );

  gf180mcu_fd_ip_sram__sram512x8m8wm1_wrapper u_tile_2 (
`ifdef USE_POWER_PINS
      .VDD (VDD),
      .VSS (VSS),
`endif
      .CLK (clk),
      .CEN (cen),
      .GWEN(~we_this),
      .WEN (we_this ? 8'h00 : 8'hFF),
      .A   (row),
      .D   (din2),
      .Q   (q_byte[2])
  );

  gf180mcu_fd_ip_sram__sram512x8m8wm1_wrapper u_tile_3 (
`ifdef USE_POWER_PINS
      .VDD (VDD),
      .VSS (VSS),
`endif
      .CLK (clk),
      .CEN (cen),
      .GWEN(~we_this),
      .WEN (we_this ? 8'h00 : 8'hFF),
      .A   (row),
      .D   (din3),
      .Q   (q_byte[3])
  );

  gf180mcu_fd_ip_sram__sram512x8m8wm1_wrapper u_tile_4 (
`ifdef USE_POWER_PINS
      .VDD (VDD),
      .VSS (VSS),
`endif
      .CLK (clk),
      .CEN (cen),
      .GWEN(~we_this),
      .WEN (we_this ? 8'h00 : 8'hFF),
      .A   (row),
      .D   (din4),
      .Q   (q_byte[4])
  );

  gf180mcu_fd_ip_sram__sram512x8m8wm1_wrapper u_tile_5 (
`ifdef USE_POWER_PINS
      .VDD (VDD),
      .VSS (VSS),
`endif
      .CLK (clk),
      .CEN (cen),
      .GWEN(~we_this),
      .WEN (we_this ? 8'h00 : 8'hFF),
      .A   (row),
      .D   (din5),
      .Q   (q_byte[5])
  );

  gf180mcu_fd_ip_sram__sram512x8m8wm1_wrapper u_tile_6 (
`ifdef USE_POWER_PINS
      .VDD (VDD),
      .VSS (VSS),
`endif
      .CLK (clk),
      .CEN (cen),
      .GWEN(~we_this),
      .WEN (we_this ? 8'h00 : 8'hFF),
      .A   (row),
      .D   (din6),
      .Q   (q_byte[6])
  );

  assign dout = {q_byte[6], q_byte[5], q_byte[4], q_byte[3], q_byte[2], q_byte[1], q_byte[0]};

endmodule

`default_nettype wire
