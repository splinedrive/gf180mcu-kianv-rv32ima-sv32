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

module interrupt_controller (
    input wire clk,
    input wire resetn,

    input wire IRQ3,
    input wire IRQ7,
    input wire IRQ9,
    input wire IRQ11,

    input wire [31:0] mie,
    input wire [31:0] mip_current,
    input wire [31:0] mideleg,
    input wire [31:0] mstatus,
    input wire [ 1:0] privilege_mode,
    input wire [63:0] timer_counter,
    input wire [31:0] stimecmp,
    input wire [31:0] stimecmph,
    input wire [31:0] menvcfgh,
    input wire [31:0] mcounteren,

    output reg [31:0] mip_next,

    output reg IRQ_TO_CPU_CTRL1,
    output reg IRQ_TO_CPU_CTRL3,
    output reg IRQ_TO_CPU_CTRL5,
    output reg IRQ_TO_CPU_CTRL7,
    output reg IRQ_TO_CPU_CTRL9,
    output reg IRQ_TO_CPU_CTRL11
);

  reg [31:0] temp_mip;
  reg [31:0] pending_irqs;
  reg        m_enabled;
  reg        s_enabled;
  reg [31:0] m_interrupts;
  reg [31:0] s_interrupts;
  reg [31:0] interrupts;

  reg [31:0] mip_next_comb;
  reg        IRQ_TO_CPU_CTRL1_comb;
  reg        IRQ_TO_CPU_CTRL3_comb;
  reg        IRQ_TO_CPU_CTRL5_comb;
  reg        IRQ_TO_CPU_CTRL7_comb;
  reg        IRQ_TO_CPU_CTRL9_comb;
  reg        IRQ_TO_CPU_CTRL11_comb;

  always @(*) begin

    temp_mip = mip_current & ~(`MIP_MTIP_MASK | `MIP_MEIP_MASK | `XIP_SEIP_MASK | (
    `CHECK_SSTC_CONDITIONS(menvcfgh, mcounteren)
    << `XIP_STIP_BIT));

    mip_next_comb = temp_mip |
    `SET_MIP_MSIP(IRQ3)
    |
    `SET_XIP_STIP(`CHECK_SSTC_TM_AND_CMP(timer_counter, stimecmph, stimecmp, menvcfgh, mcounteren))
    |
    `SET_MIP_MTIP(IRQ7)
    |
    `SET_MIP_MEIP(IRQ11)
    |
    `SET_XIP_SEIP(IRQ9);

    pending_irqs = mip_next_comb & mie;

    m_enabled = (!
    `IS_MACHINE(privilege_mode)
    ) || (
    `IS_MACHINE(privilege_mode)
    &&
    `GET_MSTATUS_MIE(mstatus)
    );

    s_enabled =
    `IS_USER(privilege_mode)
    || (
    `IS_SUPERVISOR(privilege_mode)
    &&
    `GET_XSTATUS_SIE(mstatus)
    );

    m_interrupts = pending_irqs & (~mideleg) & ({32{m_enabled}});

    s_interrupts = pending_irqs & (mideleg) & ({32{s_enabled}});

    interrupts = (|m_interrupts) ? m_interrupts : s_interrupts;

    IRQ_TO_CPU_CTRL1_comb = `GET_XIP_SSIP(interrupts);
    IRQ_TO_CPU_CTRL3_comb = `GET_MIP_MSIP(interrupts);
    IRQ_TO_CPU_CTRL5_comb = `GET_XIP_STIP(interrupts);
    IRQ_TO_CPU_CTRL7_comb = `GET_MIP_MTIP(interrupts);
    IRQ_TO_CPU_CTRL9_comb = `GET_XIP_SEIP(interrupts);
    IRQ_TO_CPU_CTRL11_comb = `GET_MIP_MEIP(interrupts);

  end

  always @(posedge clk) begin
    if (!resetn) begin
      mip_next          <= 32'b0;
      IRQ_TO_CPU_CTRL1  <= 1'b0;
      IRQ_TO_CPU_CTRL3  <= 1'b0;
      IRQ_TO_CPU_CTRL5  <= 1'b0;
      IRQ_TO_CPU_CTRL7  <= 1'b0;
      IRQ_TO_CPU_CTRL9  <= 1'b0;
      IRQ_TO_CPU_CTRL11 <= 1'b0;
    end else begin
      mip_next          <= mip_next_comb;
      IRQ_TO_CPU_CTRL1  <= IRQ_TO_CPU_CTRL1_comb;
      IRQ_TO_CPU_CTRL3  <= IRQ_TO_CPU_CTRL3_comb;
      IRQ_TO_CPU_CTRL5  <= IRQ_TO_CPU_CTRL5_comb;
      IRQ_TO_CPU_CTRL7  <= IRQ_TO_CPU_CTRL7_comb;
      IRQ_TO_CPU_CTRL9  <= IRQ_TO_CPU_CTRL9_comb;
      IRQ_TO_CPU_CTRL11 <= IRQ_TO_CPU_CTRL11_comb;
    end
  end

endmodule
