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

/* verilog_format: off */
`ifndef RISCV_PRIV_CSR_STATUS_VH
`define RISCV_PRIV_CSR_STATUS_VH
// RISC-V privilege levels
// M       -> Simple embedded systems
// M, U    -> Secure embedded systems
// M, S, U -> System running Unix-like operating systems
// RISC-V privilege levels
`define PRIVILEGE_MODE_USER 0
`define PRIVILEGE_MODE_SUPERVISOR 1
`define PRIVILEGE_MODE_RESERVED 2
`define PRIVILEGE_MODE_MACHINE 3
`define IS_USER(privilege) (privilege == `PRIVILEGE_MODE_USER)
`define IS_SUPERVISOR(privilege) (privilege == `PRIVILEGE_MODE_SUPERVISOR)
`define IS_MACHINE(privilege) (privilege == `PRIVILEGE_MODE_MACHINE)


`define MIE_MEIE_BIT       11
`define MIE_MSIE_BIT       3
`define MIE_MTIE_BIT       7
`define XIE_SEIE_BIT       9
`define XIE_SSIE_BIT       1
`define XIE_STIE_BIT       5

`define MIP_MEIP_BIT       11
`define MIP_MSIP_BIT       3
`define MIP_MTIP_BIT       7
`define XIP_SEIP_BIT       9
`define XIP_SSIP_BIT       1
`define XIP_STIP_BIT       5

`define MIE_MEIE_MASK      (1<< `MIE_MEIE_BIT)
`define MIE_MSIE_MASK      (1<< `MIE_MSIE_BIT)
`define MIE_MTIE_MASK      (1<< `MIE_MTIE_BIT)
`define XIE_SEIE_MASK      (1<< `XIE_SEIE_BIT)
`define XIE_SSIE_MASK      (1<< `XIE_SSIE_BIT)
`define XIE_STIE_MASK      (1<< `XIE_STIE_BIT)

`define MIP_MEIP_MASK      (1<< `MIP_MEIP_BIT)
`define MIP_MSIP_MASK      (1<< `MIP_MSIP_BIT)
`define MIP_MTIP_MASK      (1<< `MIP_MTIP_BIT)
`define XIP_SEIP_MASK      (1<< `XIP_SEIP_BIT)
`define XIP_SSIP_MASK      (1<< `XIP_SSIP_BIT)
`define XIP_STIP_MASK      (1<< `XIP_STIP_BIT)

`define XSTATUS_SIE_BIT 1
`define XSTATUS_SIE_MASK (1 << `XSTATUS_SIE_BIT)

`define MSTATUS_MPP_BIT 11
`define MSTATUS_MPP_WIDTH 2
`define MSTATUS_MPIE_BIT 7
`define MSTATUS_MIE_BIT 3
`define MSTATUS_MPRV_BIT 17
`define MSTATUS_TVM_BIT 20
`define MSTATUS_TW_BIT 21
`define MSTATUS_TSR_BIT 22

`define XSTATUS_SPIE_BIT 5
`define XSTATUS_SPIE_MASK (1 << `XSTATUS_SPIE_BIT)


