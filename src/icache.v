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

module icache #(
    parameter integer NUM_SETS   = 512,
    parameter integer LINE_BYTES = 4,
    parameter integer ADDR_WIDTH = 32,

    parameter integer HASH_ON     = 0,
    parameter integer HASH_MODE   = 2,
    parameter integer HASH_XOR_LO = 0,
    parameter integer HASH_XOR_HI = 1
) (
    input wire clk,
    input wire resetn,
`ifdef USE_POWER_PINS
    inout      VDD,
    inout      VSS,
`endif
    input wire flush,

    input  wire [ADDR_WIDTH-1:0] cpu_addr_i,
    input  wire                  cpu_valid_i,
    output reg  [          31:0] cpu_dout_o,
    output reg                   cpu_ready_o,

    output reg  [ADDR_WIDTH-1:0] ram_addr_o,
    input  wire [          31:0] ram_rdata_i,
    output reg                   ram_valid_o,
    input  wire                  ram_ready_i
);

  localparam integer OFFSET_BITS = $clog2(LINE_BYTES);
  localparam integer IDX_BITS = $clog2(NUM_SETS);
  localparam integer TAG_BITS = ADDR_WIDTH - OFFSET_BITS - IDX_BITS;

  wire [IDX_BITS-1:0] idx_raw = cpu_addr_i[OFFSET_BITS+IDX_BITS-1 : OFFSET_BITS];
  wire [TAG_BITS-1:0] tag = cpu_addr_i[ADDR_WIDTH-1 : OFFSET_BITS+IDX_BITS];

  function [IDX_BITS-1:0] fold_tag_to_idx;
    input [TAG_BITS-1:0] t;
    integer i;
    reg [IDX_BITS-1:0] f;
    begin
      f = {IDX_BITS{1'b0}};
      for (i = 0; i < TAG_BITS; i = i + 1) f[i%IDX_BITS] = f[i%IDX_BITS] ^ t[i];
      fold_tag_to_idx = f;
    end
  endfunction

  function [IDX_BITS-1:0] rot1;
    input [IDX_BITS-1:0] x;
    begin
      rot1 = {x[0], x[IDX_BITS-1:1]};
    end
  endfunction

  localparam integer HASH_WIDTH = (HASH_XOR_HI >= HASH_XOR_LO) ? (HASH_XOR_HI - HASH_XOR_LO + 1) : 0;
  wire [IDX_BITS-1:0] hash_mask =
      (HASH_ON && (HASH_MODE==1) && (HASH_WIDTH > 0)) ?
          { { (IDX_BITS-HASH_WIDTH){1'b0} }, tag[HASH_XOR_HI:HASH_XOR_LO] } :
          { IDX_BITS{1'b0} };

  wire [IDX_BITS-1:0] tag_fold = fold_tag_to_idx(tag);
  wire [IDX_BITS-1:0] idx_hash_strong = idx_raw ^ tag_fold ^ rot1(tag_fold);
  wire [IDX_BITS-1:0] idx_hash_xor = idx_raw ^ hash_mask;

  wire [IDX_BITS-1:0] idx =
        (HASH_ON==0)   ? idx_raw        :
        (HASH_MODE==2) ? idx_hash_strong:
        (HASH_MODE==1) ? idx_hash_xor   :
                         idx_raw;

  initial begin
    if ((NUM_SETS % 512) != 0)
      $fatal(1, "icache: NUM_SETS (%0d) should be a multiple of 512 for SRAM tiling.", NUM_SETS);
    if ((LINE_BYTES * 8) != 32)
      $fatal(1, "icache: LINE_BYTES*8 (%0d) must equal DATA_WIDTH=32.", LINE_BYTES * 8);
    if (HASH_ON && HASH_MODE == 1) begin
      if (HASH_XOR_HI < HASH_XOR_LO) $fatal(1, "icache: HASH_XOR_HI < HASH_XOR_LO.");
      if (HASH_WIDTH > TAG_BITS) $fatal(1, "icache: XOR slice wider than TAG bits.");
      if (HASH_WIDTH > IDX_BITS) $fatal(1, "icache: XOR slice wider than index width.");
    end
  end

  wire [31:0] cache_rdata;
  wire        cache_hit;
  reg cache_re, cache_we;
  reg [31:0] cache_wdata;

  cache_sram_I$ #(
      .NUM_LINES (NUM_SETS),
      .LINE_BYTES(LINE_BYTES),
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(32)
  ) cache_I (
      .clk   (clk),
      .resetn(resetn),
`ifdef USE_POWER_PINS
      .VDD   (VDD),
      .VSS   (VSS),
`endif
      .flush (flush),
      .idx   (idx),
      .tag   (tag),
      .we    (cache_we),
      .re    (cache_re),
      .wdata (cache_wdata),
      .rdata (cache_rdata),
      .hit   (cache_hit)
  );

  reg [31:0] cache_rdata_q;
  reg        cache_hit_q;
  always @(posedge clk) begin
    if (!resetn) begin
      cache_rdata_q <= 32'b0;
      cache_hit_q   <= 1'b0;
    end else if (flush) begin
      cache_rdata_q <= 32'b0;
      cache_hit_q   <= 1'b0;
    end else begin
      cache_rdata_q <= cache_rdata;
      cache_hit_q   <= cache_hit;
    end
  end

  localparam S_IDLE = 3'd0, S_READ = 3'd1, S_CHECK = 3'd2, S_MREQ = 3'd3, S_REFILL = 3'd4;

  reg [2:0] state, next_state;
  always @(posedge clk) begin
    if (!resetn) state <= S_IDLE;
    else if (flush) state <= S_IDLE;
    else state <= next_state;
  end

  always @* begin
    next_state = state;
    case (state)
      S_IDLE:   if (cpu_valid_i) next_state = S_READ;
      S_READ:   next_state = S_CHECK;
      S_CHECK:  next_state = cache_hit_q ? S_IDLE : S_MREQ;
      S_MREQ:   next_state = ram_ready_i ? S_REFILL : S_MREQ;
      S_REFILL: next_state = S_IDLE;
      default:  next_state = S_IDLE;
    endcase
  end

  always @* begin

    cpu_ready_o = 1'b0;
    cpu_dout_o  = 32'b0;

    ram_valid_o = 1'b0;
    ram_addr_o  = cpu_addr_i;

    cache_re    = 1'b0;
    cache_we    = 1'b0;
    cache_wdata = 32'b0;

    case (state)
      S_IDLE:  if (cpu_valid_i) cache_re = 1'b1;
      S_READ:  cache_re = 1'b1;
      S_CHECK:
      if (cache_hit_q) begin
        cpu_ready_o = 1'b1;
        cpu_dout_o  = cache_rdata_q;
      end
      S_MREQ:  ram_valid_o = 1'b1;
      S_REFILL: begin
        cache_we    = 1'b1;
        cache_wdata = ram_rdata_i;
        cpu_ready_o = 1'b1;
        cpu_dout_o  = ram_rdata_i;
      end
      default: ;
    endcase
  end

endmodule
`default_nettype wire

