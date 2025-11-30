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

`ifndef KIANV_SOC
`define KIANV_SOC

// ============================================================================
// Build-stop helper
// ============================================================================
`ifndef KIANV_NO_ERROR
  `define KIANV_BUILD_ERROR(MSG) `error "KIANV: " MSG
`else
  // Fallback: intentionally illegal typedef to halt preprocessors without `error
  `define KIANV_BUILD_ERROR(MSG) typedef logic _KIANV_BUILD_ERROR__``MSG[-1:0];
`endif

// ============================================================================
// Simulation-only configuration
// ============================================================================
`ifdef SIM
  `define SYSTEM_CLK 20_000_000
  `define NUM_ENTRIES_ITLB 32
  `define NUM_ENTRIES_DTLB 32
`endif

// ============================================================================
// Feature toggles / global controls
// ============================================================================
`define KIANV_SPI_CTRL0_FREQ 35_000_000 // sdcard
`define ENABLE_ACCESS_FAULT (1'b1)
//`define FPGA_MULTIPLIER

// ============================================================================
// SDRAM timing parameters (ns)
// ============================================================================
`define TRP_NS    15
`define TRCD_NS   15
`define TRFC_NS   66
`define TWR_NS    15
`define CAS       2
`define TREFI_NS  7800

// ============================================================================
// CACHE parameters
// ============================================================================

`ifndef BYPASS_CACHES
`define BYPASS_CACHES 1'b0
`endif

// ============================================================================
// System control values
// ============================================================================
`define REBOOT_ADDR 32'h 11_100_000
`define REBOOT_DATA 16'h 7777
`define HALT_DATA   16'h 5555

// Divider / CPU info registers
`define DIV_ADDR0              32'h 10_000_00C
`define DIV_ADDR1              32'h 10_000_010
`define CPU_FREQ_REG_ADDR      32'h 10_000_014
`define CPU_MEMSIZE_REG_ADDR   32'h10_000_018

// ============================================================================
// GPIO
// ============================================================================
`define KIANV_GPIO_DIR    32'h10_000_700
`define KIANV_GPIO_OUTPUT 32'h10_000_704
`define KIANV_GPIO_INPUT  32'h10_000_708

// ============================================================================
// UARTs
// ============================================================================
`define UART_TX_ADDR0 32'h10_000_000
`define UART_RX_ADDR0 32'h10_000_000
`define UART_LSR_ADDR0 32'h10_000_005

`define UART_TX_ADDR1 32'h10_000_100
`define UART_RX_ADDR1 32'h10_000_100
`define UART_LSR_ADDR1 32'h10_000_105

`define UART_TX_ADDR2 32'h10_000_200
`define UART_RX_ADDR2 32'h10_000_200
`define UART_LSR_ADDR2 32'h10_000_205

`define UART_TX_ADDR3 32'h10_000_300
`define UART_RX_ADDR3 32'h10_000_300
`define UART_LSR_ADDR3 32'h10_000_305

`define UART_TX_ADDR4 32'h10_000_400
`define UART_RX_ADDR4 32'h10_000_400
`define UART_LSR_ADDR4 32'h10_000_405

// ============================================================================
// SPI
// ============================================================================
  // sd card
`define KIANV_SPI_CTRL0 32'h10_500_000
`define KIANV_SPI_DATA0 32'h10_500_004

  // network
`define KIANV_SPI_CTRL1      32'h10_500_100
`define KIANV_SPI_DATA1      32'h10_500_104
`define KIANV_SPI_CTRL1_FREQ 13_000_000

// ============================================================================
// SDRAM controller
// ============================================================================
`define KIANV_SDRAM_CTRL 32'h10_600_000

// ============================================================================
// Audio (unchanged behavior)
// ============================================================================
`define KIANV_SND_REG          32'h10_500_300
`define KIANV_AUDIO_PWM_BUFFER (1 << 16)

// ============================================================================
// Memory map
// ============================================================================
`define SDRAM_MEM_ADDR_START 32'h80_000_000
`define SDRAM_SIZE (1024*1024*32)
`define SDRAM_MEM_ADDR_END ((`SDRAM_MEM_ADDR_START) + (`SDRAM_SIZE))

`define SPI_NOR_MEM_ADDR_START 32'h20_000_000
`define SPI_MEMORY_OFFSET      (1024*1024*1)
`define SPI_NOR_MEM_ADDR_END   ((`SPI_NOR_MEM_ADDR_START) + (16*1024*1024))
`define RESET_ADDR               (`SPI_NOR_MEM_ADDR_START + `SPI_MEMORY_OFFSET)

`endif  // KIANV_SOC

