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

module mux2 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH -1:0] d0,
    d1,
    input  wire              s,
    output wire [WIDTH -1:0] y
);

  assign y = s ? d1 : d0;
endmodule

module mux3 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH -1:0] d0,
    d1,
    d2,
    input  wire [       1:0] s,
    output wire [WIDTH -1:0] y
);

  assign y = s[1] ? d2 : (s[0] ? d1 : d0);
endmodule

module mux4 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH -1:0] d0,
    d1,
    d2,
    d3,
    input  wire [       1:0] s,
    output wire [WIDTH -1:0] y
);

  wire [WIDTH -1:0] low, high;

  mux2 lowmux (
      d0,
      d1,
      s[0],
      low
  );
  mux2 highmux (
      d2,
      d3,
      s[0],
      high
  );
  mux2 finalmux (
      low,
      high,
      s[1],
      y
  );
endmodule

module mux5 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH -1:0] d0,
    d1,
    d2,
    d3,
    d4,
    input  wire [       2:0] s,
    output wire [WIDTH -1:0] y

);

  assign y = (s == 0) ? d0 : (s == 1) ? d1 : (s == 2) ? d2 : (s == 3) ? d3 : d4;

endmodule

module mux6 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH -1:0] d0,
    d1,
    d2,
    d3,
    d4,
    d5,
    input  wire [       2:0] s,
    output wire [WIDTH -1:0] y

);

  assign y = (s == 0) ? d0 : (s == 1) ? d1 : (s == 2) ? d2 : (s == 3) ? d3 : (s == 4) ? d4 : d5;

endmodule

module dlatch_kianV #(
    parameter WIDTH = 32
) (
    input wire clk,
    input wire [WIDTH -1:0] d,
    output reg [WIDTH -1:0] q
);
  always @(posedge clk) q <= d;
endmodule

module dff_kianV #(
    parameter WIDTH  = 32,
    parameter PRESET = 0
) (
    input wire resetn,
    input wire clk,
    input wire en,
    input wire [WIDTH -1:0] d,
    output reg [WIDTH -1:0] q
);
  always @(posedge clk)
    if (!resetn) q <= PRESET;
    else if (en) q <= d;

endmodule

module counter #(
    parameter WIDTH = 64
) (
    input  wire             resetn,
    input  wire             clk,
    input  wire             incr,
    output reg  [WIDTH-1:0] count
);

  always @(posedge clk) begin
    if (!resetn) begin
      count <= {WIDTH{1'b0}};
    end else if (incr) begin
      count <= count + 1'b1;
    end
  end

endmodule

module async_reset_sync (
    input  wire clk,
    input  wire rst_n_async,
    output wire rst_n_sync
);
  (* async_reg = "true" *) reg [1:0] ff;

  always @(posedge clk or negedge rst_n_async) begin
    if (!rst_n_async) ff <= 2'b00;
    else ff <= {ff[0], 1'b1};
  end

  assign rst_n_sync = ff[1];
endmodule

module sync_2ff (
    input  wire clk,
    input  wire d_async,
    output wire q_sync
);
  (* async_reg = "true" *) reg [1:0] ff;

  always @(posedge clk) begin
    ff <= {ff[0], d_async};
  end

  assign q_sync = ff[1];

endmodule

