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
module spi_nor_flash #(
    parameter integer SCLK_DIV      = 1,
    parameter         LITTLE_ENDIAN = 1
) (
    input wire clk,
    input wire resetn,

    input  wire [21:0] addr,
    output wire [31:0] data,
    output wire        ready,
    input  wire        valid,

    output reg  spi_cs,
    input  wire spi_miso,
    output wire spi_mosi,
    output reg  spi_sclk
);

  reg  [15:0] divcnt;
  wire        tick = (SCLK_DIV == 1) ? 1'b1 : (divcnt == 16'd0);

  localparam [2:0] ST_IDLE = 3'd0, ST_CMD = 3'd1, ST_RD = 3'd2, ST_DONE = 3'd3;
  reg [2:0] state;

  reg phase;

  reg [31:0] cmd_sr, cmd_next;
  reg  [ 5:0] cmd_cnt;

  reg  [ 7:0] rx_sr;
  reg  [ 2:0] bit_cnt;
  reg  [ 1:0] byte_idx;
  reg  [31:0] rcv_buff;

  reg         done;
  reg         mosi_bit;

  reg         valid_d;
  wire        start_pulse = valid & ~valid_d;

  assign data     = rcv_buff;
  assign ready    = done;
  assign spi_mosi = mosi_bit;

  always @(posedge clk) begin
    if (!resetn) begin
      state    <= ST_IDLE;
      spi_cs   <= 1'b1;
      spi_sclk <= 1'b0;
      phase    <= 1'b0;
      divcnt   <= 16'd0;

      cmd_sr   <= 32'h0;
      cmd_next <= 32'h0;
      cmd_cnt  <= 6'd0;

      rx_sr    <= 8'h00;
      bit_cnt  <= 3'd0;
      byte_idx <= 2'd0;

      rcv_buff <= 32'h0;
      done     <= 1'b0;
      mosi_bit <= 1'b0;

      valid_d  <= 1'b0;
    end else begin
      valid_d <= valid;
      done    <= 1'b0;

      if (SCLK_DIV != 1) begin
        if (state == ST_IDLE) begin
          divcnt <= (SCLK_DIV <= 1) ? 16'd0 : (SCLK_DIV - 1);
        end else if (tick) begin
          divcnt <= (SCLK_DIV <= 1) ? 16'd0 : (SCLK_DIV - 1);
        end else begin
          divcnt <= divcnt - 16'd1;
        end
      end

      case (state)

        ST_IDLE: begin
          spi_cs   <= 1'b1;
          spi_sclk <= 1'b0;
          phase    <= 1'b0;
          if (start_pulse) begin
            cmd_next = {8'h03, addr, 2'b00};
            cmd_sr   <= cmd_next;
            cmd_cnt  <= 6'd31;
            mosi_bit <= cmd_next[31];
            spi_cs   <= 1'b0;
            state    <= ST_CMD;
          end
        end

        ST_CMD: begin
          if (tick) begin
            phase    <= ~phase;
            spi_sclk <= ~spi_sclk;
            if (phase == 1'b1) begin
              mosi_bit <= cmd_sr[31];
            end else begin
              cmd_sr <= {cmd_sr[30:0], 1'b0};
              if (cmd_cnt == 0) begin
                bit_cnt  <= 3'd7;
                byte_idx <= 2'd0;
                state    <= ST_RD;
              end else begin
                cmd_cnt <= cmd_cnt - 6'd1;
              end
            end
          end
        end

        ST_RD: begin
          if (tick) begin
            phase    <= ~phase;
            spi_sclk <= ~spi_sclk;
            if (phase == 1'b0) begin
              rx_sr <= {rx_sr[6:0], spi_miso};
              if (bit_cnt == 0) begin
                if (LITTLE_ENDIAN) begin
                  case (byte_idx)
                    2'd0: rcv_buff[7:0] <= {rx_sr[6:0], spi_miso};
                    2'd1: rcv_buff[15:8] <= {rx_sr[6:0], spi_miso};
                    2'd2: rcv_buff[23:16] <= {rx_sr[6:0], spi_miso};
                    2'd3: rcv_buff[31:24] <= {rx_sr[6:0], spi_miso};
                  endcase
                end else begin
                  case (byte_idx)
                    2'd0: rcv_buff[31:24] <= {rx_sr[6:0], spi_miso};
                    2'd1: rcv_buff[23:16] <= {rx_sr[6:0], spi_miso};
                    2'd2: rcv_buff[15:8] <= {rx_sr[6:0], spi_miso};
                    2'd3: rcv_buff[7:0] <= {rx_sr[6:0], spi_miso};
                  endcase
                end
                if (byte_idx == 2'd3) begin
                  state <= ST_DONE;
                end else begin
                  byte_idx <= byte_idx + 2'd1;
                  bit_cnt  <= 3'd7;
                end
              end else begin
                bit_cnt <= bit_cnt - 3'd1;
              end
            end
          end
        end

        ST_DONE: begin
          spi_cs   <= 1'b1;
          spi_sclk <= 1'b0;
          phase    <= 1'b0;
          done     <= 1'b1;
          state    <= ST_IDLE;
        end

        default: state <= ST_IDLE;
      endcase
    end
  end
endmodule
`default_nettype wire
