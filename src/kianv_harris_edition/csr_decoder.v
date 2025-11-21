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
module csr_decoder (
    input wire [2:0] funct3,
    input wire [4:0] Rs1Uimm,
    input wire [4:0] Rd,
    input wire valid,
    output wire CSRwe,
    output wire CSRre,
    output reg [`CSR_OP_WIDTH -1:0] CSRop
);

  wire is_csrrw = funct3 == 3'b001;
  wire is_csrrs = funct3 == 3'b010;
  wire is_csrrc = funct3 == 3'b011;

  wire is_csrrwi = funct3 == 3'b101;
  wire is_csrrsi = funct3 == 3'b110;
  wire is_csrrci = funct3 == 3'b111;

  reg  we;
  reg  re;

  assign CSRwe = we && valid;
  assign CSRre = re && valid;

  always @(*) begin
    we = 1'b0;
    re = 1'b0;
    case (1'b1)

      is_csrrw: begin
        we = 1'b1;

        re = |Rd;
        CSRop = `CSR_OP_CSRRW;
      end

      is_csrrs: begin
        we = |Rs1Uimm;
        re = 1'b1;
        CSRop = `CSR_OP_CSRRS;
      end

      is_csrrc: begin
        we = |Rs1Uimm;
        re = 1'b1;
        CSRop = `CSR_OP_CSRRC;
      end

      is_csrrwi: begin
        we = 1'b1;

        re = |Rd;
        CSRop = `CSR_OP_CSRRWI;
      end

      is_csrrsi: begin
        we = |Rs1Uimm;
        re = 1'b1;
        CSRop = `CSR_OP_CSRRSI;
      end

      is_csrrci: begin
        we = |Rs1Uimm;
        re = 1'b1;
        CSRop = `CSR_OP_CSRRCI;
      end

      default: begin
        we = 1'b0;
        re = 1'b0;
        CSRop = `CSR_OP_NA;
      end
    endcase
  end

endmodule

