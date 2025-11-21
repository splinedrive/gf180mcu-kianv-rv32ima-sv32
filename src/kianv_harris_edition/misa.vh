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

`ifndef MISA_VH
`define MISA_VH

`define MISA_MXL_RV32 2'b01
`define MISA_EXTENSION_A 5'd0
`define MISA_EXTENSION_B 5'd1
`define MISA_EXTENSION_C 5'd2
`define MISA_EXTENSION_D 5'd3
`define MISA_EXTENSION_E 5'd4
`define MISA_EXTENSION_F 5'd5
`define MISA_EXTENSION_G 5'd6
`define MISA_EXTENSION_H 5'd7
`define MISA_EXTENSION_I 5'd8
`define MISA_EXTENSION_J 5'd9
`define MISA_EXTENSION_K 5'd10
`define MISA_EXTENSION_L 5'd11
`define MISA_EXTENSION_M 5'd12
`define MISA_EXTENSION_N 5'd13
`define MISA_EXTENSION_O 5'd14
`define MISA_EXTENSION_P 5'd15
`define MISA_EXTENSION_Q 5'd16
`define MISA_EXTENSION_R 5'd17
`define MISA_EXTENSION_S 5'd18
`define MISA_EXTENSION_T 5'd19
`define MISA_EXTENSION_U 5'd20
`define MISA_EXTENSION_V 5'd21
`define MISA_EXTENSION_W 5'd22
`define MISA_EXTENSION_X 5'd23
`define MISA_EXTENSION_Y 5'd24
`define MISA_EXTENSION_Z 5'd25

`define IS_EXTENSION_SUPPORTED(MXL, Extensions, Ext_To_Check) \
  ((MXL) == `MISA_MXL_RV32) && (((Extensions) >> (Ext_To_Check)) & 1'b1)
`define SET_MISA_VALUE(MXL) (MXL << 30)
`define MISA_EXTENSION_BIT(extension) (1 << extension)

`endif
