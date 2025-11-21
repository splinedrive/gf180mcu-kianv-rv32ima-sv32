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

module cache #(
    parameter BYPASS_CACHES = 0
) (
    input wire clk,
    input wire resetn,
`ifdef USE_POWER_PINS
    inout      VDD,
    inout      VSS,
`endif
    input wire iflush,
    input wire is_instruction,

    input  wire [31:0] cpu_addr_i,
    input  wire [31:0] cpu_din_i,
    input  wire [ 3:0] cpu_wmask_i,
    input  wire        cpu_valid_i,
    output reg  [31:0] cpu_dout_o,
    output reg         cpu_ready_o,

    output reg  [31:0] cache_addr_o,
    output reg  [31:0] cache_din_o,
    output reg  [ 3:0] cache_wmask_o,
    output reg         cache_valid_o,
    input  wire [31:0] cache_dout_i,
    input  wire        cache_ready_i
);

  generate
    if (BYPASS_CACHES) begin : gen_bypass
      always @* begin
        cache_addr_o  = cpu_addr_i;
        cache_din_o   = cpu_din_i;
        cache_wmask_o = cpu_wmask_i;
        cache_valid_o = cpu_valid_i;

        cpu_dout_o    = cache_dout_i;
        cpu_ready_o   = cache_ready_i;
      end

    end else begin : gen_cached

      wire [31:0] ic_cpu_dout_o;
      wire        ic_cpu_ready_o;
      wire [31:0] ic_ram_addr_o;
      wire        ic_ram_valid_o;

      wire [31:0] dc_cpu_dout_o;
      wire        dc_cpu_ready_o;
      wire [31:0] dc_ram_addr_o;
      wire [ 3:0] dc_ram_wmask_o;
      wire [31:0] dc_ram_wdata_o;
      wire        dc_ram_valid_o;

      wire [31:0] shared_ram_rdata_i = cache_dout_i;
      wire        shared_ram_ready_i = cache_ready_i;

      icache icache_I (
          .clk   (clk),
          .resetn(resetn),
`ifdef USE_POWER_PINS
          .VDD   (VDD),
          .VSS   (VSS),
`endif
          .flush (iflush),

          .cpu_addr_i (cpu_addr_i),
          .cpu_dout_o (ic_cpu_dout_o),
          .cpu_valid_i(cpu_valid_i & is_instruction),
          .cpu_ready_o(ic_cpu_ready_o),

          .ram_addr_o (ic_ram_addr_o),
          .ram_rdata_i(shared_ram_rdata_i),
          .ram_valid_o(ic_ram_valid_o),
          .ram_ready_i(shared_ram_ready_i)
      );

      dcache dcache_I (
          .clk   (clk),
          .resetn(resetn),
`ifdef USE_POWER_PINS
          .VDD   (VDD),
          .VSS   (VSS),
`endif
          .flush (iflush),

          .cpu_addr_i (cpu_addr_i),
          .cpu_wmask_i(cpu_wmask_i),
          .cpu_din_i  (cpu_din_i),
          .cpu_dout_o (dc_cpu_dout_o),
          .cpu_valid_i(cpu_valid_i & !is_instruction),
          .cpu_ready_o(dc_cpu_ready_o),

          .ram_addr_o (dc_ram_addr_o),
          .ram_wmask_o(dc_ram_wmask_o),
          .ram_wdata_o(dc_ram_wdata_o),
          .ram_rdata_i(shared_ram_rdata_i),
          .ram_valid_o(dc_ram_valid_o),
          .ram_ready_i(shared_ram_ready_i)
      );

      always @(*) begin

        cache_addr_o  = 32'b0;
        cache_din_o   = 32'b0;
        cache_wmask_o = 4'b0;
        cache_valid_o = 1'b0;

        cpu_dout_o    = 32'b0;
        cpu_ready_o   = 1'b0;

        if (is_instruction) begin

          cache_addr_o  = ic_ram_addr_o;
          cache_valid_o = ic_ram_valid_o;

          cpu_dout_o    = ic_cpu_dout_o;
          cpu_ready_o   = ic_cpu_ready_o;

        end else begin

          cache_addr_o  = dc_ram_addr_o;
          cache_din_o   = dc_ram_wdata_o;
          cache_wmask_o = dc_ram_wmask_o;
          cache_valid_o = dc_ram_valid_o;

          cpu_dout_o    = dc_cpu_dout_o;
          cpu_ready_o   = dc_cpu_ready_o;
        end
      end

    end
  endgenerate

endmodule
`default_nettype wire

