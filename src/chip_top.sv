// SPDX-FileCopyrightText: © 2025 Project Template Contributors
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module chip_top #(
    // Power/ground pads for core and I/O
    parameter NUM_DVDD_PADS = 8,
    parameter NUM_DVSS_PADS = 10,

    // Unified bidirectional signal pads
    // 54 used by chip_core
    parameter NUM_BIDIR = 54
    )(
    `ifdef USE_POWER_PINS
    inout  wire VDD,
    inout  wire VSS,
    `endif

    inout  wire       clk_PAD,
    inout  wire       rst_n_PAD,

    inout  wire [NUM_BIDIR-1:0] bidir_PAD
);

    // ============================================================
    // Internal pad-side nets
    // ============================================================
    wire clk_PAD2CORE;
    wire rst_n_PAD2CORE;

    wire [NUM_BIDIR-1:0] bidir_PAD2CORE;
    wire [NUM_BIDIR-1:0] bidir_CORE2PAD;
    wire [NUM_BIDIR-1:0] bidir_CORE2PAD_OE;
    wire [NUM_BIDIR-1:0] bidir_CORE2PAD_CS;
    wire [NUM_BIDIR-1:0] bidir_CORE2PAD_SL;
    wire [NUM_BIDIR-1:0] bidir_CORE2PAD_IE;
    wire [NUM_BIDIR-1:0] bidir_CORE2PAD_PU;
    wire [NUM_BIDIR-1:0] bidir_CORE2PAD_PD;

    // ============================================================
    // Power / ground pad instances
    // ============================================================
    generate
        for (genvar i = 0; i < NUM_DVDD_PADS; i++) begin : dvdd_pads
            (* keep *)
            gf180mcu_ws_io__dvdd pad (
            `ifdef USE_POWER_PINS
                .DVDD   (VDD),
                .DVSS   (VSS),
                .VSS    (VSS)
            `endif
            );
        end

        for (genvar i = 0; i < NUM_DVSS_PADS; i++) begin : dvss_pads
            (* keep *)
            gf180mcu_ws_io__dvss pad (
            `ifdef USE_POWER_PINS
                .DVDD   (VDD),
                .DVSS   (VSS),
                .VDD    (VDD)
            `endif
            );
        end
    endgenerate

    // ============================================================
    // Signal IO pad instances
    // ============================================================

    // Clock pad: Schmitt trigger input
    gf180mcu_fd_io__in_s clk_pad (
        `ifdef USE_POWER_PINS
        .DVDD   (VDD),
        .DVSS   (VSS),
        .VDD    (VDD),
        .VSS    (VSS),
        `endif

        .Y      (clk_PAD2CORE),
        .PAD    (clk_PAD),

        .PU     (1'b0),
        .PD     (1'b0)
    );

    // Reset pad: normal CMOS input
    gf180mcu_fd_io__in_c rst_n_pad (
        `ifdef USE_POWER_PINS
        .DVDD   (VDD),
        .DVSS   (VSS),
        .VDD    (VDD),
        .VSS    (VSS),
        `endif

        .Y      (rst_n_PAD2CORE),
        .PAD    (rst_n_PAD),

        .PU     (1'b0),
        .PD     (1'b0)
    );

    // Unified bidirectional pads
    generate
        for (genvar i = 0; i < NUM_BIDIR; i++) begin : bidir
            (* keep *)
            gf180mcu_fd_io__bi_24t pad (
                `ifdef USE_POWER_PINS
                .DVDD   (VDD),
                .DVSS   (VSS),
                .VDD    (VDD),
                .VSS    (VSS),
                `endif

                .A      (bidir_CORE2PAD[i]),
                .OE     (bidir_CORE2PAD_OE[i]),
                .Y      (bidir_PAD2CORE[i]),
                .PAD    (bidir_PAD[i]),

                .CS     (bidir_CORE2PAD_CS[i]),
                .SL     (bidir_CORE2PAD_SL[i]),
                .IE     (bidir_CORE2PAD_IE[i]),

                .PU     (bidir_CORE2PAD_PU[i]),
                .PD     (bidir_CORE2PAD_PD[i])
            );
        end
    endgenerate

    // ============================================================
    // Core instance
    // ============================================================
    chip_core #(
        .NUM_BIDIR (NUM_BIDIR)
    ) i_chip_core (
        .clk        (clk_PAD2CORE),
        .rst_n      (rst_n_PAD2CORE),
`ifdef USE_POWER_PINS
        .VDD    (VDD),
        .VSS    (VSS),
`endif

        .bidir_in   (bidir_PAD2CORE),
        .bidir_out  (bidir_CORE2PAD),
        .bidir_oe   (bidir_CORE2PAD_OE),
        .bidir_cs   (bidir_CORE2PAD_CS),
        .bidir_sl   (bidir_CORE2PAD_SL),
        .bidir_ie   (bidir_CORE2PAD_IE),
        .bidir_pu   (bidir_CORE2PAD_PU),
        .bidir_pd   (bidir_CORE2PAD_PD)
    );

    // ============================================================
    // Fixed macros
    // ============================================================

    // Chip ID - do not remove, necessary for tapeout
    (* keep *)
    gf180mcu_ws_ip__id chip_id ();

    // wafer.space logo - can be removed
    (* keep *)
    gf180mcu_ws_ip__logo wafer_space_logo ();

    (* keep *)
    gf180mcu_ws_ip__names names ();
    
    (* keep *)
    gf180mcu_ws_ip__credits credits ();

endmodule

`default_nettype wire