`define XSTATUS_SPP_BIT 8
`define XSTATUS_SPP_MASK (1 << `XSTATUS_SPP_BIT)

`define XSTATUS_MXR 19
`define XSTATUS_SUM_POS 18

`define MSTATUS_MIE_MASK (1 << `MSTATUS_MIE_BIT)
`define MSTATUS_MPIE_MASK (1 << `MSTATUS_MPIE_BIT)
`define MSTATUS_MPP_MASK (((1 << `MSTATUS_MPP_WIDTH) - 1) << `MSTATUS_MPP_BIT)
`define MSTATUS_MPRV_MASK (1 << `MSTATUS_MPRV_BIT)
`define MSTATUS_TVM_MASK (1 << `MSTATUS_TVM_BIT)

`define SSTATUS_SIE_BIT   (1 << 1)
`define SSTATUS_SPIE_BIT  (1 << 5)
`define SSTATUS_UBE_BIT   (1 << 6)
`define SSTATUS_SPP_BIT   (1 << 8)
`define SSTATUS_VS_BIT    (3 << 9)
`define SSTATUS_FS_BIT    (3 << 13)
`define SSTATUS_XS_BIT    (3 << 15)
`define SSTATUS_SUM_BIT   (1 << 18)
`define SSTATUS_MXR_BIT   (1 << 19)
`define SSTATUS_SD_BIT    (1 << 31)

`define SSTATUS_MASK (`SSTATUS_SIE_BIT | `SSTATUS_SPIE_BIT | `SSTATUS_UBE_BIT | \
                      `SSTATUS_SPP_BIT | `SSTATUS_VS_BIT | `SSTATUS_FS_BIT | `SSTATUS_XS_BIT | `SSTATUS_SUM_BIT | \
                      `SSTATUS_MXR_BIT | `SSTATUS_SD_BIT)


// Define individual bits for MEDELEG
`define MEDELEG_INST_ADDR_MISALIGNED  'h0001  // Bit 0
`define MEDELEG_INST_ACCESS_FAULT     'h0002  // Bit 1
`define MEDELEG_ILLEGAL_INST          'h0004  // Bit 2
`define MEDELEG_BREAKPOINT            'h0008  // Bit 3
`define MEDELEG_LOAD_ADDR_MISALIGNED  'h0010  // Bit 4
`define MEDELEG_LOAD_ACCESS_FAULT     'h0020  // Bit 5
`define MEDELEG_STORE_ADDR_MISALIGNED 'h0040  // Bit 6
`define MEDELEG_STORE_ACCESS_FAULT    'h0080  // Bit 7
`define MEDELEG_ECALL_U               'h0100  // Bit 8
`define MEDELEG_ECALL_S               'h0200  // Bit 9
`define MEDELEG_INSTR_PAGE_FAULT      'h1000  // Bit 12
`define MEDELEG_LOAD_PAGE_FAULT       'h2000  // Bit 13
`define MEDELEG_STORE_PAGE_FAULT      'h8000  // Bit 15

// Reserved and non-delegatable bits
`define MEDELEG_ECALL_M               'h0800  // Bit 11 (non-delegatable)

// Combine all writable bits into a mask
`define MEDELEG_MASK (`MEDELEG_INST_ADDR_MISALIGNED | `MEDELEG_INST_ACCESS_FAULT | \
                      `MEDELEG_ILLEGAL_INST | `MEDELEG_BREAKPOINT | \
                      `MEDELEG_LOAD_ADDR_MISALIGNED | `MEDELEG_LOAD_ACCESS_FAULT | \
                      `MEDELEG_STORE_ADDR_MISALIGNED | `MEDELEG_STORE_ACCESS_FAULT | \
                      `MEDELEG_ECALL_U | `MEDELEG_ECALL_S | \
                      `MEDELEG_INSTR_PAGE_FAULT | `MEDELEG_LOAD_PAGE_FAULT | \
                      `MEDELEG_STORE_PAGE_FAULT)

  // Define individual bits for MIDELEG
`define MIDELEG_SUPERVISOR_SOFT_INTR   'h002  // Bit 1
`define MIDELEG_SUPERVISOR_TIMER_INTR  'h020  // Bit 5
`define MIDELEG_SUPERVISOR_EXT_INTR    'h200  // Bit 9

// Reserved and non-delegatable bits
`define MIDELEG_MACHINE_SOFT_INTR      'h008  // Bit 3 (non-delegatable)
`define MIDELEG_MACHINE_TIMER_INTR     'h080  // Bit 7 (non-delegatable)
`define MIDELEG_MACHINE_EXT_INTR       'h800  // Bit 11 (non-delegatable)

// Combine all writable bits into a mask
`define MIDELEG_MASK (`MIDELEG_SUPERVISOR_SOFT_INTR | `MIDELEG_SUPERVISOR_TIMER_INTR | \
                      `MIDELEG_SUPERVISOR_EXT_INTR)

`define SIP_MASK (`XIP_SSIP_MASK | `XIP_SEIP_MASK | `XIP_STIP_MASK)
`define SIE_MASK (`XIE_SSIE_MASK | `XIE_SEIE_MASK | `XIE_STIE_MASK)

`define GET_MIE_MSIE(value) ((value >> `MIE_MSIE_BIT) & 1'b1)
`define GET_MIE_MTIE(value) ((value >> `MIE_MTIE_BIT) & 1'b1)
`define GET_MIP_MEIP(value)  (((value) >> `MIP_MEIP_BIT) & 1'b1)
`define GET_MIP_MSIP(value)  (((value) >> `MIP_MSIP_BIT) & 1'b1)
`define GET_MIP_MTIP(value)  (((value) >> `MIP_MTIP_BIT) & 1'b1)
`define GET_XIP_SEIP(value)  (((value) >> `XIP_SEIP_BIT) & 1'b1)
`define GET_XIP_SSIP(value)  (((value) >> `XIP_SSIP_BIT) & 1'b1)
`define GET_XIP_STIP(value)  (((value) >> `XIP_STIP_BIT) & 1'b1)

`define SET_MIP_MEIP(value)  ((value) << `MIP_MEIP_BIT)
`define SET_MIP_MSIP(value)  ((value) << `MIP_MSIP_BIT)
`define SET_MIP_MTIP(value)  ((value) << `MIP_MTIP_BIT)
`define SET_XIP_SEIP(value)  ((value) << `XIP_SEIP_BIT)
`define SET_XIP_SSIP(value)  ((value) << `XIP_SSIP_BIT)
`define SET_XIP_STIP(value)  ((value) << `XIP_STIP_BIT)


`define GET_MSTATUS_MIE(value) (((value) >> `MSTATUS_MIE_BIT) & 1'b1)
`define GET_MSTATUS_MPIE(value) (((value) >> `MSTATUS_MPIE_BIT) & 1'b1)
`define GET_MSTATUS_MPP(value) (((value) >> `MSTATUS_MPP_BIT) & 2'b11)
`define GET_MSTATUS_MPRV(value) ((value) >> `MSTATUS_MPRV_BIT) & 1'b1
`define GET_MSTATUS_MXR(value) (((value) >> `XSTATUS_MXR) & 1'b1)
`define GET_MSTATUS_TW(value) (((value) >> `MSTATUS_TW_BIT) & 1'b1)
`define GET_MSTATUS_TSR(value) (((value) >> `MSTATUS_TSR_BIT) & 1'b1)
`define GET_MSTATUS_TVM(value) (((value) >> `MSTATUS_TVM_BIT) & 1'b1)
`define GET_XSTATUS_SIE(value) (((value) >> `XSTATUS_SIE_BIT) & 1'b1)
`define GET_XSTATUS_SPIE(value) (((value) >> `XSTATUS_SPIE_BIT) & 1'b1)
`define GET_XSTATUS_SPP(value) (((value) >> `XSTATUS_SPP_BIT) & 1'b1)
`define GET_XSTATUS_SUM(value) (((value) >> `XSTATUS_SUM_POS) & 1'b1)

`define SET_MSTATUS_MIE(value) ((value) << `MSTATUS_MIE_BIT)
`define SET_MSTATUS_MPIE(value) ((value) << `MSTATUS_MPIE_BIT)
`define SET_MSTATUS_MPP(new_privilege_mode) (((new_privilege_mode) & 2'b11) << `MSTATUS_MPP_BIT)
`define SET_MSTATUS_MPRV(mstatus, mprv_value) ((mstatus) & ~`MSTATUS_MPRV_MASK) | (((mprv_value) & 1'b1) << `MSTATUS_MPRV_BIT)
`define SET_MSTATUS_MXR(mstatus, value) ((mstatus) = ((mstatus) & ~`XSTATUS_MXR_MASK) | ((value << 19) & `XSTATUS_MXR_MASK))
`define SET_XSTATUS_SIE(value)  ((value) << `XSTATUS_SIE_BIT)
`define SET_XSTATUS_SPIE(value) ((value) << `XSTATUS_SPIE_BIT)
`define SET_XSTATUS_SPP(value)  ((value) << `XSTATUS_SPP_BIT)

`define GET_MENVCFGH_STCE(menvcfgh) ((menvcfgh >> 31) & 1)
`define GET_MCOUNTEREN_TM(mcounteren) ((mcounteren >> 1) & 1)

`define CHECK_SSTC_CONDITIONS(menvcfgh, mcounteren) \
    (`GET_MENVCFGH_STCE(menvcfgh) && `GET_MCOUNTEREN_TM(mcounteren))

`define CHECK_SSTC_TM_AND_CMP(timer_counter, stimecmph, stimecmp, menvcfgh, mcounteren) \
    (timer_counter >= {stimecmph, stimecmp} && \
    `CHECK_SSTC_CONDITIONS(menvcfgh, mcounteren))


`define IS_EBREAK(opcode, funct3, funct7, rs1, rs2, rd) ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h00100073)
`define IS_ECALL(opcode, funct3, funct7, rs1, rs2, rd) ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h00000073)
`define IS_MRET(opcode, funct3, funct7, rs1, rs2, rd) ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h30200073)
`define IS_SRET(opcode, funct3, funct7, rs1, rs2, rd) ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h10200073)
`define IS_WFI(opcode, funct3, funct7, rs1, rs2, rd) ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h10500073)

`include "mcause.vh"

`endif
/* verilog_format: on */
