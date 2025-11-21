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

module sv32_translate_data_to_physical (
    input  wire        clk,
    input  wire        resetn,
    input  wire [31:0] address,
    input  wire        satp_sv32_mode,
    output reg  [33:0] physical_address,
    input  wire        is_write,
    output reg         page_fault,
    input  wire [ 1:0] privilege_mode,
    input  wire [31:0] mstatus,

    input  wire valid,
    output reg  ready,

    output reg         walk_valid,
    input  wire        walk_ready,
    input  wire [31:0] pte_
);

  localparam S0 = 0, S1 = 1, S_LAST = 2;
  localparam STATE_WIDTH = $clog2(S_LAST);
  reg [STATE_WIDTH-1:0] state, next_state;

  always @(posedge clk) state <= !resetn ? S0 : next_state;

  always @* begin
    next_state = state;
    case (state)
      S0: next_state = S0;
      S1: next_state = S0;
      default: next_state = S0;
    endcase
  end

  reg        page_fault_nxt;
  reg        ready_nxt;
  reg [33:0] physical_address_nxt;

  reg [ 1:0] priv_eff;
  reg [31:0] pte_eff;
  reg [11:0] page_offset;
  reg [33:0] pagebase_addr;
  reg        mmu_enabled;

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

    priv_eff             = privilege_mode;
    pte_eff              = 32'd0;
    page_offset          = 12'd0;
    pagebase_addr        = 34'd0;
    mmu_enabled          = 1'b0;

    case (state)
      S0: begin

        if (`GET_MSTATUS_MPRV(mstatus)) begin
          priv_eff = `GET_MSTATUS_MPP(mstatus);
        end

        mmu_enabled = satp_sv32_mode && !`IS_MACHINE(priv_eff);

        if (valid && !ready) begin
          if (!mmu_enabled) begin

            physical_address_nxt = {2'b00, address};
            ready_nxt            = 1'b1;
          end else begin

            walk_valid = 1'b1;

            if (walk_ready) begin

              pte_eff = pte_ | ((
              `GET_MSTATUS_MXR(mstatus)
              &&
              `GET_PTE_X(pte_)
              ) ? `PTE_R_MASK : 32'h0);

              if ((!`GET_PTE_R(pte_eff) && `GET_PTE_W(pte_eff))) begin
                page_fault_nxt = 1'b1;
              end else if (`IS_SUPERVISOR(priv_eff)) begin

                if (`GET_PTE_U(pte_eff) && !`GET_XSTATUS_SUM(mstatus)) begin
                  page_fault_nxt = 1'b1;
                end else begin

                  if (is_write) begin
                    if (!`GET_PTE_W(pte_eff)) page_fault_nxt = 1'b1;
                  end else begin
                    if (!`GET_PTE_R(pte_eff)) page_fault_nxt = 1'b1;
                  end
                end
              end else begin

                if (is_write) begin
                  if (!(`GET_PTE_U(pte_eff) && `GET_PTE_W(pte_eff))) page_fault_nxt = 1'b1;
                end else begin
                  if (!(`GET_PTE_U(pte_eff) && `GET_PTE_R(pte_eff))) page_fault_nxt = 1'b1;
                end
              end

              page_offset = address & (`SV32_PAGE_SIZE - 1);
              pagebase_addr        = ( (pte_eff >> `SV32_PTE_ALIGNED_PPN_SHIFT)
                                      << `SV32_PTE_ALIGNED_PPN_SHIFT );
              physical_address_nxt = (pagebase_addr | page_offset);

              ready_nxt = 1'b1;
            end
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
