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

`default_nettype none `timescale 1 ns / 100 ps

`include "defines_soc.vh"

module soc #(
) (
    input wire clk_osc,
    input wire ext_resetn,
`ifdef USE_POWER_PINS
    inout VDD,
    inout VSS,
`endif
    output wire uart_tx,
    input wire uart_rx,

    output wire flash_sclk,
    output wire flash_csn,
    input  wire flash_miso,
    output wire flash_mosi,

    output wire        sdram_clk,
    output wire        sdram_cke,
    output wire [ 1:0] sdram_dqm,
    output wire [12:0] sdram_addr,
    output wire [ 1:0] sdram_ba,
    output wire        sdram_csn,
    output wire        sdram_wen,
    output wire        sdram_rasn,
    output wire        sdram_casn,
    output wire [15:0] sdram_dq_out,
    input  wire [15:0] sdram_dq_in,
    output wire        sdram_dq_oe,

    output wire spi_cen0,
    output wire spi_sclk0,
    input  wire spi_sio1_so_miso0,
    output wire spi_sio0_si_mosi0,

    output wire spi_cen1,
    output wire spi_sclk1,
    input  wire spi_sio1_so_miso1,
    output wire spi_sio0_si_mosi1,

    input  wire gpio_in,
    output wire gpio_out,
    output wire gpio_oe
);

  wire clk = clk_osc;

  (* async_reg="true" *) reg [1:0] sh;
  always @(posedge clk) begin
    if (!ext_resetn) sh <= 2'b00;
    else sh <= {sh[0], 1'b1};
  end
  wire ext_resetn_sync = sh[1];

  localparam integer RST_CYCLES = 200_000;
  localparam integer RSTW = $clog2(RST_CYCLES);
  reg  [RSTW-1:0] rst_cnt;
  wire            rst_done = (rst_cnt == RST_CYCLES - 1);
  reg             is_reboot_valid_r;

  always @(posedge clk) begin
    if (!ext_resetn_sync || is_reboot_valid_r) rst_cnt <= '0;
    else if (!rst_done) rst_cnt <= rst_cnt + 1'b1;
  end

  wire        resetn_sdram = ext_resetn_sync & rst_done;
  wire        resetn_soc;
  wire        sdram_init_done;

  wire        cpu_mem_ready;
  wire        cpu_mem_valid;
  wire [ 3:0] cpu_mem_wstrb;
  wire [33:0] cpu_mem_addr_phy;
  wire [31:0] cpu_mem_wdata;
  wire [31:0] cpu_mem_rdata;

  wire [31:0] cpu_mem_addr = cpu_mem_addr_phy[31:0];
  wire        wr = |cpu_mem_wstrb;
  wire        rd = ~wr;

  wire [29:0] word_aligned_addr = cpu_mem_addr[31:2];

  wire is_instruction, icache_flush;
  wire [5:0] ctrl_state;

  wire       is_reboot_addr = (cpu_mem_addr == `REBOOT_ADDR);
  wire       is_reboot_data = (cpu_mem_wdata[15:0] == `REBOOT_DATA);
  wire       is_reboot = is_reboot_addr || is_reboot_data;
  wire       is_reboot_valid = cpu_mem_valid && is_reboot_addr && is_reboot_data && wr;

  always @(posedge clk) begin
    if (!resetn_soc) is_reboot_valid_r <= 1'b0;
    else is_reboot_valid_r <= is_reboot_valid;
  end

  wire is_sdram = (cpu_mem_addr >= `SDRAM_MEM_ADDR_START && cpu_mem_addr < `SDRAM_MEM_ADDR_END);
  wire is_flash = (cpu_mem_addr >= `SPI_NOR_MEM_ADDR_START && cpu_mem_addr < `SPI_NOR_MEM_ADDR_END);
  wire hit_spi0 = (cpu_mem_addr == `KIANV_SPI_CTRL0 || cpu_mem_addr == `KIANV_SPI_DATA0);
  wire hit_spi1 = (cpu_mem_addr == `KIANV_SPI_CTRL1 || cpu_mem_addr == `KIANV_SPI_DATA1);
  wire hit_gpio = (cpu_mem_addr == `KIANV_GPIO_DIR   ||
                   cpu_mem_addr == `KIANV_GPIO_OUTPUT||
                   cpu_mem_addr == `KIANV_GPIO_INPUT);

  wire [31:0] cache_addr_o;
  wire [31:0] cache_din_o;
  wire [3:0] cache_wmask_o;
  wire cache_valid_o;
  wire [31:0] cache_dout_i;
  wire cache_ready_i;

  wire mem_sdram_valid = cpu_mem_valid && is_sdram;
  wire mem_sdram_ready;
  wire [31:0] mem_sdram_rdata;

  localparam [31:0] SDRAM_CFG_BASE = `KIANV_SDRAM_CTRL;
  localparam [15:0] SDRAM_CFG_BASE_HI = SDRAM_CFG_BASE[31:16];
  wire        sdram_cfg_access = cpu_mem_valid && (cpu_mem_addr[31:16] == SDRAM_CFG_BASE_HI);

  wire        sdram_cfg_ready_w;
  wire [31:0] sdram_cfg_rdata_w;
  wire sdram_cfg_wr_w, sdram_cfg_rd_w;
  wire [ 5:0] sdram_cfg_addr_w;
  wire [31:0] sdram_cfg_wdata_w;
  wire [31:0] sdram_cfg_rdata_w_hw;
  wire        sdram_cfg_done_w_hw;

  mt48lc16m16a2_ctrl #(
      .SDRAM_CLK_FREQ(`SYSTEM_CLK / 1_000_000),
      .TREFI_NS      (`TREFI_NS),
      .TRP_NS        (`TRP_NS),
      .TRCD_NS       (`TRCD_NS),
      .TWR_NS        (`TWR_NS),
      .CAS           (`CAS)
  ) sdram_i (
      .clk   (clk),
      .resetn(resetn_sdram),

      .addr     (cache_addr_o[24:0]),
      .din      (cache_din_o),
      .wmask    (cache_wmask_o),
      .valid    (cache_valid_o),
      .dout     (cache_dout_i),
      .ready    (cache_ready_i),
      .init_done(sdram_init_done),

      .cfg_wr   (sdram_cfg_wr_w),
      .cfg_rd   (sdram_cfg_rd_w),
      .cfg_addr (sdram_cfg_addr_w),
      .cfg_wdata(sdram_cfg_wdata_w),
      .cfg_rdata(sdram_cfg_rdata_w_hw),
      .cfg_done (sdram_cfg_done_w_hw),

      .sdram_clk   (sdram_clk),
      .sdram_cke   (sdram_cke),
      .sdram_dqm   (sdram_dqm),
      .sdram_addr  (sdram_addr),
      .sdram_ba    (sdram_ba),
      .sdram_csn   (sdram_csn),
      .sdram_wen   (sdram_wen),
      .sdram_rasn  (sdram_rasn),
      .sdram_casn  (sdram_casn),
      .sdram_dq_out(sdram_dq_out),
      .sdram_dq_in (sdram_dq_in),
      .sdram_dq_oe (sdram_dq_oe)
  );

  cache #(
      .BYPASS_CACHES(`BYPASS_CACHES)
  ) cache_I (
      .clk           (clk),
      .resetn        (resetn_soc),
`ifdef USE_POWER_PINS
      .VDD           (VDD),
      .VSS           (VSS),
`endif
      .iflush        (icache_flush),
      .is_instruction(is_instruction),
      .cpu_addr_i    (cpu_mem_addr),
      .cpu_din_i     (cpu_mem_wdata),
      .cpu_wmask_i   (cpu_mem_wstrb),
      .cpu_valid_i   (mem_sdram_valid),
      .cpu_dout_o    (mem_sdram_rdata),
      .cpu_ready_o   (mem_sdram_ready),
      .cache_addr_o  (cache_addr_o),
      .cache_din_o   (cache_din_o),
      .cache_wmask_o (cache_wmask_o),
      .cache_valid_o (cache_valid_o),
      .cache_dout_i  (cache_dout_i),
      .cache_ready_i (cache_ready_i)
  );

  assign resetn_soc = ext_resetn_sync & (rst_cnt == RST_CYCLES - 1) & sdram_init_done;

  sdram_cfg_if #(
      .BASE_ADDR    (SDRAM_CFG_BASE),
      .ADDR_HI_MATCH(SDRAM_CFG_BASE_HI)
  ) sdram_cfg_if_I (
      .clk        (clk),
      .resetn     (resetn_soc),
      .bus_valid_i(cpu_mem_valid),
      .bus_addr_i (cpu_mem_addr),
      .bus_wstrb_i(cpu_mem_wstrb),
      .bus_wdata_i(cpu_mem_wdata),
      .bus_rdata_o(sdram_cfg_rdata_w),
      .bus_ready_o(sdram_cfg_ready_w),
      .cfg_wr     (sdram_cfg_wr_w),
      .cfg_rd     (sdram_cfg_rd_w),
      .cfg_addr   (sdram_cfg_addr_w),
      .cfg_wdata  (sdram_cfg_wdata_w),
      .cfg_rdata  (sdram_cfg_rdata_w_hw),
      .cfg_done   (sdram_cfg_done_w_hw)
  );

