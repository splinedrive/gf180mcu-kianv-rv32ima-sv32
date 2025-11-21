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

module sram_sp #(
    parameter integer DEPTH = 512,
    parameter integer WIDTH = 56
) (
    input  wire                     clk,
    input  wire                     we,
`ifdef USE_POWER_PINS
    inout                           VDD,
    inout                           VSS,
`endif
    input  wire [$clog2(DEPTH)-1:0] addr,
    input  wire [        WIDTH-1:0] din,
    output wire [        WIDTH-1:0] dout
);
  localparam integer ROWS = 512;
  localparam integer ROW_BITS = 9;
  localparam integer ADDR_BITS = $clog2(DEPTH);
  localparam integer BYTES = WIDTH / 8;

  initial begin
    if ((DEPTH % ROWS) != 0) $fatal(1, "sram_sp: DEPTH (%0d) must be a multiple of 512.", DEPTH);
    if ((WIDTH % 8) != 0) $fatal(1, "sram_sp: WIDTH (%0d) must be a multiple of 8.", WIDTH);
  end

  wire [ROW_BITS-1:0] row = addr[ROW_BITS-1:0];

  localparam integer BANKS = DEPTH / ROWS;
  localparam integer BANK_BITS_BUS = (ADDR_BITS > ROW_BITS) ? (ADDR_BITS - ROW_BITS) : 0;
  localparam integer BANK_BITS_EFF = (BANK_BITS_BUS == 0) ? 1 : BANK_BITS_BUS;
  localparam integer BANKS_POW2 = (BANK_BITS_BUS == 0) ? 1 : (1 << BANK_BITS_BUS);
  localparam BANKS_IS_POW2 = (BANKS_POW2 == BANKS);

  wire [BANK_BITS_EFF-1:0] bank_raw;
  generate
    if (BANK_BITS_BUS == 0) begin : g_bank0
      assign bank_raw = {BANK_BITS_EFF{1'b0}};
    end else begin : g_bankN
      assign bank_raw = addr[ADDR_BITS-1 : ROW_BITS];
    end
  endgenerate

  wire [BANK_BITS_EFF-1:0] bank_sel;
  generate
    if (BANKS <= 1) begin : g_bank_single
      assign bank_sel = {BANK_BITS_EFF{1'b0}};
    end else if (BANKS_IS_POW2) begin : g_bank_pow2
      assign bank_sel = bank_raw;
    end else begin : g_bank_wrap
      wire [31:0] bank_u = {{(32 - BANK_BITS_EFF) {1'b0}}, bank_raw};
      localparam [31:0] BANKS_U32 = 32'h0 + BANKS;
      wire        ge = (bank_u >= BANKS_U32);
      wire [31:0] sub_u = bank_u - BANKS_U32;
      assign bank_sel = ge ? sub_u[BANK_BITS_EFF-1:0] : bank_raw;
    end
  endgenerate

  reg [BANK_BITS_EFF-1:0] bank_q;
  always @(posedge clk) bank_q <= bank_sel;

  wire [7:0] q_byte[0:BANKS-1][0:BYTES-1];

  genvar b, j;
  generate
    for (b = 0; b < BANKS; b = b + 1) begin : gen_bank
      localparam [BANK_BITS_EFF-1:0] BIDX = b[BANK_BITS_EFF-1:0];
      for (j = 0; j < BYTES; j = j + 1) begin : gen_lane
        wire [7:0] din8 = din[j*8+:8];
        wire       we_this = we && (bank_sel == BIDX);
        gf180mcu_fd_ip_sram__sram512x8m8wm1_wrapper u_tile (
            .CLK (clk),
            .CEN (1'b0),
            .GWEN(~we_this),
            .WEN (we_this ? 8'h00 : 8'hFF),
            .A   (row),
            .D   (din8),
            .Q   (q_byte[b][j])
`ifdef USE_POWER_PINS,
            .VDD (VDD),
            .VSS (VSS)
`endif
        );
      end
    end
  endgenerate

  wire [WIDTH-1:0] bank_vec[0:BANKS-1];
  generate
    for (b = 0; b < BANKS; b = b + 1) begin : gen_pack
      for (j = 0; j < BYTES; j = j + 1) begin : gen_pack_lane
        assign bank_vec[b][j*8+:8] = q_byte[b][j];
      end
    end
  endgenerate

  generate
    if (BANKS <= 1) begin : g_out_single
      assign dout = bank_vec[0];
    end else begin : g_out_multi
      assign dout = bank_vec[bank_q];
    end
  endgenerate
endmodule
`default_nettype wire
