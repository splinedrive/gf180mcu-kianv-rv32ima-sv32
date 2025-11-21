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
module tx_uart #(
    parameter FIFO_DEPTH = 16,
    parameter STOP_BITS  = 1
) (
    input wire clk,
    input wire resetn,

    input wire       valid,
    input wire [7:0] tx_data,

    input wire [15:0] div,

    output reg tx_out,

    output wire ready,
    output wire busy
);

  wire       fifo_full;
  wire       fifo_empty;
  wire [7:0] fifo_dout;
  reg        fifo_pop;

  assign ready = ~fifo_full;

  fifo #(
      .DATA_WIDTH(8),
      .DEPTH     (FIFO_DEPTH)
  ) tx_fifo_i (
      .clk   (clk),
      .resetn(resetn),
      .din   (tx_data),
      .dout  (fifo_dout),
      .push  (valid & ~fifo_full),
      .pop   (fifo_pop),
      .full  (fifo_full),
      .empty (fifo_empty)
  );

  localparam S_IDLE = 3'd0;
  localparam S_START = 3'd1;
  localparam S_DATA = 3'd2;
  localparam S_STOP = 3'd3;
  localparam S_WAIT = 3'd4;

  reg [2:0] state, return_state;
  reg [ 2:0] bit_idx;
  reg [ 7:0] tx_data_reg;
  reg [16:0] wait_states;

  assign busy = (state != S_IDLE) | ~fifo_empty;

  always @(posedge clk) begin
    if (!resetn) begin
      tx_out       <= 1'b1;
      state        <= S_IDLE;
      return_state <= S_IDLE;
      bit_idx      <= 3'd0;
      tx_data_reg  <= 8'd0;
      wait_states  <= 17'd0;
      fifo_pop     <= 1'b0;
    end else begin
      fifo_pop <= 1'b0;

      case (state)

        S_IDLE: begin
          tx_out  <= 1'b1;
          bit_idx <= 3'd0;

          if (!fifo_empty) begin

            tx_data_reg <= fifo_dout;
            fifo_pop    <= 1'b1;
            state       <= S_START;
          end
        end

        S_START: begin
          tx_out       <= 1'b0;
          wait_states  <= {1'b0, div} - 17'd1;
          return_state <= S_DATA;
          state        <= S_WAIT;
        end

        S_DATA: begin
          tx_out <= tx_data_reg[bit_idx];

          if (bit_idx == 3'd7) begin

            wait_states  <= {1'b0, div} - 17'd1;
            return_state <= S_STOP;
            bit_idx      <= 3'd0;
          end else begin

            bit_idx      <= bit_idx + 3'd1;
            wait_states  <= {1'b0, div} - 17'd1;
            return_state <= S_DATA;
          end

          state <= S_WAIT;
        end

        S_STOP: begin
          tx_out <= 1'b1;

          if (STOP_BITS == 2) begin

            wait_states <= ({1'b0, div} << 1) - 17'd1;
          end else begin

            wait_states <= {1'b0, div} - 17'd1;
          end

          return_state <= S_IDLE;
          state        <= S_WAIT;
        end

        S_WAIT: begin

          if (wait_states == 17'd0) begin
            state <= return_state;
          end else begin
            wait_states <= wait_states - 17'd1;
          end
        end

        default: begin

          state  <= S_IDLE;
          tx_out <= 1'b1;
        end
      endcase
    end
  end

`ifdef UART_TX_DEBUG
  always @(posedge clk) begin
    if (fifo_pop) begin
      $display("[TX_UART] Sending byte: 0x%02X ('%c')", fifo_dout,
               (fifo_dout >= 32 && fifo_dout <= 126) ? fifo_dout : 8'h2E);
    end
  end
`endif

endmodule
