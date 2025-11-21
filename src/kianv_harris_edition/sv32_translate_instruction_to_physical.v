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

module sv32_translate_instruction_to_physical (
    input  wire        clk,
    input  wire        resetn,
    input  wire [31:0] address,
    input  wire        satp_sv32_mode,
    output reg  [33:0] physical_address,
    output reg         page_fault,
    input  wire [ 1:0] privilege_mode,

    input  wire valid,
    output reg  ready,

    output reg  walk_valid,
    input  wire walk_ready,

    input wire [31:0] pte
);

  localparam S0 = 0, S1 = 1, S_LAST = 2;
  localparam STATE_WIDTH = $clog2(S_LAST);
  reg [STATE_WIDTH-1:0] state, next_state;

  wire mmu_enabled = satp_sv32_mode && !`IS_MACHINE(privilege_mode);

  always @(posedge clk) state <= !resetn ? S0 : next_state;

  always @* begin
    next_state = state;
    case (state)
      S0: next_state = S0;
      S1: next_state = S0;
      default: next_state = S0;
    endcase
  end

  reg         page_fault_nxt;
  reg         ready_nxt;
  reg  [33:0] physical_address_nxt;

  reg  [ 1:0] priv;
  reg  [11:0] page_offset;
  reg  [33:0] pagebase_addr;

  wire        req_fire = valid && !ready;

  always @(posedge clk) begin
    if (!resetn) begin
      page_fault       <= 1'b0;
      physical_address <= 34'd0;
      ready            <= 1'b0;
    end else begin
      page_fault       <= page_fault_nxt;
      physical_address <= physical_address_nxt;
      ready            <= ready_nxt;
    end
  end

  always @* begin

    physical_address_nxt = physical_address;
    page_fault_nxt       = 1'b0;
    ready_nxt            = 1'b0;

    walk_valid           = 1'b0;
    priv                 = privilege_mode;
    page_offset          = 12'd0;
    pagebase_addr        = 34'd0;

    case (state)
      S0: begin
        if (req_fire) begin
          if (mmu_enabled) begin

            walk_valid = 1'b1;

            if (walk_ready) begin

              if ((!
                  `GET_PTE_X(pte)
                  &&
                  `GET_PTE_W(pte)
                  && !
                  `GET_PTE_R(pte)
                  ) || (
                  `GET_PTE_X(pte)
                  &&
                  `GET_PTE_W(pte)
                  && !
                  `GET_PTE_R(pte)
                  )) begin
                page_fault_nxt = 1'b1;
              end else if (`IS_SUPERVISOR(priv)) begin
                if (`GET_PTE_U(pte)) begin
                  page_fault_nxt = 1'b1;
                end else if (!`GET_PTE_X(pte)) begin
                  page_fault_nxt = 1'b1;
                end
              end else begin
                if (!(`GET_PTE_X(pte) && `GET_PTE_U(pte))) begin
                  page_fault_nxt = 1'b1;
                end
              end

              page_offset = address & (`SV32_PAGE_SIZE - 1);
              pagebase_addr = ((pte >> `SV32_PTE_ALIGNED_PPN_SHIFT) << `SV32_PTE_ALIGNED_PPN_SHIFT);
              physical_address_nxt = pagebase_addr | page_offset;

              ready_nxt = 1'b1;
            end
          end else begin

            physical_address_nxt = {2'b00, address};
            ready_nxt            = 1'b1;
          end
        end
      end

      S1: begin

      end

      default: ;
    endcase

  end
endmodule

`default_nettype wire

