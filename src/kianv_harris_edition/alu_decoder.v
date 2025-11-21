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

module alu_decoder (
    input  wire                        imm_bit10,
    input  wire                        op_bit5,
    input  wire [                 2:0] funct3,
    input  wire                        funct7b5,
    input  wire [`ALU_OP_WIDTH   -1:0] ALUOp,
    input  wire [`AMO_OP_WIDTH   -1:0] AMOop,
    output reg  [`ALU_CTRL_WIDTH -1:0] ALUControl
);

  wire is_rtype_sub = op_bit5 & funct7b5;
  wire is_srl_srli = (op_bit5 && !funct7b5) || (!op_bit5 && !imm_bit10);

  always @(*) begin
    case (ALUOp)
      `ALU_OP_ADD:   ALUControl = `ALU_CTRL_ADD_ADDI;
      `ALU_OP_SUB:   ALUControl = `ALU_CTRL_SUB;
      `ALU_OP_AUIPC: ALUControl = `ALU_CTRL_AUIPC;
      `ALU_OP_LUI:   ALUControl = `ALU_CTRL_LUI;
      `ALU_OP_BRANCH: begin
        case (funct3)
          3'b000:  ALUControl = `ALU_CTRL_BEQ;
          3'b001:  ALUControl = `ALU_CTRL_BNE;
          3'b100:  ALUControl = `ALU_CTRL_BLT;
          3'b101:  ALUControl = `ALU_CTRL_BGE;
          3'b110:  ALUControl = `ALU_CTRL_BLTU;
          3'b111:  ALUControl = `ALU_CTRL_BGEU;
          default: ALUControl = 'hx;

        endcase
      end
      `ALU_OP_AMO: begin
        case (AMOop)
          `AMO_OP_ADD_W:  ALUControl = `ALU_CTRL_ADD_ADDI;
          `AMO_OP_SWAP_W: ALUControl = `ALU_CTRL_ADD_ADDI;
          `AMO_OP_LR_W:   ALUControl = `ALU_CTRL_ADD_ADDI;
          `AMO_OP_SC_W:   ALUControl = `ALU_CTRL_ADD_ADDI;
          `AMO_OP_XOR_W:  ALUControl = `ALU_CTRL_XOR_XORI;
          `AMO_OP_AND_W:  ALUControl = `ALU_CTRL_AND_ANDI;
          `AMO_OP_OR_W:   ALUControl = `ALU_CTRL_OR_ORI;
          `AMO_OP_MIN_W:  ALUControl = `ALU_CTRL_MIN;
          `AMO_OP_MAX_W:  ALUControl = `ALU_CTRL_MAX;
          `AMO_OP_MINU_W: ALUControl = `ALU_CTRL_MINU;
          `AMO_OP_MAXU_W: ALUControl = `ALU_CTRL_MAXU;

          default: ALUControl = 'hx;

        endcase
      end
      `ALU_OP_ARITH_LOGIC: begin
        case (funct3)
          3'b000:  ALUControl = is_rtype_sub ? `ALU_CTRL_SUB : `ALU_CTRL_ADD_ADDI;
          3'b100:  ALUControl = `ALU_CTRL_XOR_XORI;
          3'b110:  ALUControl = `ALU_CTRL_OR_ORI;
          3'b111:  ALUControl = `ALU_CTRL_AND_ANDI;
          3'b010:  ALUControl = `ALU_CTRL_SLT_SLTI;
          3'b001:  ALUControl = `ALU_CTRL_SLL_SLLI;
          3'b011:  ALUControl = `ALU_CTRL_SLTU_SLTIU;
          3'b101:  ALUControl = is_srl_srli ? `ALU_CTRL_SRL_SRLI : `ALU_CTRL_SRA_SRAI;
          default: ALUControl = 'hx;

        endcase
      end
      default:       ALUControl = 'hx;

    endcase
  end

endmodule
