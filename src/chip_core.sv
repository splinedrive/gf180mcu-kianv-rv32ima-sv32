// SPDX-FileCopyrightText: © 2025 hirosh@dabui.de Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none

module chip_core #(
    parameter NUM_BIDIR_PADS = 54  // unified bidirectional pads (53 used, 1 spare)
)(
    input  logic clk,       // system clock
    input  logic rst_n,     // reset (active low)
`ifdef USE_POWER_PINS
     inout VDD,
     inout VSS,
`endif
    // Unified bidirectional pad bus
    input  wire  [NUM_BIDIR_PADS-1:0] bidir_in,
    output wire  [NUM_BIDIR_PADS-1:0] bidir_out,
    output wire  [NUM_BIDIR_PADS-1:0] bidir_oe,
    output wire  [NUM_BIDIR_PADS-1:0] bidir_cs,
    output wire  [NUM_BIDIR_PADS-1:0] bidir_sl,
    output wire  [NUM_BIDIR_PADS-1:0] bidir_ie,
    output wire  [NUM_BIDIR_PADS-1:0] bidir_pu,
    output wire  [NUM_BIDIR_PADS-1:0] bidir_pd
);
    // ============================================================
    // Pad Configuration Defaults (GF180 standard)
    // ============================================================
    assign bidir_cs = '0;   // CMOS input type
    assign bidir_sl = '0;   // fast slew
    assign bidir_pu = '0;   // no pull-up
    assign bidir_pd = '0;   // no pull-down

    // ============================================================
    // Pad index mapping - Single UART, reordered for clarity
    // Inputs: 0-3, Outputs: 4-13, SDRAM: 14-52, Reserved: 53
    // ============================================================
    localparam UART_RX_IDX    = 0;
    localparam SPI0_MISO_IDX  = 1;
    localparam FLASH_MISO_IDX = 2;
    localparam SPI1_MISO_IDX  = 3;

    localparam UART_TX_IDX    = 4;
    localparam SPI0_CSN_IDX   = 5;
    localparam SPI0_SCLK_IDX  = 6;
    localparam SPI0_MOSI_IDX  = 7;
    localparam FLASH_CSN_IDX  = 8;
    localparam FLASH_SCLK_IDX = 9;
    localparam FLASH_MOSI_IDX = 10;
    localparam SPI1_CSN_IDX   = 11;
    localparam SPI1_SCLK_IDX  = 12;
    localparam SPI1_MOSI_IDX  = 13;

    // SDRAM: indices 14-52 (control 14-36, DQ 37-52)
    localparam SDRAM_BASE_IDX = 14;

    // ============================================================
    // Pad index mapping - add GPIO
    // ============================================================
    localparam GPIO0_IDX = 53;

    // ============================================================
    // Tie unused output bits (input-only pads) to zero
    // ============================================================
    assign bidir_out[UART_RX_IDX]    = 1'b0;
    assign bidir_out[SPI0_MISO_IDX]  = 1'b0;
    assign bidir_out[FLASH_MISO_IDX] = 1'b0;
    assign bidir_out[SPI1_MISO_IDX]  = 1'b0;


    // ============================================================
    // SDRAM internal nets - 16-bit
    // ============================================================
    wire [15:0] sdram_dq_out;
    wire [15:0] sdram_dq_in;
    wire        sdram_dq_oe;

    // ============================================================
    // GPIO internal nets - 1-bit
    // ============================================================
    wire  gpio_out;
    wire  gpio_in;
    wire  gpio_oe;

    // ============================================================
    // SoC instance - Single UART
    // ============================================================
    soc #(
        //.NUM_UARTS(1)
    ) u_soc (
        .clk_osc (clk),
        .ext_resetn (rst_n),
`ifdef USE_POWER_PINS
        .VDD    (VDD),
        .VSS    (VSS),
`endif
        // Single UART
        .uart_tx (bidir_out[UART_TX_IDX]),
        .uart_rx (bidir_in [UART_RX_IDX]),
        // SPI0
        .spi_cen0          (bidir_out[SPI0_CSN_IDX]),
        .spi_sclk0         (bidir_out[SPI0_SCLK_IDX]),
        .spi_sio1_so_miso0 (bidir_in [SPI0_MISO_IDX]),
        .spi_sio0_si_mosi0 (bidir_out[SPI0_MOSI_IDX]),
        // External flash
        .flash_csn  (bidir_out[FLASH_CSN_IDX]),
        .flash_sclk (bidir_out[FLASH_SCLK_IDX]),
        .flash_miso (bidir_in [FLASH_MISO_IDX]),
        .flash_mosi (bidir_out[FLASH_MOSI_IDX]),
        // SPI1 / Network
        .spi_cen1          (bidir_out[SPI1_CSN_IDX]),
        .spi_sclk1         (bidir_out[SPI1_SCLK_IDX]),
        .spi_sio1_so_miso1 (bidir_in [SPI1_MISO_IDX]),
        .spi_sio0_si_mosi1 (bidir_out[SPI1_MOSI_IDX]),
        // SDRAM interface - 16-bit
        .sdram_clk    (bidir_out[SDRAM_BASE_IDX + 0]),
        .sdram_cke    (bidir_out[SDRAM_BASE_IDX + 1]),
        .sdram_dqm    (bidir_out[SDRAM_BASE_IDX + 3:SDRAM_BASE_IDX + 2]),
        .sdram_addr   (bidir_out[SDRAM_BASE_IDX + 16:SDRAM_BASE_IDX + 4]),
        .sdram_ba     (bidir_out[SDRAM_BASE_IDX + 18:SDRAM_BASE_IDX + 17]),
        .sdram_csn    (bidir_out[SDRAM_BASE_IDX + 19]),
        .sdram_wen    (bidir_out[SDRAM_BASE_IDX + 20]),
        .sdram_rasn   (bidir_out[SDRAM_BASE_IDX + 21]),
        .sdram_casn   (bidir_out[SDRAM_BASE_IDX + 22]),
        .sdram_dq_out (sdram_dq_out),
        .sdram_dq_in  (sdram_dq_in),
        .sdram_dq_oe  (sdram_dq_oe),
        .gpio_in  (gpio_in),
        .gpio_out (gpio_out),
        .gpio_oe  (gpio_oe)
    );

    // ============================================================
    // Output enable (OE) and input enable (IE)
    // ============================================================
    logic [NUM_BIDIR_PADS-1:0] bidir_oe_i;
    assign bidir_oe = bidir_oe_i;

    always_comb begin
        bidir_oe_i = '0;
        // Static output pads
        bidir_oe_i[UART_TX_IDX]    = 1'b1;
        bidir_oe_i[SPI0_CSN_IDX]   = 1'b1;
        bidir_oe_i[SPI0_SCLK_IDX]  = 1'b1;
        bidir_oe_i[SPI0_MOSI_IDX]  = 1'b1;
        bidir_oe_i[FLASH_CSN_IDX]  = 1'b1;
        bidir_oe_i[FLASH_SCLK_IDX] = 1'b1;
        bidir_oe_i[FLASH_MOSI_IDX] = 1'b1;
        bidir_oe_i[SPI1_CSN_IDX]   = 1'b1;
        bidir_oe_i[SPI1_SCLK_IDX]  = 1'b1;
        bidir_oe_i[SPI1_MOSI_IDX]  = 1'b1;
        // SDRAM control/address (static)
        bidir_oe_i[SDRAM_BASE_IDX +: 23] = '1;
        // SDRAM DQ bus (dynamic) - 16 bits
        for (int dq = 0; dq < 16; dq++) begin
            bidir_oe_i[SDRAM_BASE_IDX + 23 + dq] = sdram_dq_oe;
        end
        // GPIO - dynamic direction
        bidir_oe_i[GPIO0_IDX] = gpio_oe;
    end

    // SDRAM DQ connections - 16 bits
    for (genvar dq = 0; dq < 16; dq++) begin : sdram_dq_map
        assign bidir_out[SDRAM_BASE_IDX + 23 + dq] = sdram_dq_out[dq];
        assign sdram_dq_in[dq]                     = bidir_in[SDRAM_BASE_IDX + 23 + dq];
    end

   // GPIO pad mapping
    assign bidir_out[GPIO0_IDX] = gpio_out;
    assign gpio_in              = bidir_in[GPIO0_IDX];

    // Everything else is input
    assign bidir_ie = ~bidir_oe_i;
endmodule
`default_nettype wire
