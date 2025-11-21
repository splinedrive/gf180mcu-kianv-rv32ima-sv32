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

module sv32_table_walk #(
    parameter NUM_ENTRIES_ITLB = 64,
    parameter NUM_ENTRIES_DTLB = 64,
    parameter ITLB_WAYS        = 4,
    parameter DTLB_WAYS        = 4
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire [31:0] address,
    input  wire [31:0] satp,
    output reg  [31:0] pte,
    input  wire        is_instruction,
    input  wire        tlb_flush,
    input  wire        valid,
    output reg         ready,

    output reg         walk_mem_valid,
    input  wire        walk_mem_ready,
    output reg  [31:0] walk_mem_addr,
    input  wire [31:0] walk_mem_rdata
);

  localparam S0 = 0, S1 = 1, S2 = 2, S_LAST = 3;
  reg [$clog2(S_LAST)-1:0] state, next_state;

  wire        sv32_mode = `GET_SATP_MODE(satp);
  wire [19:0] vpn_all = address >> `SV32_PAGE_OFFSET_BITS;
  wire [ 9:0] vpn1 = vpn_all[19:10];
  wire [ 9:0] vpn0 = vpn_all[9:0];
  wire [ 8:0] asid = `GET_SATP_ASID(satp);

  reg [1:0] level, level_nxt;

  reg [31:0] base, base_nxt;

  reg  [28:0] tag;

  wire        itlb_hit;
  reg         itlb_we;
  reg         itlb_v;
  reg  [31:0] itlb_pte_i;
  wire [31:0] itlb_pte_o;

  associative_cache #(
      .TAG_WIDTH         (29),
      .PAYLOAD_WIDTH     (32),
      .TOTAL_ENTRIES     (NUM_ENTRIES_ITLB),
      .WAYS              (ITLB_WAYS),
      .REPLACEMENT_POLICY("LRU")
  ) itlb_I (
      .clk      (clk),
      .resetn   (resetn),
      .flush    (tlb_flush),
      .tag      (tag),
      .we       (itlb_we),
      .valid_i  (itlb_v),
      .hit_o    (itlb_hit),
      .payload_i(itlb_pte_i),
      .payload_o(itlb_pte_o)
  );

  wire        dtlb_hit;
  reg         dtlb_we;
  reg         dtlb_v;
  reg  [31:0] dtlb_pte_i;
  wire [31:0] dtlb_pte_o;

  associative_cache #(
      .TAG_WIDTH         (29),
      .PAYLOAD_WIDTH     (32),
      .TOTAL_ENTRIES     (NUM_ENTRIES_DTLB),
      .WAYS              (DTLB_WAYS),
      .REPLACEMENT_POLICY("LRU")
  ) dtlb_I (
      .clk      (clk),
      .resetn   (resetn),
      .flush    (tlb_flush),
      .tag      (tag),
      .we       (dtlb_we),
      .valid_i  (dtlb_v),
      .hit_o    (dtlb_hit),
      .payload_i(dtlb_pte_i),
      .payload_o(dtlb_pte_o)
  );

  reg  [31:0] pte_nxt;
  reg         ready_nxt;
  reg  [31:0] ppn_tmp;
  reg  [ 9:0] flags_tmp;
  reg  [31:0] vpn_concat_tmp;

  wire        tlb_hit_sel = is_instruction ? itlb_hit : dtlb_hit;
  wire [31:0] tlb_pte_sel = is_instruction ? itlb_pte_o : dtlb_pte_o;

  wire [31:0] first_level_base = (`GET_SATP_PPN(satp) << `SV32_PAGE_OFFSET_BITS);

  wire        probe_s0 = (state == S0) && sv32_mode && valid && !ready;
  wire        miss_s0 = probe_s0 && !tlb_hit_sel;
  wire        miss_s1 = (state == S1) && !tlb_hit_sel;
  wire        cont_s2 = (state == S2) && !ready;

  reg  [31:0] addr_base_sel;
  reg  [ 9:0] idx_sel;
  wire [31:0] calc_addr;

  always @* begin
    if (miss_s0 || miss_s1) begin
      addr_base_sel = first_level_base;
      idx_sel       = vpn1;
    end else begin
      addr_base_sel = base;
      idx_sel       = (level ? vpn1 : vpn0);
    end
  end

  assign calc_addr = addr_base_sel + ({22'd0, idx_sel} << `SV32_PTE_SHIFT);

  always @(posedge clk) begin
    if (!resetn) begin
      state          <= S0;
      level          <= 2'd1;
      base           <= 32'd0;
      pte            <= 32'd0;
      ready          <= 1'b0;

      walk_mem_valid <= 1'b0;
      walk_mem_addr  <= 32'd0;
    end else begin
      state <= next_state;
      level <= level_nxt;
      base  <= base_nxt;
      pte   <= pte_nxt;
      ready <= ready_nxt;

      if (!walk_mem_valid) begin
        if (miss_s0 || miss_s1 || cont_s2) begin
          walk_mem_valid <= 1'b1;
          walk_mem_addr  <= calc_addr;
        end
      end else if (walk_mem_ready) begin
        walk_mem_valid <= 1'b0;
      end
    end
  end

  always @* begin
    next_state = state;
    case (state)
      S0: begin
        if (!sv32_mode && valid) next_state = S0;
        else if (probe_s0 && tlb_hit_sel) next_state = S0;
        else if (probe_s0 && !tlb_hit_sel) next_state = S2;
        else next_state = S0;
      end
      S1: begin
        next_state = tlb_hit_sel ? S0 : S2;
      end
      S2: begin
        next_state = !walk_mem_ready ? S2 : (!ready_nxt ? S2 : S0);
      end
      default: next_state = S0;
    endcase
  end

  always @* begin

    pte_nxt    = pte;
    ready_nxt  = 1'b0;
    level_nxt  = level;
    base_nxt   = base;

    itlb_v     = 1'b0;
    itlb_we    = 1'b0;
    itlb_pte_i = 32'd0;
    dtlb_v     = 1'b0;
    dtlb_we    = 1'b0;
    dtlb_pte_i = 32'd0;

    tag        = {asid, vpn_all};

    case (state)

      S0: begin
        level_nxt = 2'd1;
        base_nxt  = first_level_base;

        if (!sv32_mode && valid) begin

          pte_nxt = `PTE_V_MASK | `PTE_R_MASK | `PTE_W_MASK |
          `PTE_X_MASK
          | ((address >> `SV32_PAGE_OFFSET_BITS) << `SV32_PAGE_OFFSET_BITS);
          ready_nxt = 1'b1;
        end else if (probe_s0) begin

          if (is_instruction) itlb_v = 1'b1;
          else dtlb_v = 1'b1;

          if (tlb_hit_sel) begin

            pte_nxt   = tlb_pte_sel;
            ready_nxt = 1'b1;
            level_nxt = 2'd1;
          end

        end
      end

      S1: begin
        if (is_instruction) itlb_v = 1'b1;
        else dtlb_v = 1'b1;

        if (tlb_hit_sel) begin
          pte_nxt   = tlb_pte_sel;
          ready_nxt = 1'b1;
          level_nxt = 2'd1;
        end
      end

      S2: begin
        if (walk_mem_ready) begin

          ppn_tmp        = walk_mem_rdata >> `SV32_PTE_PPN_SHIFT;
          flags_tmp      = walk_mem_rdata & `PTE_FLAGS;
          vpn_concat_tmp = address >> `SV32_PAGE_OFFSET_BITS;

          if (!`GET_PTE_V(walk_mem_rdata)) begin

            pte_nxt   = 32'd0;
            ready_nxt = 1'b1;
            level_nxt = 2'd1;
          end else if (!
              `GET_PTE_R(walk_mem_rdata)
              && !
              `GET_PTE_W(walk_mem_rdata)
              && !
              `GET_PTE_X(walk_mem_rdata)
              ) begin

            base_nxt  = (ppn_tmp << `SV32_PAGE_OFFSET_BITS);
            level_nxt = level - 1'b1;
            ready_nxt = 1'b0;
          end else begin

            pte_nxt    = ( (level ? (ppn_tmp | (vpn_concat_tmp & ((1<<`SV32_VPN0_SHIFT)-1))) : ppn_tmp)
                        << `SV32_PTE_ALIGNED_PPN_SHIFT ) | flags_tmp;
            ready_nxt = 1'b1;
            level_nxt = 2'd1;

            if (is_instruction) begin
              itlb_v     = 1'b1;
              itlb_we    = 1'b1;
              itlb_pte_i = pte_nxt;
            end else begin
              dtlb_v     = 1'b1;
              dtlb_we    = 1'b1;
              dtlb_pte_i = pte_nxt;
            end
          end
        end
      end

      default: begin
        ready_nxt = 1'b0;
        level_nxt = 2'd1;
      end
    endcase
  end

`ifdef SIM

  integer stuck;
  always @(posedge clk) begin
    if (!resetn) stuck <= 0;
    else begin
      if (walk_mem_valid && !walk_mem_ready) stuck <= stuck + 1;
      else stuck <= 0;
      if (stuck == 100000) begin
        $fatal(1, "PTW stuck: st=%0d lvl=%0d base=%h addr=%h v=%0b r=%0b", state, level, base,
               walk_mem_addr, walk_mem_valid, walk_mem_ready);
      end
    end
  end
`endif

endmodule
`default_nettype wire
