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

module associative_cache #(
    parameter TAG_WIDTH          = 29,
    parameter PAYLOAD_WIDTH      = 32,
    parameter TOTAL_ENTRIES      = 64,
    parameter WAYS               = 4,
    parameter REPLACEMENT_POLICY = "LRU",

    parameter integer PTE_G_BIT = 5
) (
    input wire clk,
    input wire resetn,
    input wire flush,

    input  wire [    TAG_WIDTH-1:0] tag,
    input  wire                     we,
    input  wire                     valid_i,
    output wire                     hit_o,
    input  wire [PAYLOAD_WIDTH-1:0] payload_i,
    output reg  [PAYLOAD_WIDTH-1:0] payload_o
);

  localparam integer SETS = TOTAL_ENTRIES / WAYS;
  localparam integer SET_WIDTH = $clog2(SETS);
  localparam integer WAY_WIDTH = $clog2(WAYS);

  localparam integer VPN_WIDTH = 20;
  localparam integer ASID_WIDTH = TAG_WIDTH - VPN_WIDTH;

  wire [    VPN_WIDTH-1:0] vpn_i = tag[VPN_WIDTH-1:0];
  wire [   ASID_WIDTH-1:0] asid_i = tag[TAG_WIDTH-1:VPN_WIDTH];

  wire [    SET_WIDTH-1:0] set_idx = vpn_i[SET_WIDTH-1:0];

  reg                      val_ram                             [0:SETS-1][0:WAYS-1];
  reg  [    VPN_WIDTH-1:0] vpn_ram                             [0:SETS-1][0:WAYS-1];
  reg  [   ASID_WIDTH-1:0] asid_ram                            [0:SETS-1][0:WAYS-1];
  reg  [PAYLOAD_WIDTH-1:0] pte_ram                             [0:SETS-1][0:WAYS-1];
  reg                      g_ram                               [0:SETS-1][0:WAYS-1];

  wire [         WAYS-1:0] way_hit;
  genvar w;
  generate
    for (w = 0; w < WAYS; w = w + 1) begin : GEN_HIT
      assign way_hit[w] =
        valid_i &&
        val_ram[set_idx][w] &&
        (vpn_ram[set_idx][w]  == vpn_i) &&
        ( g_ram[set_idx][w] || (asid_ram[set_idx][w] == asid_i) );
    end
  endgenerate

  assign hit_o = |way_hit;

  reg [WAY_WIDTH-1:0] hit_way;
  integer hit_i;
  always @(*) begin
    hit_way = {WAY_WIDTH{1'b0}};
    for (hit_i = 0; hit_i < WAYS; hit_i = hit_i + 1)
    if (way_hit[hit_i]) hit_way = hit_i[WAY_WIDTH-1:0];
  end

  always @(*) begin
    payload_o = {PAYLOAD_WIDTH{1'b0}};
    if (hit_o) payload_o = pte_ram[set_idx][hit_way];
  end

  wire [WAY_WIDTH-1:0] replace_way;

  generate
    if (REPLACEMENT_POLICY == "LRU") begin : GEN_LRU
      lru_replacement #(
          .SETS     (SETS),
          .SET_WIDTH(SET_WIDTH),
          .WAYS     (WAYS)
      ) u_lru (
          .clk       (clk),
          .resetn    (resetn),
          .flush     (flush),
          .set_idx   (set_idx),
          .access    (valid_i && (hit_o || we)),
          .access_way(hit_o ? hit_way : replace_way),
          .lru_way   (replace_way)
      );
    end else if (REPLACEMENT_POLICY == "LPRU") begin : GEN_LPRU
      lpru_replacement #(
          .SETS     (SETS),
          .SET_WIDTH(SET_WIDTH),
          .WAYS     (WAYS)
      ) u_lpru (
          .clk       (clk),
          .resetn    (resetn),
          .flush     (flush),
          .set_idx   (set_idx),
          .access    (valid_i && (hit_o || we)),
          .access_way(hit_o ? hit_way : replace_way),
          .lpru_way  (replace_way)
      );
    end else if (REPLACEMENT_POLICY == "RANDOM") begin : GEN_RAND
      random_replacement #(
          .WAYS(WAYS)
      ) u_rand (
          .clk       (clk),
          .resetn    (resetn),
          .flush     (flush),
          .random_way(replace_way)
      );
    end else begin : GEN_RR
      round_robin_replacement #(
          .SETS     (SETS),
          .SET_WIDTH(SET_WIDTH),
          .WAYS     (WAYS)
      ) u_rr (
          .clk     (clk),
          .resetn  (resetn),
          .flush   (flush),
          .set_idx (set_idx),
          .access  (valid_i && we && !hit_o),
          .next_way(replace_way)
      );
    end
  endgenerate

  wire [WAYS-1:0] way_we;
  generate
    for (w = 0; w < WAYS; w = w + 1) begin : GEN_WE
      assign way_we[w] = valid_i && we &&
                         ( hit_o ? (hit_way == w[WAY_WIDTH-1:0])
                                 : (replace_way == w[WAY_WIDTH-1:0]) );
    end
  endgenerate

  wire g_from_pte = payload_i[PTE_G_BIT];

  integer s, i;
  always @(posedge clk) begin
    if (!resetn) begin
      for (s = 0; s < SETS; s = s + 1) begin
        for (i = 0; i < WAYS; i = i + 1) begin
          val_ram[s][i]  <= 1'b0;
          vpn_ram[s][i]  <= {VPN_WIDTH{1'b0}};
          asid_ram[s][i] <= {ASID_WIDTH{1'b0}};
          pte_ram[s][i]  <= {PAYLOAD_WIDTH{1'b0}};
          g_ram[s][i]    <= 1'b0;
        end
      end
    end else if (flush) begin
      for (s = 0; s < SETS; s = s + 1) begin
        for (i = 0; i < WAYS; i = i + 1) begin
          val_ram[s][i]  <= 1'b0;
          vpn_ram[s][i]  <= {VPN_WIDTH{1'b0}};
          asid_ram[s][i] <= {ASID_WIDTH{1'b0}};
          pte_ram[s][i]  <= {PAYLOAD_WIDTH{1'b0}};
          g_ram[s][i]    <= 1'b0;
        end
      end
    end else begin
      for (i = 0; i < WAYS; i = i + 1) begin
        if (way_we[i]) begin
          val_ram[set_idx][i]  <= 1'b1;
          vpn_ram[set_idx][i]  <= vpn_i;
          asid_ram[set_idx][i] <= g_from_pte ? {ASID_WIDTH{1'b0}} : asid_i;
          pte_ram[set_idx][i]  <= payload_i;
          g_ram[set_idx][i]    <= g_from_pte;
        end
      end
    end
  end
endmodule

module lru_replacement #(
    parameter SETS = 16,
    parameter SET_WIDTH = 4,
    parameter WAYS = 4
) (
    input  wire                    clk,
    input  wire                    resetn,
    input  wire                    flush,
    input  wire [   SET_WIDTH-1:0] set_idx,
    input  wire                    access,
    input  wire [$clog2(WAYS)-1:0] access_way,
    output reg  [$clog2(WAYS)-1:0] lru_way
);
  localparam WAY_WIDTH = $clog2(WAYS);
  generate
    if (WAYS == 2) begin : two_way
      reg lru_bit[SETS-1:0];
      integer i;
      always @(posedge clk) begin
        if (!resetn) begin
          for (i = 0; i < SETS; i = i + 1) begin
            lru_bit[i] <= 1'b0;
          end
        end else if (flush) begin
          for (i = 0; i < SETS; i = i + 1) begin
            lru_bit[i] <= 1'b0;
          end
        end else if (access) begin
          lru_bit[set_idx] <= access_way[0];
        end
      end
      always @(*) begin
        lru_way = ~lru_bit[set_idx];
      end
    end else if (WAYS == 4) begin : four_way
      reg [2:0] lru_state[SETS-1:0];
      integer i;
      always @(posedge clk) begin
        if (!resetn) begin
          for (i = 0; i < SETS; i = i + 1) begin
            lru_state[i] <= 3'b000;
          end
        end else if (flush) begin
          for (i = 0; i < SETS; i = i + 1) begin
            lru_state[i] <= 3'b000;
          end
        end else if (access) begin
          case (access_way)
            2'b00: lru_state[set_idx] <= {1'b1, lru_state[set_idx][1], 1'b1};
            2'b01: lru_state[set_idx] <= {1'b1, lru_state[set_idx][1], 1'b0};
            2'b10: lru_state[set_idx] <= {1'b0, 1'b1, lru_state[set_idx][0]};
            2'b11: lru_state[set_idx] <= {1'b0, 1'b0, lru_state[set_idx][0]};
          endcase
        end
      end
      always @(*) begin
        case (lru_state[set_idx])
          3'b000: lru_way = 2'b00;
          3'b001: lru_way = 2'b01;
          3'b010: lru_way = 2'b00;
          3'b011: lru_way = 2'b01;
          3'b100: lru_way = 2'b10;
          3'b101: lru_way = 2'b11;
          3'b110: lru_way = 2'b10;
          3'b111: lru_way = 2'b11;
        endcase
      end
    end else begin : general_way
      reg [WAY_WIDTH:0] age_counter[WAYS-1:0][SETS-1:0];
      integer i, j;
      always @(posedge clk) begin
        if (!resetn) begin
          for (i = 0; i < WAYS; i = i + 1) begin
            for (j = 0; j < SETS; j = j + 1) begin
              age_counter[i][j] <= i;
            end
          end
        end else if (flush) begin
          for (i = 0; i < WAYS; i = i + 1) begin
            for (j = 0; j < SETS; j = j + 1) begin
              age_counter[i][j] <= i;
            end
          end
        end else if (access) begin
          for (i = 0; i < WAYS; i = i + 1) begin
            if (i == access_way) begin
              age_counter[i][set_idx] <= 0;
            end else begin
              age_counter[i][set_idx] <= age_counter[i][set_idx] + 1;
            end
          end
        end
      end
      always @(*) begin
        lru_way = 0;
        begin : lru_search
          integer k;
          for (k = 1; k < WAYS; k = k + 1) begin
            if (age_counter[k][set_idx] > age_counter[lru_way][set_idx]) begin
              lru_way = k[WAY_WIDTH-1:0];
            end
          end
        end
      end
    end
  endgenerate
endmodule

module lpru_replacement #(
    parameter SETS = 16,
    parameter SET_WIDTH = 4,
    parameter WAYS = 4
) (
    input  wire                    clk,
    input  wire                    resetn,
    input  wire                    flush,
    input  wire [   SET_WIDTH-1:0] set_idx,
    input  wire                    access,
    input  wire [$clog2(WAYS)-1:0] access_way,
    output reg  [$clog2(WAYS)-1:0] lpru_way
);
  localparam WAY_WIDTH = $clog2(WAYS);

  reg [WAYS-1:0] usage_bits[SETS-1:0];

  integer i, j;

  always @(posedge clk) begin
    if (!resetn) begin
      for (i = 0; i < SETS; i = i + 1) begin
        usage_bits[i] <= {WAYS{1'b0}};
      end
    end else if (flush) begin
      for (i = 0; i < SETS; i = i + 1) begin
        usage_bits[i] <= {WAYS{1'b0}};
      end
    end else if (access) begin
      usage_bits[set_idx][access_way] <= 1'b1;
      if (&usage_bits[set_idx]) begin
        usage_bits[set_idx] <= (1 << access_way);
      end
    end
  end

  reg found;
  always @(*) begin
    lpru_way = 0;
    found = 0;
    for (j = 0; j < WAYS; j = j + 1) begin
      if (!usage_bits[set_idx][j] && !found) begin
        lpru_way = j[WAY_WIDTH-1:0];
        found = 1;
      end
    end
  end

endmodule

module random_replacement #(
    parameter WAYS = 4
) (
    input  wire                    clk,
    input  wire                    resetn,
    input  wire                    flush,
    output reg  [$clog2(WAYS)-1:0] random_way
);
  localparam WAY_WIDTH = $clog2(WAYS);

  reg [7:0] lfsr;

  always @(posedge clk) begin
    if (!resetn) begin
      lfsr <= 8'h1;
    end else if (flush) begin
      lfsr <= 8'h1;
    end else begin
      lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end
  end

  always @(*) begin
    random_way = lfsr[WAY_WIDTH-1:0];
  end

endmodule

module round_robin_replacement #(
    parameter SETS = 16,
    parameter SET_WIDTH = 4,
    parameter WAYS = 4
) (
    input  wire                    clk,
    input  wire                    resetn,
    input  wire                    flush,
    input  wire [   SET_WIDTH-1:0] set_idx,
    input  wire                    access,
    output reg  [$clog2(WAYS)-1:0] next_way
);
  localparam WAY_WIDTH = $clog2(WAYS);
  localparam MAX_WAY = WAYS - 1;
  reg [WAY_WIDTH-1:0] rr_counter[SETS-1:0];
  integer i;
  always @(posedge clk) begin
    if (!resetn) begin
      for (i = 0; i < SETS; i = i + 1) begin
        rr_counter[i] <= 0;
      end
    end else if (flush) begin
      for (i = 0; i < SETS; i = i + 1) begin
        rr_counter[i] <= 0;
      end
    end else if (access) begin
      if (rr_counter[set_idx] == MAX_WAY[WAY_WIDTH-1:0]) begin
        rr_counter[set_idx] <= 0;
      end else begin
        rr_counter[set_idx] <= rr_counter[set_idx] + 1'b1;
      end
    end
  end
  always @(*) begin
    next_way = rr_counter[set_idx];
  end
endmodule
