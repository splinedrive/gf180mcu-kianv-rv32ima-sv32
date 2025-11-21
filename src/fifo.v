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
module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
) (
    input wire clk,
    input wire resetn,

    input  wire [DATA_WIDTH-1:0] din,
    output wire [DATA_WIDTH-1:0] dout,

    input wire push,
    input wire pop,

    output wire full,
    output wire empty
);

  reg [DATA_WIDTH-1:0] ram[0:DEPTH-1];

  localparam AW = $clog2(DEPTH);
  reg [AW:0] cnt;
  reg [AW-1:0] rd_ptr, wr_ptr;
  reg [AW:0] cnt_next;
  reg [AW-1:0] rd_ptr_next, wr_ptr_next;

  assign empty = (cnt == 0);
  assign full  = (cnt == DEPTH);

  wire wr_accept = push && (!full || pop);
  wire rd_accept = pop && (!empty);

  always @* begin
    rd_ptr_next = rd_ptr;
    wr_ptr_next = wr_ptr;
    cnt_next    = cnt;

    if (wr_accept) begin
      wr_ptr_next = wr_ptr + 1'b1;
    end
    if (rd_accept) begin
      rd_ptr_next = rd_ptr + 1'b1;
    end

    case ({
      push, pop
    })
      2'b00: cnt_next = cnt;
      2'b01: if (!empty) cnt_next = cnt - 1'b1;
      2'b10: if (!full) cnt_next = cnt + 1'b1;
      2'b11: cnt_next = cnt;
    endcase
  end

  always @(posedge clk) begin
    if (!resetn) begin
      rd_ptr <= 0;
      wr_ptr <= 0;
      cnt    <= 0;
    end else begin
      rd_ptr <= rd_ptr_next;
      wr_ptr <= wr_ptr_next;
      cnt    <= cnt_next;
    end
  end

  always @(posedge clk) begin
    if (wr_accept) ram[wr_ptr] <= din;
  end

  assign dout = ram[rd_ptr];

endmodule

