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

module cache_sram_I$ #(
    parameter integer NUM_LINES  = 512,
    parameter integer LINE_BYTES = 4,
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32
) (
    input wire clk,
    input wire resetn,
`ifdef USE_POWER_PINS
    inout      VDD,
    inout      VSS,
`endif
    input wire flush,

    input wire [$clog2(NUM_LINES)-1:0] idx,
    input wire [ADDR_WIDTH-$clog2(NUM_LINES)-$clog2(LINE_BYTES)-1:0] tag,

    input wire                  we,
    input wire                  re,
    input wire [DATA_WIDTH-1:0] wdata,

    output reg [DATA_WIDTH-1:0] rdata,
    output reg                  hit
);

  localparam integer OFFSET_BITS = $clog2(LINE_BYTES);
  localparam integer IDX_BITS = $clog2(NUM_LINES);
  localparam integer TAG_BITS = ADDR_WIDTH - OFFSET_BITS - IDX_BITS;

  localparam integer SUM_BITS = TAG_BITS + DATA_WIDTH;
  localparam integer PACK_BYTES = (SUM_BITS + 7) / 8;
  localparam integer PACK_BITS = 8 * PACK_BYTES;
  localparam integer PAD_BITS = PACK_BITS - SUM_BITS;

  initial begin
    if ((NUM_LINES % 512) != 0)
      $fatal(1, "cache_sram_I$: NUM_LINES (%0d) must be a multiple of 512.", NUM_LINES);
    if ((LINE_BYTES * 8) != DATA_WIDTH)
      $fatal(
          1,
          "cache_sram_I$: LINE_BYTES*8 (%0d) must equal DATA_WIDTH (%0d).",
          LINE_BYTES * 8,
          DATA_WIDTH
      );
  end

  (* keep *)reg [NUM_LINES-1:0] valid0;
  (* keep *)reg [NUM_LINES-1:0] valid1;

  (* keep *)reg [NUM_LINES-1:0] lru;

  wire [PACK_BITS-1:0] packed_out0, packed_out1;

  wire target_way;
  wire write_sel_way0, write_sel_way1;

  sram_sp_gf180_512x56 u_mem_way0 (
      .clk (clk),
      .we  (write_sel_way0),
`ifdef USE_POWER_PINS
      .VDD (VDD),
      .VSS (VSS),
`endif
      .addr(idx),
      .din ({{PAD_BITS{1'b0}}, tag, wdata}),
      .dout(packed_out0)
  );

  sram_sp_gf180_512x56 u_mem_way1 (
      .clk (clk),
      .we  (write_sel_way1),
`ifdef USE_POWER_PINS
      .VDD (VDD),
      .VSS (VSS),
`endif
      .addr(idx),
      .din ({{PAD_BITS{1'b0}}, tag, wdata}),
      .dout(packed_out1)
  );

  localparam integer DATA_LO = 0;
  localparam integer DATA_HI = DATA_LO + DATA_WIDTH - 1;
  localparam integer TAG_LO = DATA_HI + 1;
  localparam integer TAG_HI = TAG_LO + TAG_BITS - 1;

  wire [DATA_WIDTH-1:0] data0 = packed_out0[DATA_HI:DATA_LO];
  wire [DATA_WIDTH-1:0] data1 = packed_out1[DATA_HI:DATA_LO];
  wire [TAG_BITS-1:0] tag0 = packed_out0[TAG_HI:TAG_LO];
  wire [TAG_BITS-1:0] tag1 = packed_out1[TAG_HI:TAG_LO];

  wire way0_match = valid0[idx] && (tag0 == tag);
  wire way1_match = valid1[idx] && (tag1 == tag);

  wire hit_comb = way0_match | way1_match;
  wire hit_way = way1_match ? 1'b1 : 1'b0;

  wire both_valid = valid0[idx] & valid1[idx];
  wire miss_sel = both_valid ? lru[idx] : (valid0[idx] ? 1'b1 : 1'b0);
  assign target_way = hit_comb ? hit_way : miss_sel;

  assign write_sel_way0 = we && (target_way == 1'b0);
  assign write_sel_way1 = we && (target_way == 1'b1);

  always @* begin
    hit = hit_comb;
    if (way0_match) rdata = data0;
    else if (way1_match) rdata = data1;
    else rdata = {DATA_WIDTH{1'b0}};
  end

  always @(posedge clk) begin
    if (!resetn) begin
      valid0 <= {NUM_LINES{1'b0}};
      valid1 <= {NUM_LINES{1'b0}};
      lru    <= {NUM_LINES{1'b0}};
    end else if (flush) begin
      valid0 <= {NUM_LINES{1'b0}};
      valid1 <= {NUM_LINES{1'b0}};
      lru    <= {NUM_LINES{1'b0}};
    end else begin

      if (write_sel_way0) valid0[idx] <= 1'b1;
      if (write_sel_way1) valid1[idx] <= 1'b1;

      if (hit_comb) begin
        lru[idx] <= ~hit_way;
      end else if (we) begin
        lru[idx] <= ~target_way;
      end
    end
  end

`ifdef CACHE_DBG

`ifndef DBG_PERIOD
  localparam integer DBG_PERIOD_BASE = 100000;
`else
  localparam integer DBG_PERIOD_BASE = `DBG_PERIOD;
`endif
  localparam integer DBG_PERIOD = DBG_PERIOD_BASE * 10;

  localparam integer DBG_BANKS = (NUM_LINES / 512);
  localparam integer TILES_PER_WAY = DBG_BANKS * PACK_BYTES;
  initial begin
    $display("[I$] Geometry: SETS=%0d LINE_BYTES=%0d TAG_BITS=%0d DATA_BITS=%0d", NUM_LINES,
             LINE_BYTES, TAG_BITS, DATA_WIDTH);
    $display("[I$] SRAM tiles: ways=2 banks=%0d bytes/word=%0d tiles/way=%0d total_tiles=%0d",
             DBG_BANKS, PACK_BYTES, TILES_PER_WAY, 2 * TILES_PER_WAY);
    $display("[I$] Debug period: %0d cycles (10 × %0d)", DBG_PERIOD, DBG_PERIOD_BASE);
  end

  reg re_q;
  always @(posedge clk) begin
    if (!resetn || flush) re_q <= 1'b0;
    else re_q <= re;
  end
  wire re_rise = re & ~re_q;

  reg hit_q, re_rise_d;
  always @(posedge clk) begin
    if (!resetn || flush) begin
      hit_q     <= 1'b0;
      re_rise_d <= 1'b0;
    end else begin
      hit_q     <= hit;
      re_rise_d <= re_rise;
    end
  end

  reg [63:0] cnt_access, cnt_hit, cnt_miss;
  reg [63:0] cnt_fills, cnt_new, cnt_evict;
  reg [31:0] valid_count_way0, valid_count_way1;

  reg [63:0] snap_access, snap_hit, snap_miss;
  reg [63:0] snap_fills, snap_new, snap_evict;
  reg [31:0] snap_valid0, snap_valid1;

  reg [63:0] cyc, next_cyc;

  real hr_tot, hr_win, occ_tot, occ_win;

  always @(posedge clk) begin
    if (!resetn || flush) begin
      cnt_access <= 0;
      cnt_hit <= 0;
      cnt_miss <= 0;
      cnt_fills <= 0;
      cnt_new <= 0;
      cnt_evict <= 0;
      valid_count_way0 <= 0;
      valid_count_way1 <= 0;

      snap_access <= 0;
      snap_hit <= 0;
      snap_miss <= 0;
      snap_fills <= 0;
      snap_new <= 0;
      snap_evict <= 0;
      snap_valid0 <= 0;
      snap_valid1 <= 0;

      cyc <= 0;
      next_cyc <= DBG_PERIOD;
    end else begin
      cyc <= cyc + 64'd1;

      if (re_rise) cnt_access <= cnt_access + 64'd1;
      if (re_rise_d) begin
        if (hit_q) cnt_hit <= cnt_hit + 64'd1;
        else cnt_miss <= cnt_miss + 64'd1;
      end

      if (write_sel_way0) begin
        cnt_fills <= cnt_fills + 64'd1;
        if (!valid0[idx]) begin
          cnt_new          <= cnt_new + 64'd1;
          valid_count_way0 <= valid_count_way0 + 32'd1;
        end else begin
          cnt_evict <= cnt_evict + 64'd1;
        end
      end
      if (write_sel_way1) begin
        cnt_fills <= cnt_fills + 64'd1;
        if (!valid1[idx]) begin
          cnt_new          <= cnt_new + 64'd1;
          valid_count_way1 <= valid_count_way1 + 32'd1;
        end else begin
          cnt_evict <= cnt_evict + 64'd1;
        end
      end

      if (DBG_PERIOD != 0 && cyc >= next_cyc) begin
        reg [63:0] d_acc, d_hit, d_miss, d_fill, d_new, d_evict;
        reg [31:0] d_valid0, d_valid1;
        reg [31:0] valid_total, d_valid_total;

        d_acc = cnt_access - snap_access;
        d_hit = cnt_hit - snap_hit;
        d_miss = cnt_miss - snap_miss;
        d_fill = cnt_fills - snap_fills;
        d_new = cnt_new - snap_new;
        d_evict = cnt_evict - snap_evict;

        d_valid0 = valid_count_way0 - snap_valid0;
        d_valid1 = valid_count_way1 - snap_valid1;

        valid_total = valid_count_way0 + valid_count_way1;
        d_valid_total = d_valid0 + d_valid1;

        hr_tot = (cnt_access != 0) ? (100.0 * cnt_hit) / cnt_access : 0.0;
        hr_win = (d_acc != 0) ? (100.0 * d_hit) / d_acc : 0.0;
        occ_tot = (2.0 * NUM_LINES != 0.0) ? (100.0 * valid_total) / (2.0 * NUM_LINES) : 0.0;
        occ_win = (2.0 * NUM_LINES != 0.0) ? (100.0 * d_valid_total) / (2.0 * NUM_LINES) : 0.0;

        if (d_acc != 0 || d_fill != 0 || d_evict != 0 || d_valid_total != 0) begin
          $display("\n[I$] cyc=%0d  acc=%0d hit=%0d miss=%0d  HR=%.2f%%  occ=%0d/%0d (%.2f%%)", cyc,
                   cnt_access, cnt_hit, cnt_miss, hr_tot, valid_total, 2 * NUM_LINES, occ_tot);
          $display(
              "[I$] Δacc=%0d Δhit=%0d Δmiss=%0d  HR(win)=%.2f%%  |  Δfills=%0d Δnew=%0d Δevict=%0d  |  Δocc=%0d (%.2f%%)",
              d_acc, d_hit, d_miss, hr_win, d_fill, d_new, d_evict, d_valid_total, occ_win);
          $display("[I$] occ per way: way0=%0d way1=%0d  (Δway0=%0d Δway1=%0d)",
                   valid_count_way0, valid_count_way1, d_valid0, d_valid1);

          if (d_fill != 0 && d_new == 0 && ((100 * d_evict) / d_fill) >= 90)
            $display(
                "[I$] THRASH WARNING: evictions=%0d / fills=%0d (>=90%% in window)", d_evict, d_fill
            );
        end

        snap_access <= cnt_access;
        snap_hit <= cnt_hit;
        snap_miss <= cnt_miss;
        snap_fills  <= cnt_fills;
        snap_new <= cnt_new;
        snap_evict<= cnt_evict;
        snap_valid0 <= valid_count_way0;
        snap_valid1 <= valid_count_way1;

        next_cyc    <= next_cyc + DBG_PERIOD;
      end
    end
  end

`endif

endmodule
`default_nettype wire

