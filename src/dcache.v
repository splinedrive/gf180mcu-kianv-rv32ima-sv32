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

module dcache #(

    parameter integer NUM_LINES  = 512,
    parameter integer LINE_BYTES = 4,
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32,

    parameter FULL_STORE_MISS_ALLOCATE = 1'b0,

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

    input  wire [    ADDR_WIDTH-1:0] cpu_addr_i,
    input  wire [(DATA_WIDTH/8)-1:0] cpu_wmask_i,
    input  wire [    DATA_WIDTH-1:0] cpu_din_i,
    output reg  [    DATA_WIDTH-1:0] cpu_dout_o,
    input  wire                      cpu_valid_i,
    output reg                       cpu_ready_o,

    output reg  [    ADDR_WIDTH-1:0] ram_addr_o,
    output reg  [(DATA_WIDTH/8)-1:0] ram_wmask_o,
    output reg  [    DATA_WIDTH-1:0] ram_wdata_o,
    input  wire [    DATA_WIDTH-1:0] ram_rdata_i,
    output reg                       ram_valid_o,
    input  wire                      ram_ready_i
);

  localparam integer OFFSET_BITS = $clog2(LINE_BYTES);
  localparam integer IDX_BITS = $clog2(NUM_LINES);
  localparam integer TAG_BITS = ADDR_WIDTH - OFFSET_BITS - IDX_BITS;
  localparam integer LANES = DATA_WIDTH / 8;

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
    if ((NUM_LINES % 512) != 0)
      $fatal(1, "dcache: NUM_LINES (%0d) must be a multiple of 512.", NUM_LINES);
    if ((LINE_BYTES * 8) != DATA_WIDTH)
      $fatal(
          1, "dcache: LINE_BYTES*8 (%0d) must equal DATA_WIDTH (%0d).", LINE_BYTES * 8, DATA_WIDTH
      );
    if (HASH_ON && HASH_MODE == 1) begin
      if (HASH_XOR_HI < HASH_XOR_LO) $fatal(1, "dcache: HASH_XOR_HI < HASH_XOR_LO.");
      if (HASH_WIDTH > TAG_BITS) $fatal(1, "dcache: XOR slice wider than TAG bits.");
      if (HASH_WIDTH > IDX_BITS) $fatal(1, "dcache: XOR slice wider than index width.");
    end
  end

  wire [DATA_WIDTH-1:0] cache_rdata;
  wire                  cache_hit;
  reg cache_re, cache_we;
  reg [DATA_WIDTH-1:0] cache_wdata;

  cache_sram_D$ #(
      .NUM_LINES (NUM_LINES),
      .LINE_BYTES(LINE_BYTES),
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) cache_D (
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

  reg [DATA_WIDTH-1:0] cache_rdata_q;
  reg                  cache_hit_q;
  always @(posedge clk) begin
    if (!resetn) begin
      cache_rdata_q <= {DATA_WIDTH{1'b0}};
      cache_hit_q   <= 1'b0;
    end else if (flush) begin
      cache_rdata_q <= {DATA_WIDTH{1'b0}};
      cache_hit_q   <= 1'b0;
    end else begin
      cache_rdata_q <= cache_rdata;
      cache_hit_q   <= cache_hit;
    end
  end

  reg [     LANES-1:0] cpu_wmask_q;
  reg [DATA_WIDTH-1:0] cpu_din_q;
  always @(posedge clk) begin
    if (!resetn) begin
      cpu_wmask_q <= {LANES{1'b0}};
      cpu_din_q   <= {DATA_WIDTH{1'b0}};
    end else if (flush) begin
      cpu_wmask_q <= {LANES{1'b0}};
      cpu_din_q   <= {DATA_WIDTH{1'b0}};
    end else begin
      cpu_wmask_q <= cpu_wmask_i;
      cpu_din_q   <= cpu_din_i;
    end
  end

  wire is_read_req = (cpu_wmask_q == {LANES{1'b0}});
  wire is_full_write = (cpu_wmask_q == {LANES{1'b1}});
  wire is_part_write = (cpu_wmask_q != {LANES{1'b0}}) && !is_full_write;

  function [DATA_WIDTH-1:0] apply_wmask;
    input [DATA_WIDTH-1:0] old_data;
    input [DATA_WIDTH-1:0] new_data;
    input [LANES-1:0] wmask;
    integer i;
    begin
      for (i = 0; i < LANES; i = i + 1)
      apply_wmask[i*8+:8] = wmask[i] ? new_data[i*8+:8] : old_data[i*8+:8];
    end
  endfunction

  localparam S_IDLE    = 3'd0,
             S_READ    = 3'd1,
             S_CHECK   = 3'd2,
             S_RD_REQ  = 3'd3,
             S_REFILL  = 3'd4,
             S_WR_REQ  = 3'd5;

  reg [2:0] state, next_state;
  always @(posedge clk) begin
    if (!resetn) state <= S_IDLE;
    else if (flush) state <= S_IDLE;
    else state <= next_state;
  end

  reg op_is_read, op_is_full, op_is_partial;
  reg wr_from_hit;

  reg pending_we;
  reg [DATA_WIDTH-1:0] pending_data;

  wire want_alloc_full_miss = op_is_full && !wr_from_hit && FULL_STORE_MISS_ALLOCATE;
  wire want_alloc = wr_from_hit || op_is_partial || want_alloc_full_miss;

  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE:   if (cpu_valid_i) next_state = S_READ;
      S_READ:   next_state = S_CHECK;
      S_CHECK: begin
        if (cache_hit_q) begin
          next_state = is_read_req ? S_IDLE : S_WR_REQ;
        end else begin
          if (is_read_req) next_state = S_RD_REQ;
          else if (is_full_write) next_state = S_WR_REQ;
          else next_state = S_RD_REQ;
        end
      end
      S_RD_REQ: if (ram_ready_i) next_state = op_is_read ? S_REFILL : S_WR_REQ;
      S_REFILL: next_state = S_IDLE;
      S_WR_REQ: if (ram_ready_i) next_state = S_IDLE;
      default:  next_state = S_IDLE;
    endcase
  end

  always @(posedge clk) begin
    if (!resetn) begin
      op_is_read    <= 1'b0;
      op_is_full    <= 1'b0;
      op_is_partial <= 1'b0;
      wr_from_hit   <= 1'b0;
      pending_we    <= 1'b0;
      pending_data  <= {DATA_WIDTH{1'b0}};
    end else if (flush) begin
      op_is_read    <= 1'b0;
      op_is_full    <= 1'b0;
      op_is_partial <= 1'b0;
      wr_from_hit   <= 1'b0;
      pending_we    <= 1'b0;
      pending_data  <= {DATA_WIDTH{1'b0}};
    end else begin
      if (state == S_WR_REQ && ram_ready_i && pending_we) pending_we <= 1'b0;

      case (state)
        S_CHECK: begin
          op_is_read    <= is_read_req;
          op_is_full    <= is_full_write;
          op_is_partial <= is_part_write;

          if (cache_hit_q) begin
            wr_from_hit <= !is_read_req;
            if (!is_read_req) begin
              pending_data <= is_full_write ? cpu_din_q : apply_wmask(
                  cache_rdata_q, cpu_din_q, cpu_wmask_q
              );
              pending_we <= 1'b1;
            end
          end else begin
            wr_from_hit <= 1'b0;
            if (is_full_write) begin
              pending_data <= cpu_din_q;
              pending_we   <= 1'b1;
            end
          end
        end

        S_RD_REQ:
        if (ram_ready_i && op_is_partial) begin
          pending_data <= apply_wmask(ram_rdata_i, cpu_din_q, cpu_wmask_q);
          pending_we   <= 1'b1;
        end
        default: ;
      endcase
    end
  end

  always @(*) begin
    cpu_ready_o = 1'b0;
    cpu_dout_o  = {DATA_WIDTH{1'b0}};

    ram_valid_o = 1'b0;
    ram_wmask_o = {LANES{1'b0}};
    ram_wdata_o = cpu_din_q;
    ram_addr_o  = cpu_addr_i;

    cache_re    = 1'b0;
    cache_we    = 1'b0;
    cache_wdata = {DATA_WIDTH{1'b0}};

    case (state)
      S_IDLE:   if (cpu_valid_i) cache_re = 1'b1;
      S_READ:   cache_re = 1'b1;
      S_CHECK:
      if (cache_hit_q && is_read_req) begin
        cpu_ready_o = 1'b1;
        cpu_dout_o  = cache_rdata_q;
      end
      S_RD_REQ: ram_valid_o = 1'b1;
      S_REFILL: begin
        cache_we    = 1'b1;
        cache_wdata = ram_rdata_i;
        cpu_ready_o = 1'b1;
        cpu_dout_o  = ram_rdata_i;
      end
      S_WR_REQ: begin
        ram_valid_o = 1'b1;
        ram_wmask_o = cpu_wmask_q;
        ram_wdata_o = cpu_din_q;
        if (ram_ready_i) begin
          if (pending_we && want_alloc) begin
            cache_we    = 1'b1;
            cache_wdata = pending_data;
          end
          cpu_ready_o = 1'b1;
        end
      end
      default:  ;
    endcase
  end

`ifdef CACHE_DBG

  initial begin
    $display("[D$] Geometry: NUM_LINES=%0d LINE_BYTES=%0d DATA_BITS=%0d TAG_BITS=%0d", NUM_LINES,
             LINE_BYTES, DATA_WIDTH, TAG_BITS);
    if (!HASH_ON) $display("[D$] Index hashing: OFF");
    else if (HASH_MODE == 1)
      $display("[D$] Index hashing: ON  (XOR tag[%0d:%0d])", HASH_XOR_HI, HASH_XOR_LO);
    else $display("[D$] Index hashing: ON  (fold+rotate)");
  end

`endif

`ifdef CACHE_DBG

`ifndef DBG_PERIOD
  localparam integer DBG_PERIOD_BASE = 1_000_000;
`else
  localparam integer DBG_PERIOD_BASE = `DBG_PERIOD;
`endif
  localparam integer DBG_PERIOD = DBG_PERIOD_BASE * 10;

  reg re_q_dbg;
  always @(posedge clk) begin
    if (!resetn) re_q_dbg <= 1'b0;
    else if (flush) re_q_dbg <= 1'b0;
    else re_q_dbg <= cache_re;
  end
  wire        re_rise_dbg = cache_re & ~re_q_dbg;

  wire        done_load_hit = (state == S_CHECK) && cache_hit_q && is_read_req;
  wire        done_load_miss = (state == S_REFILL) && !is_read_req;
  wire        done_store = (state == S_WR_REQ) && ram_ready_i && !is_read_req;
  wire        req_done_dbg = done_load_hit | done_load_miss | done_store;

  reg  [63:0] acc_tot;
  reg [63:0] acc_rd, acc_wr_full, acc_wr_part;

  reg [63:0] hit_tot, miss_tot;
  reg [63:0] hit_rd, miss_rd;
  reg [63:0] hit_wr_full, miss_wr_full;
  reg [63:0] hit_wr_part, miss_wr_part;

  reg [63:0] rd_tx_cnt;
  reg [63:0] wr_tx_cnt;
  reg [63:0] alloc_cnt;
  reg [63:0] new_cnt, evict_cnt;
  reg [63:0] noalloc_full_miss_cnt;
  reg [63:0] merge_cnt;

  reg [31:0] valid_count;

  reg        inflight;
  reg [31:0] lat_ctr;
  reg [63:0] sum_lat_tot, sum_lat_win;
  reg [31:0] max_lat_tot, max_lat_win;
  reg [63:0] done_cnt_tot, done_cnt_win;

  reg [63:0] stall_cycles_tot, stall_cycles_win;
  reg [63:0] ram_wait_tot, ram_wait_win;

  reg [63:0] snap_acc_tot, snap_hit_tot, snap_miss_tot;
  reg [63:0] snap_acc_rd, snap_acc_wr_full, snap_acc_wr_part;
  reg [63:0] snap_hit_rd, snap_miss_rd;
  reg [63:0] snap_hit_wr_full, snap_miss_wr_full;
  reg [63:0] snap_hit_wr_part, snap_miss_wr_part;

  reg [63:0] snap_rd_tx, snap_wr_tx;
  reg [63:0] snap_alloc, snap_new, snap_evict, snap_noalloc_full, snap_merge;

  reg [31:0] snap_valid;
  reg [63:0] snap_done_cnt;
  reg [63:0] snap_stall, snap_ram_wait;

  reg [63:0] cyc, next_cyc;

  real hr_tot, hr_win;
  real hr_rd_tot, hr_rd_win, hr_wr_tot, hr_wr_win;
  real lat_avg_tot, lat_avg_win;
  real occ_tot, occ_win;

  initial begin
    $display("[D$] Debug period: %0d cycles (10 × %0d)", DBG_PERIOD, DBG_PERIOD_BASE);
  end

  always @(posedge clk) begin
    if (!resetn || flush) begin
      acc_tot               <= 0;
      acc_rd                <= 0;
      acc_wr_full           <= 0;
      acc_wr_part           <= 0;
      hit_tot               <= 0;
      miss_tot              <= 0;
      hit_rd                <= 0;
      miss_rd               <= 0;
      hit_wr_full           <= 0;
      miss_wr_full          <= 0;
      hit_wr_part           <= 0;
      miss_wr_part          <= 0;

      rd_tx_cnt             <= 0;
      wr_tx_cnt             <= 0;
      alloc_cnt             <= 0;
      new_cnt               <= 0;
      evict_cnt             <= 0;
      noalloc_full_miss_cnt <= 0;
      merge_cnt             <= 0;

      valid_count           <= 0;

      inflight              <= 1'b0;
      lat_ctr               <= 0;
      sum_lat_tot           <= 0;
      sum_lat_win           <= 0;
      max_lat_tot           <= 0;
      max_lat_win           <= 0;
      done_cnt_tot          <= 0;
      done_cnt_win          <= 0;

      stall_cycles_tot      <= 0;
      stall_cycles_win      <= 0;
      ram_wait_tot          <= 0;
      ram_wait_win          <= 0;

      snap_acc_tot          <= 0;
      snap_hit_tot          <= 0;
      snap_miss_tot         <= 0;
      snap_acc_rd           <= 0;
      snap_acc_wr_full      <= 0;
      snap_acc_wr_part      <= 0;
      snap_hit_rd           <= 0;
      snap_miss_rd          <= 0;
      snap_hit_wr_full      <= 0;
      snap_miss_wr_full     <= 0;
      snap_hit_wr_part      <= 0;
      snap_miss_wr_part     <= 0;

      snap_rd_tx            <= 0;
      snap_wr_tx            <= 0;
      snap_alloc            <= 0;
      snap_new              <= 0;
      snap_evict            <= 0;
      snap_noalloc_full     <= 0;
      snap_merge            <= 0;

      snap_valid            <= 0;
      snap_done_cnt         <= 0;
      snap_stall            <= 0;
      snap_ram_wait         <= 0;

      cyc                   <= 0;
      next_cyc              <= DBG_PERIOD;
    end else begin
      cyc <= cyc + 64'd1;

      if (re_rise_dbg && !inflight) begin
        inflight <= 1'b1;
        lat_ctr  <= 0;
      end else if (inflight) begin
        lat_ctr <= lat_ctr + 1;
      end
      if (req_done_dbg && inflight) begin
        inflight     <= 1'b0;
        sum_lat_tot  <= sum_lat_tot + lat_ctr;
        sum_lat_win  <= sum_lat_win + lat_ctr;
        done_cnt_tot <= done_cnt_tot + 64'd1;
        done_cnt_win <= done_cnt_win + 64'd1;
        if (lat_ctr > max_lat_tot) max_lat_tot <= lat_ctr;
        if (lat_ctr > max_lat_win) max_lat_win <= lat_ctr;
      end

      if (cpu_valid_i && !cpu_ready_o) begin
        stall_cycles_tot <= stall_cycles_tot + 64'd1;
        stall_cycles_win <= stall_cycles_win + 64'd1;
      end
      if ((state == S_RD_REQ || state == S_WR_REQ) && !ram_ready_i) begin
        ram_wait_tot <= ram_wait_tot + 64'd1;
        ram_wait_win <= ram_wait_win + 64'd1;
      end

      if (state == S_CHECK) begin
        acc_tot <= acc_tot + 64'd1;

        if (is_read_req) begin
          acc_rd <= acc_rd + 64'd1;
          if (cache_hit_q) begin
            hit_tot <= hit_tot + 64'd1;
            hit_rd  <= hit_rd + 64'd1;
          end else begin
            miss_tot <= miss_tot + 64'd1;
            miss_rd  <= miss_rd + 64'd1;
          end
        end else if (is_full_write) begin
          acc_wr_full <= acc_wr_full + 64'd1;
          if (cache_hit_q) begin
            hit_tot     <= hit_tot + 64'd1;
            hit_wr_full <= hit_wr_full + 64'd1;
          end else begin
            miss_tot     <= miss_tot + 64'd1;
            miss_wr_full <= miss_wr_full + 64'd1;
            if (!FULL_STORE_MISS_ALLOCATE) noalloc_full_miss_cnt <= noalloc_full_miss_cnt + 64'd1;
          end
        end else begin

          acc_wr_part <= acc_wr_part + 64'd1;
          if (cache_hit_q) begin
            hit_tot     <= hit_tot + 64'd1;
            hit_wr_part <= hit_wr_part + 64'd1;
          end else begin
            miss_tot     <= miss_tot + 64'd1;
            miss_wr_part <= miss_wr_part + 64'd1;
          end
        end
      end

      if (state == S_RD_REQ && ram_ready_i) begin
        rd_tx_cnt <= rd_tx_cnt + 64'd1;
        if (op_is_partial) merge_cnt <= merge_cnt + 64'd1;
      end
      if (state == S_WR_REQ && ram_ready_i) begin
        wr_tx_cnt <= wr_tx_cnt + 64'd1;
      end

      if (cache_we) begin
        alloc_cnt <= alloc_cnt + 64'd1;

        if (!cache_D.valid_ff[idx]) begin
          new_cnt     <= new_cnt + 64'd1;
          valid_count <= valid_count + 32'd1;
        end else begin
          evict_cnt <= evict_cnt + 64'd1;
        end
      end

      if (DBG_PERIOD != 0 && cyc >= next_cyc) begin

        reg [63:0] d_acc_tot, d_hit_tot, d_miss_tot;
        reg [63:0] d_acc_rd, d_acc_wr_full, d_acc_wr_part;
        reg [63:0] d_hit_rd, d_miss_rd;
        reg [63:0] d_hit_wr_full, d_miss_wr_full;
        reg [63:0] d_hit_wr_part, d_miss_wr_part;
        reg [63:0] d_rd_tx, d_wr_tx, d_alloc, d_new, d_evict, d_noalloc_full, d_merge;
        reg [31:0] d_valid;
        reg [63:0] d_done, d_stall, d_ram_wait;

        d_acc_tot = acc_tot - snap_acc_tot;
        d_hit_tot = hit_tot - snap_hit_tot;
        d_miss_tot = miss_tot - snap_miss_tot;

        d_acc_rd = acc_rd - snap_acc_rd;
        d_acc_wr_full = acc_wr_full - snap_acc_wr_full;
        d_acc_wr_part = acc_wr_part - snap_acc_wr_part;

        d_hit_rd = hit_rd - snap_hit_rd;
        d_miss_rd = miss_rd - snap_miss_rd;

        d_hit_wr_full = hit_wr_full - snap_hit_wr_full;
        d_miss_wr_full = miss_wr_full - snap_miss_wr_full;

        d_hit_wr_part = hit_wr_part - snap_hit_wr_part;
        d_miss_wr_part = miss_wr_part - snap_miss_wr_part;

        d_rd_tx = rd_tx_cnt - snap_rd_tx;
        d_wr_tx = wr_tx_cnt - snap_wr_tx;
        d_alloc = alloc_cnt - snap_alloc;
        d_new = new_cnt - snap_new;
        d_evict = evict_cnt - snap_evict;
        d_noalloc_full = noalloc_full_miss_cnt - snap_noalloc_full;
        d_merge = merge_cnt - snap_merge;

        d_valid = valid_count - snap_valid;

        d_done = done_cnt_tot - snap_done_cnt;
        d_stall = stall_cycles_tot - snap_stall;
        d_ram_wait = ram_wait_tot - snap_ram_wait;

        hr_tot = (acc_tot != 0) ? (100.0 * hit_tot) / acc_tot : 0.0;
        hr_win = (d_acc_tot != 0) ? (100.0 * d_hit_tot) / d_acc_tot : 0.0;

        hr_rd_tot = (acc_rd != 0) ? (100.0 * hit_rd) / acc_rd : 0.0;
        hr_wr_tot = ((acc_wr_full+acc_wr_part)!=0) ?
                   (100.0*(hit_wr_full+hit_wr_part))/(acc_wr_full+acc_wr_part) : 0.0;

        hr_rd_win = (d_acc_rd != 0) ? (100.0 * d_hit_rd) / d_acc_rd : 0.0;
        hr_wr_win = ((d_acc_wr_full+d_acc_wr_part)!=0) ?
                   (100.0*(d_hit_wr_full+d_hit_wr_part))/(d_acc_wr_full+d_acc_wr_part) : 0.0;

        occ_tot = (NUM_LINES != 0) ? (100.0 * valid_count) / NUM_LINES : 0.0;
        occ_win = (NUM_LINES != 0) ? (100.0 * d_valid) / NUM_LINES : 0.0;

        lat_avg_tot = (done_cnt_tot != 0) ? (1.0 * sum_lat_tot) / done_cnt_tot : 0.0;
        lat_avg_win = (d_done != 0) ? (1.0 * sum_lat_win) / d_done : 0.0;

        $display("\n[D$] cyc=%0d  acc=%0d hit=%0d miss=%0d  HR=%.2f%%  occ=%0d/%0d (%.2f%%)", cyc,
                 acc_tot, hit_tot, miss_tot, hr_tot, valid_count, NUM_LINES, occ_tot);
        $display(
            "[D$] Δacc=%0d Δhit=%0d Δmiss=%0d  HR(win)=%.2f%%  |  Δfills=%0d Δnew=%0d Δevict=%0d  |  Δocc=%0d (%.2f%%)",
            d_acc_tot, d_hit_tot, d_miss_tot, hr_win, d_alloc, d_new, d_evict, d_valid, occ_win);

        $display(
            "[D$] R/W split (total): R acc=%0d HR=%.2f%% | W acc=%0d (full=%0d, part=%0d) HR=%.2f%%",
            acc_rd, hr_rd_tot, (acc_wr_full + acc_wr_part), acc_wr_full, acc_wr_part, hr_wr_tot);
        $display(
            "[D$] R/W split (win)  : R Δacc=%0d HR=%.2f%% | W Δacc=%0d (full=%0d, part=%0d) HR=%.2f%%",
            d_acc_rd, hr_rd_win, (d_acc_wr_full + d_acc_wr_part), d_acc_wr_full, d_acc_wr_part,
            hr_wr_win);

        $display("[D$] Bus: Δrd_tx=%0d Δwr_tx=%0d | policy: Δnoalloc_full=%0d Δmerge=%0d",
                 d_rd_tx, d_wr_tx, d_noalloc_full, d_merge);

        $display(
            "[D$] Latency (cycles): avg_tot=%.2f avg_win=%.2f  max_tot=%0d max_win=%0d  |  Δdone=%0d",
            lat_avg_tot, lat_avg_win, max_lat_tot, max_lat_win, d_done);

        $display("[D$] Stall: Δcpu_wait=%0d  Δram_wait=%0d", d_stall, d_ram_wait);

        if (d_alloc != 0 && d_new == 0 && ((100 * d_evict) / d_alloc) >= 90)
          $display(
              "[D$] THRASH WARNING: evictions=%0d / fills=%0d (>=90%% in window)", d_evict, d_alloc
          );

        sum_lat_win <= 0;
        max_lat_win <= 0;
        done_cnt_win <= 0;

        snap_acc_tot <= acc_tot;
        snap_hit_tot <= hit_tot;
        snap_miss_tot <= miss_tot;
        snap_acc_rd <= acc_rd;
        snap_acc_wr_full <= acc_wr_full;
        snap_acc_wr_part <= acc_wr_part;
        snap_hit_rd <= hit_rd;
        snap_miss_rd <= miss_rd;
        snap_hit_wr_full <= hit_wr_full;
        snap_miss_wr_full <= miss_wr_full;
        snap_hit_wr_part <= hit_wr_part;
        snap_miss_wr_part <= miss_wr_part;

        snap_rd_tx <= rd_tx_cnt;
        snap_wr_tx <= wr_tx_cnt;
        snap_alloc <= alloc_cnt;
        snap_new <= new_cnt;
        snap_evict <= evict_cnt;
        snap_noalloc_full <= noalloc_full_miss_cnt;
        snap_merge <= merge_cnt;

        snap_valid <= valid_count;
        snap_done_cnt <= done_cnt_tot;
        snap_stall <= stall_cycles_tot;
        snap_ram_wait <= ram_wait_tot;

        next_cyc <= next_cyc + DBG_PERIOD;
      end
    end
  end

`endif

endmodule
`default_nettype wire
