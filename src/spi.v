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

module spi #(
    parameter CPOL = 1'b0
) (
    input wire clk,
    input wire resetn,

    input  wire        ctrl,
    output wire [31:0] rdata,
    input  wire [31:0] wdata,
    input  wire [ 3:0] wstrb,
    input  wire [15:0] div,
    input  wire        valid,
    output reg         ready,

    output wire cen,
    output reg  sclk,
    output reg  mosi,
    input  wire miso
);

  localparam S_IDLE = 1'b0, S_XFER = 1'b1;

  reg         state;
  reg  [ 5:0] xfer_cycles;
  reg  [ 7:0] shreg;
  reg  [31:0] rx_data;
  reg         spi_cen;
  reg  [17:0] tick_cnt;

  wire        in_xfer = |xfer_cycles;

  wire [17:0] div_eff = (div == 16'd0) ? 18'd1 : {2'b0, div};
  wire        tick = (tick_cnt == div_eff - 1);

  wire        ctrl_access = valid && !ctrl;
  wire        data_write = valid && ctrl && wstrb[0] && !in_xfer;
  wire        data_read = valid && ctrl && !wstrb[0];
  wire        accept = ctrl_access || data_write || data_read;

  assign rdata = ctrl ? rx_data : {in_xfer, 30'b0, spi_cen};
  assign cen   = spi_cen;

  always @(posedge clk) begin
    if (!resetn) begin
      state       <= S_IDLE;
      xfer_cycles <= 6'd0;
      shreg       <= 8'h00;
      rx_data     <= 32'h0;
      spi_cen     <= 1'b1;
      sclk        <= CPOL;
      mosi        <= 1'b0;
      tick_cnt    <= 18'd0;
      ready       <= 1'b0;
    end else begin

      ready <= accept;

      if (ctrl_access && wstrb[0]) begin
        spi_cen <= ~wdata[0];
      end

      if (data_write) begin
        shreg       <= wdata[7:0];
        xfer_cycles <= 6'd8;
        state       <= S_XFER;
        sclk        <= CPOL;
        mosi        <= wdata[7];
      end

      case (state)
        S_IDLE: begin
          sclk <= CPOL;
        end

        S_XFER: begin
          if (in_xfer && tick) begin
            sclk <= ~sclk;

            if (!sclk) begin

              shreg       <= {shreg[6:0], miso};
              xfer_cycles <= xfer_cycles - 1'b1;
            end else begin

              mosi <= shreg[7];
            end
          end

          if (!in_xfer) begin
            state   <= S_IDLE;
            mosi    <= 1'b0;
            sclk    <= CPOL;
            rx_data <= {24'h0, shreg};
          end
        end
      endcase

      if (!in_xfer) tick_cnt <= 18'd0;
      else if (tick) tick_cnt <= 18'd0;
      else tick_cnt <= tick_cnt + 18'd1;
    end
  end

endmodule

`default_nettype wire
