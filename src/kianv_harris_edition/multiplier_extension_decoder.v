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
module multiplier_extension_decoder (
    input  wire [               2:0] funct3,
    output wire [`MUL_OP_WIDTH -1:0] MULop,
    output wire [`DIV_OP_WIDTH -1:0] DIVop,
    input  wire                      mul_ext_valid,
    output wire                      mul_valid,
    output wire                      div_valid
);

  multiplier_decoder multiplier_I (
      funct3,
      MULop,
      mul_ext_valid,
      mul_valid
  );
  divider_decoder divider_decoder_I (
      funct3,
      DIVop,
      mul_ext_valid,
      div_valid
  );

endmodule
