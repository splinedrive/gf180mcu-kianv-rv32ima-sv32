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

`ifndef MCAUSE_VH
`define MCAUSE_VH
// Exception codes
`define EXC_INSTR_ADDR_MISALIGNED 32'h00000000
`define EXC_INSTR_ACCESS_FAULT 32'h00000001
`define EXC_ILLEGAL_INSTRUCTION 32'h00000002
`define EXC_BREAKPOINT 32'h00000003
`define EXC_LOAD_AMO_ADDR_MISALIGNED 32'h00000004
`define EXC_LOAD_AMO_ACCESS_FAULT 32'h00000005
`define EXC_STORE_AMO_ADDR_MISALIGNED 32'h00000006
`define EXC_STORE_AMO_ACCESS_FAULT 32'h00000007
`define EXC_ECALL_FROM_UMODE 32'h00000008
`define EXC_ECALL_FROM_SMODE 32'h00000009
`define EXC_ECALL_FROM_MMODE 32'h0000000B
`define EXC_INSTR_PAGE_FAULT 32'h0000000C
`define EXC_LOAD_PAGE_FAULT 32'h0000000D
`define EXC_STORE_AMO_PAGE_FAULT 32'h0000000F

// Interrupt codes
`define INTERRUPT_USER_SOFTWARE 32'h80000000
`define INTERRUPT_SUPERVISOR_SOFTWARE 32'h80000001
`define INTERRUPT_MACHINE_SOFTWARE 32'h80000003
`define INTERRUPT_USER_TIMER 32'h80000004
`define INTERRUPT_SUPERVISOR_TIMER 32'h80000005
`define INTERRUPT_MACHINE_TIMER 32'h80000007
`define INTERRUPT_USER_EXTERNAL 32'h80000008
`define INTERRUPT_SUPERVISOR_EXTERNAL 32'h80000009
`define INTERRUPT_MACHINE_EXTERNAL 32'h8000000B

`define MCAUSE_CAUSE_MASK 32'h7FFFFFFF
`define GET_MCAUSE_CAUSE(mcause) ((mcause) & `MCAUSE_CAUSE_MASK)

`define MCAUSE_INTERRUPT_MASK 32'h80000000
`define IS_MCAUSE_INTERRUPT(mcause) (((mcause) & `MCAUSE_INTERRUPT_MASK) >> 31)



`endif
