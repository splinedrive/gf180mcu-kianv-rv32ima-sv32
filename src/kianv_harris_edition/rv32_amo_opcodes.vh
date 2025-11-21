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

`define RV32_AMO_OPCODE 7'h2F
`define RV32_AMO_FUNCT3 3'h2
`define RV32_AMOADD_W 5'h00
`define RV32_AMOSWAP_W 5'h01
`define RV32_LR_W 5'h02
`define RV32_SC_W 5'h03
`define RV32_AMOXOR_W 5'h04
`define RV32_AMOAND_W 5'h0C
`define RV32_AMOOR_W 5'h08
`define RV32_AMOMIN_W 5'h10
`define RV32_AMOMAX_W 5'h14
`define RV32_AMOMINU_W 5'h18
`define RV32_AMOMAXU_W 5'h1c
`define RV32_SYSTEM_OPCODE 7'b1110011
`define RV32_SFENCE_VMA_FUNCT3 3'b000
`define RV32_SFENCE_VMA_FUNCT7 7'b0001001
`define RV32_SYSTEM_OPCODE 7'b1110011
`define RV32_FENCE_OPCODE 7'b0001111
`define RV32_FENCE_FUNCT3 3'b000
`define RV32_FENCE_I_FUNCT3 3'b001


/* verilog_format: off */
`define RV32_IS_AMO_INSTRUCTION(opcode, funct3) (opcode == `RV32_AMO_OPCODE && funct3 == `RV32_AMO_FUNCT3)
`define RV32_IS_AMOADD_W(funct5) (funct5 == `RV32_AMOADD_W)
`define RV32_IS_AMOSWAP_W(funct5) (funct5 == `RV32_AMOSWAP_W)
`define RV32_IS_LR_W(funct5) (funct5 == `RV32_LR_W)
`define RV32_IS_SC_W(funct5) (funct5 == `RV32_SC_W)
`define RV32_IS_AMOXOR_W(funct5) ( funct5 == `RV32_AMOXOR_W)
`define RV32_IS_AMOAND_W(funct5) ( funct5 == `RV32_AMOAND_W)
`define RV32_IS_AMOOR_W(funct5) ( funct5 == `RV32_AMOOR_W)
`define RV32_IS_AMOMIN_W(funct5) ( funct5 == `RV32_AMOMIN_W)
`define RV32_IS_AMOMAX_W(funct5) ( funct5 == `RV32_AMOMAX_W)
`define RV32_IS_AMOMINU_W(funct5) ( funct5 == `RV32_AMOMINU_W)
`define RV32_IS_AMOMAXU_W(funct5) ( funct5 == `RV32_AMOMAXU_W)
`define RV32_IS_SFENCE_VMA(opcode, funct3, funct7) ((opcode == `RV32_SYSTEM_OPCODE) && (funct3 == `RV32_SFENCE_VMA_FUNCT3) && (funct7 == `RV32_SFENCE_VMA_FUNCT7))
`define RV32_IS_FENCE(opcode, funct3) ((opcode == `RV32_FENCE_OPCODE) && (funct3 == `RV32_FENCE_FUNCT3))
`define RV32_IS_FENCE_I(opcode, funct3) ((opcode == `RV32_FENCE_OPCODE) && (funct3 == `RV32_FENCE_I_FUNCT3))
/* verilog_format: on */
