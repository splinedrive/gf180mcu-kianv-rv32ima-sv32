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

module csr_exception_handler (
    input  wire                      clk,
    input  wire                      resetn,
    input  wire [              15:0] sysclk_mhz_q8_8,
    input  wire                      incr_inst_retired,
    input  wire [              11:0] CSRAddr,
    input  wire [`CSR_OP_WIDTH -1:0] CSRop,
    input  wire                      we,
    input  wire                      re,
    input  wire [              31:0] Rd1,
    input  wire [               4:0] uimm,
    input  wire                      exception_event,
    input  wire                      mret,
    input  wire                      sret,
    input  wire                      wfi_event,
    input  wire [              31:0] cause,
    input  wire [              31:0] pc,
    input  wire [              31:0] badaddr,
    output wire [              31:0] rdata,
    output wire [              31:0] exception_next_pc,
    output wire                      exception_select,
    output wire [               1:0] privilege_mode,
    output wire                      csr_access_fault,
    output wire [              31:0] mstatus,
    output wire [              63:0] timer_counter,
    output wire [              31:0] satp,
    output wire                      tlb_flush,
    input  wire                      IRQ3,
    input  wire                      IRQ7,
    input  wire                      IRQ9,
    input  wire                      IRQ11,
    output wire                      IRQ_TO_CPU_CTRL1,
    output wire                      IRQ_TO_CPU_CTRL3,
    output wire                      IRQ_TO_CPU_CTRL5,
    output wire                      IRQ_TO_CPU_CTRL7,
    output wire                      IRQ_TO_CPU_CTRL9,
    output wire                      IRQ_TO_CPU_CTRL11
);

  wire [31:0] mie;
  wire [31:0] mip_current;
  wire [31:0] mideleg;
  wire [31:0] mip_next;
  wire [31:0] menvcfgh;
  wire [31:0] mcounteren;
  wire [31:0] stimecmp;
  wire [31:0] stimecmph;

  csr_unit #() csr_unit_inst (
      .clk                   (clk),
      .resetn                (resetn),
      .sysclk_mhz_q8_8       (sysclk_mhz_q8_8),
      .incr_inst_retired     (incr_inst_retired),
      .CSRAddr               (CSRAddr),
      .CSRop                 (CSRop),
      .we                    (we),
      .re                    (re),
      .Rd1                   (Rd1),
      .uimm                  (uimm),
      .exception_event       (exception_event),
      .mret                  (mret),
      .sret                  (sret),
      .wfi_event             (wfi_event),
      .cause                 (cause),
      .pc                    (pc),
      .badaddr               (badaddr),
      .rdata                 (rdata),
      .exception_next_pc     (exception_next_pc),
      .exception_select      (exception_select),
      .privilege_mode        (privilege_mode),
      .csr_access_fault      (csr_access_fault),
      .mstatus               (mstatus),
      .timer_counter         (timer_counter),
      .satp                  (satp),
      .tlb_flush             (tlb_flush),
      .mie                   (mie),
      .mip                   (mip_current),
      .mideleg               (mideleg),
      .menvcfgh              (menvcfgh),
      .mcounteren            (mcounteren),
      .stimecmp              (stimecmp),
      .stimecmph             (stimecmph),
      .mip_next_from_irq_ctrl(mip_next)
  );

  interrupt_controller interrupt_controller_inst (
      .clk              (clk),
      .resetn           (resetn),
      .IRQ3             (IRQ3),
      .IRQ7             (IRQ7),
      .IRQ9             (IRQ9),
      .IRQ11            (IRQ11),
      .mie              (mie),
      .mip_current      (mip_current),
      .mideleg          (mideleg),
      .mstatus          (mstatus),
      .privilege_mode   (privilege_mode),
      .timer_counter    (timer_counter),
      .stimecmp         (stimecmp),
      .stimecmph        (stimecmph),
      .menvcfgh         (menvcfgh),
      .mcounteren       (mcounteren),
      .mip_next         (mip_next),
      .IRQ_TO_CPU_CTRL1 (IRQ_TO_CPU_CTRL1),
      .IRQ_TO_CPU_CTRL3 (IRQ_TO_CPU_CTRL3),
      .IRQ_TO_CPU_CTRL5 (IRQ_TO_CPU_CTRL5),
      .IRQ_TO_CPU_CTRL7 (IRQ_TO_CPU_CTRL7),
      .IRQ_TO_CPU_CTRL9 (IRQ_TO_CPU_CTRL9),
      .IRQ_TO_CPU_CTRL11(IRQ_TO_CPU_CTRL11)
  );

endmodule
