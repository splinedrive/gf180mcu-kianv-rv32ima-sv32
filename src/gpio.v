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
module gpio (
    input  wire        clk,
    input  wire        resetn,
    input  wire [ 3:0] addr,
    input  wire [ 3:0] wrstb,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    input  wire        valid,
    output reg         ready,

    input  wire in,
    output wire out,
    output wire oe
);

  reg out_en;
  reg out_val;

  assign out = out_val;
  assign oe  = out_en;

  wire wr = |wrstb;

  always @(posedge clk) ready <= !resetn ? 1'b0 : valid;

  always @(posedge clk) begin
    if (!resetn) begin
      out_en  <= 1'b0;
      out_val <= 1'b0;
      rdata   <= 32'b0;
    end else if (valid) begin
      case (addr)
        4'h0: begin
          if (wr) out_en <= wdata[9];
          else rdata <= {31'b0, out_en};
        end

        4'h4: begin
          if (wr) out_val <= wdata[9];
          else rdata <= {31'b0, out_val};
        end

        4'h8: begin
          if (!wr) rdata <= {31'b0, in};
        end

        default: rdata <= 32'b0;
      endcase
    end
  end

endmodule

