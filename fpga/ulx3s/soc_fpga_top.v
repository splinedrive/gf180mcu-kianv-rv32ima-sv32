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

module soc_fpga_top (

    input wire clk_osc,
    input wire ext_resetn,

    output wire [1:0] uart_tx,
    input  wire [1:0] uart_rx,

    output wire        sdram_clk,
    output wire        sdram_cke,
    output wire [12:0] sdram_addr,
    output wire [ 1:0] sdram_ba,
    output wire [ 1:0] sdram_dqm,
    output wire        sdram_csn,
    output wire        sdram_wen,
    output wire        sdram_rasn,
    output wire        sdram_casn,
    inout  wire [15:0] sdram_dq,

    output wire spi_cen0,
    output wire spi_sclk0,
    input  wire spi_sio1_so_miso0,
    output wire spi_sio0_si_mosi0,

    output wire spi_cen1,
    output wire spi_sclk1,
    input  wire spi_sio1_so_miso1,
    output wire spi_sio0_si_mosi1,

    output wire flash_csn,
    input  wire flash_miso,
    output wire flash_mosi,

    inout wire [8:8] gpio,

`ifdef SOC_IS_ULX3S
    output wire wifi_en,
`endif
);

  wire [15:0] sdram_dq_out;
  wire [15:0] sdram_dq_in;
  wire sdram_dq_oe;
  assign sdram_dq    = sdram_dq_oe ? sdram_dq_out : 16'hzzzz;
  assign sdram_dq_in = sdram_dq;

  wire clk;
  pll #(
      .freq(`SYSTEM_CLK / 1_000_000)
  ) pll_I0 (
      clk_osc,
      clk
  );

  wire flash_sclk;
  wire flash_clk;
  USRMCLK u1 (
      .USRMCLKI (flash_clk),
      .USRMCLKTS(1'b0)
  );
  assign flash_clk = flash_sclk;

  wire wifi_en = 1'b1;

  wire gpio_out;
  wire gpio_in;
  wire gpio_oe;
  assign gpio = gpio_oe ? gpio_out : 1'hz;
  assign gpio = gpio_in;

  wire rst_n_sync;
  async_reset_sync u_rst_sync (
      .clk        (clk),
      .rst_n_async(ext_resetn),
      .rst_n_sync (rst_n_sync)
  );

  soc #() u_soc (
      .clk_osc   (clk),
      .ext_resetn(rst_n_sync),

      .uart_tx(uart_tx),
      .uart_rx(uart_rx),

      .flash_sclk(flash_sclk),
      .flash_csn (flash_csn),
      .flash_miso(flash_miso),
      .flash_mosi(flash_mosi),

      .sdram_clk   (sdram_clk),
      .sdram_cke   (sdram_cke),
      .sdram_dqm   (sdram_dqm),
      .sdram_addr  (sdram_addr),
      .sdram_ba    (sdram_ba),
      .sdram_csn   (sdram_csn),
      .sdram_wen   (sdram_wen),
      .sdram_rasn  (sdram_rasn),
      .sdram_casn  (sdram_casn),
      .sdram_dq_in (sdram_dq_in),
      .sdram_dq_out(sdram_dq_out),
      .sdram_dq_oe (sdram_dq_oe),

      .spi_cen0         (spi_cen0),
      .spi_sclk0        (spi_sclk0),
      .spi_sio1_so_miso0(spi_sio1_so_miso0),
      .spi_sio0_si_mosi0(spi_sio0_si_mosi0),

      .spi_cen1         (spi_cen1),
      .spi_sclk1        (spi_sclk1),
      .spi_sio1_so_miso1(spi_sio1_so_miso1),
      .spi_sio0_si_mosi1(spi_sio0_si_mosi1),

      .gpio_in (gpio_in),
      .gpio_out(gpio_out),
      .gpio_oe (gpio_oe)
  );

endmodule

