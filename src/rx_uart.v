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

module rx_uart #(
    parameter DATA_BITS  = 8,
    parameter FIFO_DEPTH = 16
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        rx_in,
    input  wire        data_rd,
    input  wire [15:0] div,
    output reg         error,
    output wire [31:0] data
);

  localparam [2:0] ST_IDLE = 3'd0, ST_VERIFY = 3'd1, ST_DATA = 3'd2, ST_STOP = 3'd3, ST_WAIT = 3'd4;

  reg [2:0] state, return_state;
  reg  [          2:0] bit_idx;
  reg  [DATA_BITS-1:0] rx_data;
  reg                  ready;

  reg  [         16:0] wait_states;
  reg  [          2:0] rx_in_sync;
  wire                 rx_sample = rx_in_sync[2];

  always @(posedge clk) begin
    if (!resetn) rx_in_sync <= 3'b111;
    else rx_in_sync <= {rx_in_sync[1:0], rx_in};
  end

  wire fifo_full, fifo_empty;
  wire [DATA_BITS-1:0] fifo_out;

  fifo #(
      .DATA_WIDTH(DATA_BITS),
      .DEPTH     (FIFO_DEPTH)
  ) fifo_i (
      .clk   (clk),
      .resetn(resetn),
      .din   (rx_data),
      .dout  (fifo_out),
      .push  (ready & ~fifo_full),
      .pop   (data_rd & ~fifo_empty),
      .full  (fifo_full),
      .empty (fifo_empty)
  );

  assign data = fifo_empty ? 32'hFFFF_FFFF : {24'd0, fifo_out};

  always @(posedge clk) begin
    if (!resetn) begin
      state        <= ST_IDLE;
      ready        <= 1'b0;
      error        <= 1'b0;
      wait_states  <= 17'd1;
      bit_idx      <= 3'd0;
      rx_data      <= {DATA_BITS{1'b0}};
      return_state <= ST_IDLE;
    end else begin
      case (state)

        ST_IDLE: begin
          ready   <= 1'b0;
          error   <= 1'b0;
          bit_idx <= 3'd0;

          if (rx_in_sync[2:1] == 2'b10) begin
            wait_states  <= ({1'b0, div} >> 1);
            return_state <= ST_VERIFY;
            state        <= ST_WAIT;
          end
        end

        ST_VERIFY: begin
          if (~rx_sample) begin
            wait_states  <= {1'b0, div};
            return_state <= ST_DATA;
            state        <= ST_WAIT;
          end else begin
            state <= ST_IDLE;
          end
        end

        ST_DATA: begin
          rx_data[bit_idx] <= rx_sample;
          bit_idx          <= bit_idx + 1;
          wait_states      <= {1'b0, div};
          return_state     <= (bit_idx == (DATA_BITS[2:0] - 3'd1)) ? ST_STOP : ST_DATA;
          state            <= ST_WAIT;
        end

        ST_STOP: begin
          if (~rx_sample) begin
            error <= 1'b1;
            state <= ST_IDLE;
          end else begin
            ready        <= 1'b1;
            wait_states  <= ({1'b0, div} >> 2);
            return_state <= ST_IDLE;
            state        <= ST_WAIT;
          end
        end

        ST_WAIT: begin
          ready <= 1'b0;
          if (wait_states == 17'd1) state <= return_state;
          else wait_states <= wait_states - 1'b1;
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule

`default_nettype wire