`ifdef USE_SIM_MEM_MODEL

  assign sdram_clk   = clk;
  assign sdram_cke   = 1'b0;
  assign sdram_dqm   = 2'b00;
  assign sdram_addr  = 13'h0;
  assign sdram_ba    = 2'b00;
  assign sdram_csn   = 1'b1;
  assign sdram_wen   = 1'b1;
  assign sdram_rasn  = 1'b1;
  assign sdram_casn  = 1'b1;
  assign sdram_dq_oe = 1'b0;
  assign sdram_dq_out= 16'h0000;
`endif

  wire        spi_nor_ready;
  wire [31:0] spi_nor_rdata;

  spi_nor_if #(
      .START_ADDR     (`SPI_NOR_MEM_ADDR_START),
      .END_ADDR       (`SPI_NOR_MEM_ADDR_END),
      .ADDR_WORD_SHIFT(2),
      .ADDR_WORD_WIDTH(22)
  ) spi_nor_if_I (
      .clk        (clk),
      .resetn     (resetn_soc),
      .bus_valid_i(cpu_mem_valid),
      .bus_addr_i (cpu_mem_addr),
      .bus_wstrb_i(cpu_mem_wstrb),
      .bus_rdata_o(spi_nor_rdata),
      .bus_ready_o(spi_nor_ready),
      .spi_cs     (flash_csn),
      .spi_sclk   (flash_sclk),
      .spi_mosi   (flash_mosi),
      .spi_miso   (flash_miso)
  );

  wire        gpio_ready;
  wire [31:0] gpio_rdata;
  gpio_if #(
      .DIR_ADDR(`KIANV_GPIO_DIR),
      .OUT_ADDR(`KIANV_GPIO_OUTPUT),
      .IN_ADDR (`KIANV_GPIO_INPUT)
  ) gpio_if_I (
      .clk        (clk),
      .resetn     (resetn_soc),
      .bus_valid_i(cpu_mem_valid),
      .bus_addr_i (cpu_mem_addr),
      .bus_wstrb_i(cpu_mem_wstrb),
      .bus_wdata_i(cpu_mem_wdata),
      .bus_rdata_o(gpio_rdata),
      .bus_ready_o(gpio_ready),
      .gpio_oe    (gpio_oe),
      .gpio_in    (gpio_in),
      .gpio_out   (gpio_out)
  );

  wire spi0_ready, spi1_ready;
  wire [31:0] spi0_rdata, spi1_rdata;

  wire        div_ready;
  wire [31:0] div_rdata;
  wire [31:0] div_reg_bus0, div_reg_bus1;
  wire div0_valid_seen, div1_valid_seen;

`ifdef SIM
  localparam SIM_DEF_EN = 1'b1;
`else
  localparam SIM_DEF_EN = 1'b0;
`endif
  div_if #(
      .DIV_ADDR0    (`DIV_ADDR0),
      .DIV_ADDR1    (`DIV_ADDR1),
      .SYSTEM_CLK_HZ(`SYSTEM_CLK),
      .SIM_DEFAULTS (SIM_DEF_EN)
  ) div_if_I (
      .clk         (clk),
      .resetn      (resetn_soc),
      .bus_valid_i (cpu_mem_valid),
      .bus_addr_i  (cpu_mem_addr),
      .bus_wstrb_i (cpu_mem_wstrb),
      .bus_wdata_i (cpu_mem_wdata),
      .bus_rdata_o (div_rdata),
      .bus_ready_o (div_ready),
      .div_reg0_o  (div_reg_bus0),
      .div_reg1_o  (div_reg_bus1),
      .div0_valid_o(div0_valid_seen),
      .div1_valid_o(div1_valid_seen),
      .div_reg_o   (),
      .div_valid_o ()
  );

  spi_if #(
      .CTRL_ADDR(`KIANV_SPI_CTRL0),
      .DATA_ADDR(`KIANV_SPI_DATA0),
      .CPOL     (1'b0)
  ) spi0_if_I (
      .clk        (clk),
      .resetn     (resetn_soc),
      .bus_valid_i(cpu_mem_valid),
      .bus_addr_i (cpu_mem_addr),
      .bus_wstrb_i(cpu_mem_wstrb),
      .bus_wdata_i(cpu_mem_wdata),
      .bus_rdata_o(spi0_rdata),
      .bus_ready_o(spi0_ready),
      .div_i      (div_reg_bus0[31:16]),
      .cen        (spi_cen0),
      .sclk       (spi_sclk0),
      .miso       (spi_sio1_so_miso0),
      .mosi       (spi_sio0_si_mosi0)
  );

  spi_if #(
      .CTRL_ADDR(`KIANV_SPI_CTRL1),
      .DATA_ADDR(`KIANV_SPI_DATA1),
      .CPOL     (1'b0)
  ) spi1_if_I (
      .clk        (clk),
      .resetn     (resetn_soc),
      .bus_valid_i(cpu_mem_valid),
      .bus_addr_i (cpu_mem_addr),
      .bus_wstrb_i(cpu_mem_wstrb),
      .bus_wdata_i(cpu_mem_wdata),
      .bus_rdata_o(spi1_rdata),
      .bus_ready_o(spi1_ready),
      .div_i      (div_reg_bus1[31:16]),
      .cen        (spi_cen1),
      .sclk       (spi_sclk1),
      .miso       (spi_sio1_so_miso1),
      .mosi       (spi_sio0_si_mosi1)
  );

  wire        uart_if_ready;
  wire [31:0] uart_if_rdata;
  wire [31:0] uart_rx_data_obs;
  wire        uart_tx_busy_obs;

  wire        uart_tx_rdy;
  wire        uart_lsr_rdy;

  uart_if #(
      .LSR_ADDR(`UART_LSR_ADDR0),
      .TX_ADDR (`UART_TX_ADDR0),
      .RX_ADDR (`UART_RX_ADDR0),
      .HAS_TEMT(1'b1),
      .HAS_THRE(1'b1)
  ) uart_if_I (
      .clk        (clk),
      .resetn     (resetn_soc),
      .bus_valid_i(cpu_mem_valid),
      .bus_addr_i (cpu_mem_addr),
      .bus_wstrb_i(cpu_mem_wstrb),
      .bus_wdata_i(cpu_mem_wdata),
      .bus_rdata_o(uart_if_rdata),
      .bus_ready_o(uart_if_ready),
      .div_i      (div_reg_bus0[15:0]),
      .uart_tx    (uart_tx),
      .uart_rx    (uart_rx),
      .rx_data_o  (uart_rx_data_obs),
      .tx_busy_o  (uart_tx_busy_obs),
      .tx_ready_o (uart_tx_rdy),
      .lsr_ready_o(uart_lsr_rdy)
  );

  wire clint_ready, plic_ready;
  wire [31:0] clint_rdata, plic_rdata;
  wire clint_valid_vis, plic_valid_vis;
  wire IRQ3, IRQ7;
  wire [63:0] timer_counter;
  wire irq_ctx0_w, irq_ctx1_w;
  wire [63:0] mtime_for_system;

  mtime_source mtime_src_I (
      .clk            (clk),
      .resetn         (resetn_soc),
      .timer_counter_i(timer_counter),
      .mtime_div_i    (div_reg_bus1[15:0]),
      .mtime_o        (mtime_for_system)
  );

  clint_if #(
      .BASE_HI(8'h02)
  ) clint_if_I (
      .clk            (clk),
      .resetn         (resetn_soc),
      .bus_valid_i    (cpu_mem_valid),
      .bus_addr_i     (cpu_mem_addr),
      .bus_wstrb_i    (cpu_mem_wstrb),
      .bus_wdata_i    (cpu_mem_wdata),
      .bus_rdata_o    (clint_rdata),
      .bus_ready_o    (clint_ready),
      .is_valid_o     (clint_valid_vis),
      .timer_counter_i(mtime_for_system),
      .IRQ3           (IRQ3),
      .IRQ7           (IRQ7)
  );

  wire uart_irq = ~(&uart_rx_data_obs) || uart_tx_busy_obs;
  wire [31:1] plic_irqs = {21'b0, uart_irq, 9'b0};

  plic_if #(
      .BASE_HI(8'h0C)
  ) plic_if_I (
      .clk              (clk),
      .resetn           (resetn_soc),
      .bus_valid_i      (cpu_mem_valid),
      .bus_addr_i       (cpu_mem_addr),
      .bus_wstrb_i      (cpu_mem_wstrb),
      .bus_wdata_i      (cpu_mem_wdata),
      .bus_rdata_o      (plic_rdata),
      .bus_ready_o      (plic_ready),
      .is_valid_o       (plic_valid_vis),
      .interrupt_request(plic_irqs),
      .irq_ctx0_o       (irq_ctx0_w),
      .irq_ctx1_o       (irq_ctx1_w)
  );

  wire        sys_ready;
  wire [31:0] sys_rdata;
  wire sys_cpu_freq_valid, sys_mem_size_valid;
  wire [15:0] sysclk_mhz_q8_8;

  sysinfo_if #(
      .CPU_FREQ_ADDR(`CPU_FREQ_REG_ADDR),
      .MEM_SIZE_ADDR(`CPU_MEMSIZE_REG_ADDR)
  ) sysinfo_if_I (
      .clk             (clk),
      .resetn          (resetn_soc),
      .sysclk_mhz_q8_8 (sysclk_mhz_q8_8),
      .bus_valid_i     (cpu_mem_valid),
      .bus_addr_i      (cpu_mem_addr),
      .bus_wstrb_i     (cpu_mem_wstrb),
      .bus_wdata_i     (cpu_mem_wdata),
      .bus_rdata_o     (sys_rdata),
      .bus_ready_o     (sys_ready),
      .cpu_freq_valid_o(sys_cpu_freq_valid),
      .mem_size_valid_o(sys_mem_size_valid)
  );

  wire match_lsr = (cpu_mem_addr == `UART_LSR_ADDR0);
  wire match_tx = (cpu_mem_addr == `UART_TX_ADDR0);
  wire match_rx = (cpu_mem_addr == `UART_RX_ADDR0);

  wire is_io = (cpu_mem_addr >= 32'h10_000_000 && cpu_mem_addr <= 32'h12_000_000) ||
               (cpu_mem_addr[31:24] == 8'h0C) || (cpu_mem_addr[31:24] == 8'h02);

  wire spi_mem_valid0 = cpu_mem_valid && hit_spi0;
  wire spi_mem_valid1 = cpu_mem_valid && hit_spi1;
  wire gpio_valid = cpu_mem_valid && hit_gpio;

  wire unmatched_io = !(match_lsr || match_tx || match_rx ||
                        clint_valid_vis || plic_valid_vis ||
                        spi_mem_valid0 || spi_mem_valid1 ||
                        div0_valid_seen || div1_valid_seen || gpio_valid ||
                        sys_cpu_freq_valid || sys_mem_size_valid ||
                        sdram_cfg_access);

  reg unmatched_io_ready;
  always @(posedge clk) begin
    if (!resetn_soc) unmatched_io_ready <= 1'b0;
    else unmatched_io_ready <= unmatched_io;
  end

  reg is_io_ready;
  always @(posedge clk) begin
    if (!resetn_soc) is_io_ready <= 1'b0;
    else is_io_ready <= is_io;
  end

  reg        io_ready;
  reg [31:0] io_rdata;
  always @(*) begin
    io_ready = 1'b0;
    io_rdata = 32'h0;
    if (is_io_ready) begin
      if (uart_if_ready) begin
        io_ready = 1'b1;
        io_rdata = uart_if_rdata;
      end else if (sys_ready) begin
        io_ready = 1'b1;
        io_rdata = sys_rdata;
      end else if (clint_ready) begin
        io_ready = 1'b1;
        io_rdata = clint_rdata;
      end else if (plic_ready) begin
        io_ready = 1'b1;
        io_rdata = plic_rdata;
      end else if (div_ready) begin
        io_ready = 1'b1;
        io_rdata = div_rdata;
      end else if (spi0_ready) begin
        io_ready = 1'b1;
        io_rdata = spi0_rdata;
      end else if (spi1_ready) begin
        io_ready = 1'b1;
        io_rdata = spi1_rdata;
      end else if (gpio_ready) begin
        io_ready = 1'b1;
        io_rdata = gpio_rdata;
      end else if (sdram_cfg_ready_w) begin
        io_ready = 1'b1;
        io_rdata = sdram_cfg_rdata_w;
      end else if (unmatched_io_ready) begin
        io_ready = 1'b1;
        io_rdata = 32'h0;
      end
    end
  end

  reg access_fault_ready;
  wire non_instruction_invalid_access = !is_instruction && !(is_io || is_sdram || is_flash || is_reboot);
  wire instruction_invalid_access = is_instruction && !(is_sdram || is_flash);
  wire hit_access_fault_valid         = `ENABLE_ACCESS_FAULT &&
                                        (cpu_mem_valid &&
                                        (non_instruction_invalid_access || instruction_invalid_access));
  always @(posedge clk) begin
    if (!resetn_soc) access_fault_ready <= 1'b0;
    else access_fault_ready <= hit_access_fault_valid;
  end

  kianv_harris_mc_edition #(
      .RESET_ADDR      (`RESET_ADDR),
      .NUM_ENTRIES_ITLB(`NUM_ENTRIES_ITLB),
      .NUM_ENTRIES_DTLB(`NUM_ENTRIES_DTLB)
  ) kianv_I (
      .clk            (clk),
      .resetn         (resetn_soc),
      .sysclk_mhz_q8_8(sysclk_mhz_q8_8),
      .mem_ready      (cpu_mem_ready),
      .mem_valid      (cpu_mem_valid),
      .mem_wstrb      (cpu_mem_wstrb),
      .mem_addr       (cpu_mem_addr_phy),
      .mem_wdata      (cpu_mem_wdata),
      .mem_rdata      (cpu_mem_rdata),
      .access_fault   (access_fault_ready),
      .timer_counter  (timer_counter),
      .is_instruction (is_instruction),
      .icache_flush   (icache_flush),
      .IRQ3           (IRQ3),
      .IRQ7           (IRQ7),
      .IRQ9           (irq_ctx1_w),
      .IRQ11          (irq_ctx0_w),
      .PC             ()
  );

  assign cpu_mem_ready =
      (is_sdram && mem_sdram_valid && mem_sdram_ready) ||
      (is_flash && spi_nor_ready) ||
      (hit_spi0 && spi0_ready) ||
      (hit_spi1 && spi1_ready) ||
      (hit_gpio && gpio_ready) ||
      (is_io    && io_ready) ||
      (hit_access_fault_valid && access_fault_ready);

  assign cpu_mem_rdata =
      (is_sdram && mem_sdram_ready) ? mem_sdram_rdata :
      (is_flash && spi_nor_ready)   ? spi_nor_rdata   :
      (hit_spi0 && spi0_ready)      ? spi0_rdata      :
      (hit_spi1 && spi1_ready)      ? spi1_rdata      :
      (hit_gpio && gpio_ready)      ? gpio_rdata      :
      (is_io    && io_ready)        ? io_rdata        :
      32'h0000_0000;

endmodule

module uart_if #(
    parameter [31:0] LSR_ADDR = 32'h1000_0005,
    parameter [31:0] TX_ADDR  = 32'h1000_0000,
    parameter [31:0] RX_ADDR  = 32'h1000_0004,
    parameter        HAS_TEMT = 1'b1,
    parameter        HAS_THRE = 1'b1
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        bus_valid_i,
    input  wire [31:0] bus_addr_i,
    input  wire [ 3:0] bus_wstrb_i,
    input  wire [31:0] bus_wdata_i,
    output wire [31:0] bus_rdata_o,
    output wire        bus_ready_o,

    input wire [15:0] div_i,

    output wire uart_tx,
    input  wire uart_rx,

    output wire [31:0] rx_data_o,
    output wire        tx_busy_o,
    output wire        tx_ready_o,
    output wire        lsr_ready_o
);
  wire wr = |bus_wstrb_i;
  wire rd = ~wr;

  wire match_lsr = bus_valid_i && (bus_addr_i == LSR_ADDR) && rd;
  wire match_tx = bus_valid_i && (bus_addr_i == TX_ADDR) && wr;
  wire match_rx = bus_valid_i && (bus_addr_i == RX_ADDR) && rd;

  wire uart_tx_rdy;
  wire uart_tx_busy;
  reg  tx_seen;
  wire tx_accept = match_tx && !tx_seen && uart_tx_rdy;
  reg  uart_tx_ready;

  always @(posedge clk) begin
    if (!resetn) uart_tx_ready <= 1'b0;
    else uart_tx_ready <= tx_accept;
  end
  always @(posedge clk) begin
    if (!resetn) tx_seen <= 1'b0;
    else if (!match_tx) tx_seen <= 1'b0;
    else if (tx_accept) tx_seen <= 1'b1;
  end

  tx_uart tx_uart_i (
      .clk    (clk),
      .resetn (resetn),
      .valid  (tx_accept),
      .tx_data(bus_wdata_i[7:0]),
      .div    (div_i),
      .tx_out (uart_tx),
      .ready  (uart_tx_rdy),
      .busy   (uart_tx_busy)
  );
  assign tx_busy_o  = uart_tx_busy;
  assign tx_ready_o = uart_tx_rdy;

  reg         uart_rx_ready;
  wire [31:0] rx_uart_data;
  wire        uart_rx_valid_rd = (~uart_rx_ready) && match_rx;
  always @(posedge clk) begin
    if (!resetn) uart_rx_ready <= 1'b0;
    else uart_rx_ready <= uart_rx_valid_rd;
  end

  rx_uart rx_uart_i (
      .clk    (clk),
      .resetn (resetn),
      .rx_in  (uart_rx),
      .div    (div_i),
      .error  (),
      .data_rd(uart_rx_ready),
      .data   (rx_uart_data)
  );
  assign rx_data_o = rx_uart_data;

  reg lsr_thre;
  always @(posedge clk) begin
    if (!resetn) lsr_thre <= 1'b1;
    else if (tx_accept) lsr_thre <= 1'b0;
    else if (uart_tx_rdy) lsr_thre <= 1'b1;
  end

  wire       temt_bit = HAS_TEMT ? (~uart_tx_busy) : 1'b0;
  wire       thre_bit = HAS_THRE ? lsr_thre : 1'b0;
  wire [7:0] lsr = {1'b0, temt_bit, thre_bit, 1'b0, 3'b000, ~(&rx_uart_data)};

  reg        lsr_rdy_q;
  always @(posedge clk) begin
    if (!resetn) lsr_rdy_q <= 1'b0;
    else lsr_rdy_q <= (~lsr_rdy_q) && match_lsr;
  end
  assign lsr_ready_o = lsr_rdy_q;

  reg [31:0] rdata_r;
  reg        ready_r;
  always @(*) begin
    rdata_r = 32'h0;
    ready_r = 1'b0;

    if (lsr_rdy_q) begin
      rdata_r = {16'h0000, lsr, 8'h00};
      ready_r = 1'b1;
    end else if (uart_rx_ready) begin
      rdata_r = rx_uart_data;
      ready_r = 1'b1;
    end else if (uart_tx_ready) begin
      rdata_r = 32'h0000_0000;
      ready_r = 1'b1;
    end
  end

  assign bus_rdata_o = ready_r ? rdata_r : 32'h0;
  assign bus_ready_o = ready_r;
endmodule

module sdram_cfg_if #(
    parameter [31:0] BASE_ADDR     = 32'h1060_0000,
    parameter [15:0] ADDR_HI_MATCH = 16'h1060
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        bus_valid_i,
    input  wire [31:0] bus_addr_i,
    input  wire [ 3:0] bus_wstrb_i,
    input  wire [31:0] bus_wdata_i,
    output wire [31:0] bus_rdata_o,
    output wire        bus_ready_o,

    output reg         cfg_wr,
    output reg         cfg_rd,
    output reg  [ 5:0] cfg_addr,
    output reg  [31:0] cfg_wdata,
    input  wire [31:0] cfg_rdata,
    input  wire        cfg_done
);
  wire        hit = bus_valid_i && (bus_addr_i[31:16] == ADDR_HI_MATCH);
  wire        rd = hit && (bus_wstrb_i == 4'b0000);
  wire        wr = hit && (|bus_wstrb_i);
  wire [ 5:0] word_addr = bus_addr_i[7:2];

  reg         busy;
  reg  [31:0] rdata_r;
  reg         ready_r;

  always @(posedge clk) begin
    if (!resetn) begin
      busy      <= 1'b0;
      cfg_wr    <= 1'b0;
      cfg_rd    <= 1'b0;
      cfg_addr  <= 6'h00;
      cfg_wdata <= 32'h0;
      rdata_r   <= 32'h0;
      ready_r   <= 1'b0;
    end else begin
      cfg_wr  <= 1'b0;
      cfg_rd  <= 1'b0;
      ready_r <= 1'b0;

      if (!busy && (rd || wr)) begin
        busy      <= 1'b1;
        cfg_addr  <= word_addr;
        cfg_wdata <= bus_wdata_i;
        if (wr) cfg_wr <= 1'b1;
        else cfg_rd <= 1'b1;
      end

      if (busy) begin
        if (cfg_done) begin
          busy    <= 1'b0;
          ready_r <= 1'b1;
          rdata_r <= cfg_rdata;
        end
      end
    end
  end

  assign bus_ready_o = ready_r;
  assign bus_rdata_o = ready_r ? rdata_r : 32'h0;
endmodule

module spi_nor_if #(
    parameter         [31:0] START_ADDR      = 32'h2000_0000,
    parameter         [31:0] END_ADDR        = 32'h2400_0000,
    parameter integer        ADDR_WORD_SHIFT = 2,
    parameter integer        ADDR_WORD_WIDTH = 22
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        bus_valid_i,
    input  wire [31:0] bus_addr_i,
    input  wire [ 3:0] bus_wstrb_i,
    output wire [31:0] bus_rdata_o,
    output wire        bus_ready_o,

    output wire spi_cs,
    output wire spi_sclk,
    output wire spi_mosi,
    input  wire spi_miso
);
  wire in_range = (bus_addr_i >= START_ADDR) && (bus_addr_i < END_ADDR);
  wire hit = bus_valid_i && in_range && (bus_wstrb_i == 4'b0000);

  wire [ADDR_WORD_WIDTH-1:0] word_addr = bus_addr_i[ADDR_WORD_SHIFT+ADDR_WORD_WIDTH-1 : ADDR_WORD_SHIFT];

  wire [31:0] data;
  wire ready;

  spi_nor_flash u_flash (
      .clk     (clk),
      .resetn  (resetn),
      .addr    (word_addr),
      .data    (data),
      .ready   (ready),
      .valid   (hit),
      .spi_cs  (spi_cs),
      .spi_sclk(spi_sclk),
      .spi_mosi(spi_mosi),
      .spi_miso(spi_miso)
  );

  assign bus_ready_o = ready;
  assign bus_rdata_o = ready ? data : 32'h0;
endmodule

module gpio_if #(
    parameter [31:0] DIR_ADDR = 32'h1100_0000,
    parameter [31:0] OUT_ADDR = 32'h1100_0004,
    parameter [31:0] IN_ADDR  = 32'h1100_0008
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        bus_valid_i,
    input  wire [31:0] bus_addr_i,
    input  wire [ 3:0] bus_wstrb_i,
    input  wire [31:0] bus_wdata_i,
    output wire [31:0] bus_rdata_o,
    output wire        bus_ready_o,
    output wire        gpio_oe,
    input  wire        gpio_in,
    output wire        gpio_out
);
  wire hit = bus_valid_i &&
            ((bus_addr_i == DIR_ADDR) || (bus_addr_i == OUT_ADDR) || (bus_addr_i == IN_ADDR));

  gpio gpio_I (
      .clk   (clk),
      .resetn(resetn),
      .addr  (bus_addr_i[3:0]),
      .wrstb (bus_wstrb_i),
      .wdata (bus_wdata_i),
      .rdata (bus_rdata_o),
      .valid (hit),
      .ready (bus_ready_o),
      .oe    (gpio_oe),
      .in    (gpio_in),
      .out   (gpio_out)
  );
endmodule

module spi_if #(
    parameter [31:0] CTRL_ADDR = 32'h0,
    parameter [31:0] DATA_ADDR = 32'h0,
    parameter        CPOL      = 1'b0
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        bus_valid_i,
    input  wire [31:0] bus_addr_i,
    input  wire [ 3:0] bus_wstrb_i,
    input  wire [31:0] bus_wdata_i,
    output wire [31:0] bus_rdata_o,
    output wire        bus_ready_o,

    input wire [15:0] div_i,

    output wire cen,
    output wire sclk,
    input  wire miso,
    output wire mosi
);
  wire hit = bus_valid_i && ((bus_addr_i == CTRL_ADDR) || (bus_addr_i == DATA_ADDR));

  spi #(
      .CPOL(CPOL)
  ) spi_I (
      .clk   (clk),
      .resetn(resetn),
      .ctrl  (bus_addr_i[2]),
      .rdata (bus_rdata_o),
      .wdata (bus_wdata_i),
      .wstrb (bus_wstrb_i),
      .valid (hit),
      .div   (div_i),
      .ready (bus_ready_o),
      .cen   (cen),
      .sclk  (sclk),
      .miso  (miso),
      .mosi  (mosi)
  );
endmodule

module clint_if #(
    parameter [7:0] BASE_HI = 8'h02
) (
    input wire clk,
    input wire resetn,

    input  wire        bus_valid_i,
    input  wire [31:0] bus_addr_i,
    input  wire [ 3:0] bus_wstrb_i,
    input  wire [31:0] bus_wdata_i,
    output wire [31:0] bus_rdata_o,
    output wire        bus_ready_o,
    output wire        is_valid_o,

    input wire [63:0] timer_counter_i,

    output wire IRQ3,
    output wire IRQ7
);

  wire is_clint = (bus_addr_i[31:24] == BASE_HI);

  clint clint_I (
      .clk          (clk),
      .resetn       (resetn),
      .valid        (is_clint && bus_valid_i),
      .addr         (bus_addr_i[23:0]),
      .wmask        (bus_wstrb_i),
      .wdata        (bus_wdata_i),
      .rdata        (bus_rdata_o),
      .is_valid     (is_valid_o),
      .ready        (bus_ready_o),
      .IRQ3         (IRQ3),
      .IRQ7         (IRQ7),
      .timer_counter(timer_counter_i)
  );
endmodule

module plic_if #(
    parameter [7:0] BASE_HI = 8'h0C
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        bus_valid_i,
    input  wire [31:0] bus_addr_i,
    input  wire [ 3:0] bus_wstrb_i,
    input  wire [31:0] bus_wdata_i,
    output wire [31:0] bus_rdata_o,
    output wire        bus_ready_o,
    output wire        is_valid_o,
    input  wire [31:1] interrupt_request,
    output wire        irq_ctx0_o,
    output wire        irq_ctx1_o
);
  wire is_plic = (bus_addr_i[31:24] == BASE_HI);

  plic plic_I (
      .clk                   (clk),
      .resetn                (resetn),
      .valid                 (is_plic && bus_valid_i),
      .addr                  (bus_addr_i[23:0]),
      .wmask                 (bus_wstrb_i),
      .wdata                 (bus_wdata_i),
      .rdata                 (bus_rdata_o),
      .interrupt_request     (interrupt_request),
      .is_valid              (is_valid_o),
      .ready                 (bus_ready_o),
      .interrupt_request_ctx0(irq_ctx0_o),
      .interrupt_request_ctx1(irq_ctx1_o)
  );
endmodule

module sysinfo_if #(

    parameter [31:0] CPU_FREQ_ADDR     = `CPU_FREQ_REG_ADDR,
    parameter [31:0] MEM_SIZE_ADDR     = `CPU_MEMSIZE_REG_ADDR,
    parameter        CPU_FREQ_WRITABLE = 1'b1
) (
    input wire clk,
    input wire resetn,

    output wire [15:0] sysclk_mhz_q8_8,

    input  wire        bus_valid_i,
    input  wire [31:0] bus_addr_i,
    input  wire [ 3:0] bus_wstrb_i,
    input  wire [31:0] bus_wdata_i,
    output wire [31:0] bus_rdata_o,
    output wire        bus_ready_o,

    output wire cpu_freq_valid_o,
    output wire mem_size_valid_o
);

  wire wr = |bus_wstrb_i;

  localparam [31:0] RESET_Q8_8_32 =
      ( ((`SYSTEM_CLK / 1_000_000) << 8)
      + ((((`SYSTEM_CLK % 1_000_000) * 256) + 500_000) / 1_000_000) );
  localparam [15:0] RESET_Q8_8 = (RESET_Q8_8_32 > 32'h0000_FFFF) ? 16'hFFFF : RESET_Q8_8_32[15:0];

  reg  [15:0] cpu_freq_reg;
  reg         cpu_freq_ready;

  wire        cpu_freq_hit = bus_valid_i && (bus_addr_i == CPU_FREQ_ADDR);
  wire        cpu_freq_valid = (!cpu_freq_ready) && cpu_freq_hit;

  always @(posedge clk) begin
    if (!resetn) begin
      cpu_freq_reg   <= RESET_Q8_8;
      cpu_freq_ready <= 1'b0;
    end else begin
      cpu_freq_ready <= cpu_freq_valid;
      if (CPU_FREQ_WRITABLE && cpu_freq_valid && wr) begin

        if (bus_wdata_i[15:0] < 16'h0100) cpu_freq_reg <= 16'h0100;
        else cpu_freq_reg <= bus_wdata_i[15:0];
      end
    end
  end

  reg  mem_size_ready;
  wire mem_size_hit = bus_valid_i && (bus_addr_i == MEM_SIZE_ADDR) && !wr;
  wire mem_size_valid = (!mem_size_ready) && mem_size_hit;

  always @(posedge clk) begin
    if (!resetn) mem_size_ready <= 1'b0;
    else mem_size_ready <= mem_size_valid;
  end

  assign bus_ready_o = cpu_freq_ready | mem_size_ready;

  assign bus_rdata_o = cpu_freq_ready ? {16'b0, cpu_freq_reg} :
                       mem_size_ready ? `SDRAM_SIZE :
                                        32'h0;

  assign sysclk_mhz_q8_8 = cpu_freq_reg;
  assign cpu_freq_valid_o = cpu_freq_valid;
  assign mem_size_valid_o = mem_size_valid;

endmodule

module div_if #(
    parameter [31:0] DIV_ADDR0 = 32'h1000_000C,
    parameter [31:0] DIV_ADDR1 = 32'h1000_0010,

    parameter integer SYSTEM_CLK_HZ    = 50_000_000,
    parameter         SIM_DEFAULTS     = 1'b0,
    parameter integer UART_BAUD_SIM    = 115_200,
    parameter integer SPI0_SCLK_HZ_SIM = 12_000_000,
    parameter integer SPI1_SCLK_HZ_SIM = 24_000_000,

    parameter integer CLINT_US_PER_TICK_SIM = 1
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        bus_valid_i,
    input  wire [31:0] bus_addr_i,
    input  wire [ 3:0] bus_wstrb_i,
    input  wire [31:0] bus_wdata_i,
    output wire [31:0] bus_rdata_o,
    output wire        bus_ready_o,

    output reg  [31:0] div_reg0_o,
    output reg  [31:0] div_reg1_o,
    output wire        div0_valid_o,
    output wire        div1_valid_o,

    output wire [31:0] div_reg_o,
    output wire        div_valid_o
);
  wire wr = |bus_wstrb_i;

  function [15:0] div_from_hz16;
    input integer fclk_hz;
    input integer target_hz;
    integer d;
    begin
      if (target_hz <= 0) d = 1;
      else d = (fclk_hz + (target_hz / 2)) / target_hz;
      if (d < 1) d = 1;
      if (d > 65535) d = 65535;
      div_from_hz16 = d[15:0];
    end
  endfunction

  localparam [15:0] UART_DIV_SIM = div_from_hz16(SYSTEM_CLK_HZ, UART_BAUD_SIM);
  localparam [15:0] SPI0_DIV_SIM = div_from_hz16(SYSTEM_CLK_HZ, SPI0_SCLK_HZ_SIM);
  localparam [15:0] SPI1_DIV_SIM = div_from_hz16(SYSTEM_CLK_HZ, SPI1_SCLK_HZ_SIM);
  localparam [15:0] CLINT_DIV_SIM  =
      (CLINT_US_PER_TICK_SIM < 1)    ? 16'd1 :
      (CLINT_US_PER_TICK_SIM > 65535)? 16'hFFFF :
                                       CLINT_US_PER_TICK_SIM[15:0];

  localparam [31:0] DIV0_RESET_SIM = {SPI0_DIV_SIM, UART_DIV_SIM};
  localparam [31:0] DIV1_RESET_SIM = {SPI1_DIV_SIM, CLINT_DIV_SIM};

  reg div0_ready_q, div1_ready_q;

  wire div0_access = bus_valid_i && (bus_addr_i == DIV_ADDR0);
  wire div1_access = bus_valid_i && (bus_addr_i == DIV_ADDR1);

  wire div0_valid = (!div0_ready_q) && div0_access;
  wire div1_valid = (!div1_ready_q) && div1_access;

  always @(posedge clk) begin
    if (!resetn) begin
      div0_ready_q <= 1'b0;
      div1_ready_q <= 1'b0;
    end else begin
      div0_ready_q <= div0_valid;
      div1_ready_q <= div1_valid;
    end
  end

  always @(posedge clk) begin
    if (!resetn) begin
      if (SIM_DEFAULTS) begin
        div_reg0_o <= DIV0_RESET_SIM;
        div_reg1_o <= DIV1_RESET_SIM;
      end else begin
        div_reg0_o <= 32'd1;
        div_reg1_o <= 32'd1;
      end
    end else begin
      if (div0_valid && wr) div_reg0_o <= bus_wdata_i;
      if (div1_valid && wr) div_reg1_o <= bus_wdata_i;
    end
  end

  assign bus_ready_o = div0_ready_q | div1_ready_q;
  assign bus_rdata_o = div0_ready_q ? div_reg0_o : div1_ready_q ? div_reg1_o : 32'h0;

  assign div0_valid_o = div0_valid;
  assign div1_valid_o = div1_valid;

  assign div_reg_o = div_reg0_o;
  assign div_valid_o = div0_valid;
endmodule

module mtime_source (
    input  wire        clk,
    input  wire        resetn,
    input  wire [63:0] timer_counter_i,
    input  wire [15:0] mtime_div_i,
    output wire [63:0] mtime_o
);

  reg  [63:0] prev_mtime;
  wire        tick_1us = (timer_counter_i != prev_mtime);

  reg [15:0] presc, div_lat;
  reg  [63:0] mtime_div;

  wire [15:0] div_safe = (mtime_div_i == 16'd0) ? 16'd1 : mtime_div_i;

  always @(posedge clk) begin
    if (!resetn) begin
      prev_mtime <= 64'd0;
      presc      <= 16'd0;
      div_lat    <= 16'd1;
      mtime_div  <= 64'd0;
    end else if (tick_1us) begin
      prev_mtime <= timer_counter_i;

      if (div_lat == 16'd1) begin

        presc   <= 16'd0;
        div_lat <= div_safe;
      end else begin

        if (presc == div_lat - 16'd1) begin
          presc    <= 16'd0;
          mtime_div<= mtime_div + 64'd1;
          div_lat  <= div_safe;
        end else begin
          presc <= presc + 16'd1;
        end
      end
    end
  end

  assign mtime_o = (div_lat == 16'd1) ? timer_counter_i : mtime_div;

endmodule

`default_nettype wire
