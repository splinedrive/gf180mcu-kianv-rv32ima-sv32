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
module plic (
    input wire clk,
    input wire resetn,
    input wire valid,
    input wire [23:0] addr,
    input wire [3:0] wmask,
    input wire [31:0] wdata,
    output reg [31:0] rdata,
    input wire [31:1] interrupt_request,
    output wire is_valid,
    output reg ready,
    output wire interrupt_request_ctx0,
    output wire interrupt_request_ctx1
);

  wire we = |wmask;
  wire is_pending_0_31 = (addr == 24'h00_1000);
  wire is_enable_ctx0_0_31 = (addr == 24'h00_2000);
  wire is_enable_ctx1_0_31 = (addr == 24'h00_2080);
  wire is_claim_complete_ctx0 = (addr == 24'h20_0004);
  wire is_claim_complete_ctx1 = (addr == 24'h20_1004);

  assign is_valid = !ready && valid;
  always @(posedge clk) begin
    if (!resetn) begin
      ready <= 1'b0;
    end else begin
      ready <= is_valid;
    end
  end

  integer i, j;
  reg [31:0] enable_ctx0_0_31;
  always @(posedge clk) begin
    if (!resetn) begin
      enable_ctx0_0_31 <= 0;
    end else if (valid && is_enable_ctx0_0_31) begin
      for (i = 0; i < 4; i = i + 1) begin
        if (wmask[i]) enable_ctx0_0_31[i*8+:8] <= wdata[i*8+:8];
      end
    end
  end

  reg [31:0] enable_ctx1_0_31;
  always @(posedge clk) begin
    if (!resetn) begin
      enable_ctx1_0_31 <= 0;
    end else if (valid && is_enable_ctx1_0_31) begin
      for (j = 0; j < 4; j = j + 1) begin
        if (wmask[j]) enable_ctx1_0_31[j*8+:8] <= wdata[j*8+:8];
      end
    end
  end

  wire [31:0] irq_in = {interrupt_request, 1'b0};

  reg  [31:0] pending_ctx0;
  always @(posedge clk) begin
    if (!resetn) begin
      pending_ctx0 <= 0;
    end else begin
      if (is_claim_complete_ctx0 && we && valid) begin
        pending_ctx0 <= pending_ctx0 & ~(1 << wdata[7:0]);
      end else begin
        pending_ctx0 <= pending_ctx0 | (irq_in & enable_ctx0_0_31);
      end
    end
  end

  reg [31:0] pending_ctx1;
  always @(posedge clk) begin
    if (!resetn) begin
      pending_ctx1 <= 0;
    end else begin
      if (is_claim_complete_ctx1 && we && valid) begin
        pending_ctx1 <= pending_ctx1 & ~(1 << wdata[7:0]);
      end else begin
        pending_ctx1 <= pending_ctx1 | (irq_in & enable_ctx1_0_31);
      end
    end
  end

  wire [31:0] claim_ctx0;
  Priority_Encoder #(
      .WORD_WIDTH(32)
  ) priority_encoder_i0 (
      .word_in       (pending_ctx0 & -pending_ctx0),
      .word_out      (claim_ctx0),
      .word_out_valid()
  );

  wire [31:0] claim_ctx1;
  Priority_Encoder #(
      .WORD_WIDTH(32)
  ) priority_encoder_i1 (
      .word_in       (pending_ctx1 & -pending_ctx1),
      .word_out      (claim_ctx1),
      .word_out_valid()
  );

  always @(*) begin
    case (1'b1)
      is_pending_0_31: rdata = pending_ctx0 | pending_ctx1;
      is_enable_ctx0_0_31: rdata = enable_ctx0_0_31;
      is_enable_ctx1_0_31: rdata = enable_ctx1_0_31;
      is_claim_complete_ctx0: rdata = claim_ctx0;
      is_claim_complete_ctx1: rdata = claim_ctx1;
      default: rdata = 0;
    endcase
  end

  assign interrupt_request_ctx0 = |pending_ctx0;
  assign interrupt_request_ctx1 = |pending_ctx1;

endmodule
