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

`default_nettype none `timescale 1ns / 1ps

module mt48lc16m16a2_ctrl #(

    parameter integer SDRAM_CLK_FREQ = 64,

    parameter integer       TRP_NS   = 15,
    parameter integer       TRCD_NS  = 15,
    parameter integer       TCH_NS   = 2,
    parameter         [2:0] CAS      = 3'd2,
    parameter integer       TRFC_NS  = 66,
    parameter integer       TWR_NS   = 15,
    parameter integer       TREFI_NS = 7800,

    parameter integer REF_CREDITS_MAX_DFLT  = 8,
    parameter integer REF_FORCE_THRESH_DFLT = 4,
    parameter integer REF_SOFT_THRESH_DFLT  = 1,

    parameter integer KEEP_OPEN_DFLT = 1,

    parameter integer READ_NEGEDGE_DFLT   = 1,
    parameter integer READ_EXTRA_CYC_DFLT = 0
) (
    input wire clk,
    input wire resetn,

    input  wire [24:0] addr,
    input  wire [31:0] din,
    input  wire [ 3:0] wmask,
    input  wire        valid,
    output reg  [31:0] dout,
    output reg         ready,
    output reg         init_done,

    input  wire        cfg_wr,
    input  wire        cfg_rd,
    input  wire [ 5:0] cfg_addr,
    input  wire [31:0] cfg_wdata,
    output reg  [31:0] cfg_rdata,
    output reg         cfg_done,

    output wire        sdram_clk,
    output wire        sdram_cke,
    output wire [ 1:0] sdram_dqm,
    output wire [12:0] sdram_addr,
    output wire [ 1:0] sdram_ba,
    output wire        sdram_csn,
    output wire        sdram_wen,
    output wire        sdram_rasn,
    output wire        sdram_casn,
    input  wire [15:0] sdram_dq_in,
    output wire [15:0] sdram_dq_out,
    output wire        sdram_dq_oe
);

  function integer ns2cyc;
    input integer ns;
    input integer f_mhz;
    integer num;
    begin
      num = ns * f_mhz + 999;
      ns2cyc = num / 1000;
      if (ns2cyc < 1) ns2cyc = 1;
    end
  endfunction

  localparam integer ONE_US_CYC = SDRAM_CLK_FREQ;
  localparam integer WAIT_200US = 200 * ONE_US_CYC;

  localparam integer TRP_CYC_DFLT = (ns2cyc(
      TRP_NS, SDRAM_CLK_FREQ
  ) < 2) ? 2 : ns2cyc(
      TRP_NS, SDRAM_CLK_FREQ
  );
  localparam integer TRCD_CYC_DFLT = (ns2cyc(
      TRCD_NS, SDRAM_CLK_FREQ
  ) < 2) ? 2 : ns2cyc(
      TRCD_NS, SDRAM_CLK_FREQ
  );
  localparam integer TCH_TMP_DFLT = ns2cyc(TCH_NS, SDRAM_CLK_FREQ);
  localparam integer TMRD_CYC_DFLT = (TCH_TMP_DFLT < 2) ? 2 : TCH_TMP_DFLT;
  localparam integer TRFC_CYC_DFLT = ns2cyc(TRFC_NS, SDRAM_CLK_FREQ);
  localparam integer TWR_CYC_DFLT = ns2cyc(TWR_NS, SDRAM_CLK_FREQ);
  localparam integer TDAL_CYC_DFLT = TWR_CYC_DFLT + TRP_CYC_DFLT;
  localparam integer TREFI_CYC_DFLT = ns2cyc(TREFI_NS, SDRAM_CLK_FREQ);

  localparam [2:0] BURST_LENGTH = 3'b001;
  localparam ACCESS_TYPE = 1'b0;
  localparam [1:0] OP_MODE = 2'b00;
  localparam NO_WRITE_BURST = 1'b0;

  wire [12:0] col_ap = {3'b001, addr[10:2], 1'b0};
  wire [12:0] col_ko = {3'b000, addr[10:2], 1'b0};

  initial begin
    $display("====================================================");
    $display("SDR SDRAM controller @%0d MHz (runtime configurable)", SDRAM_CLK_FREQ);
    $display("Power-up wait               : %0d cycles (200 us)", WAIT_200US);

    $display("--- Default timing (ns -> cycles) -----------------");
    $display("tRP   = %0d ns -> %0d cycles", TRP_NS, TRP_CYC_DFLT);
    $display("tRCD  = %0d ns -> %0d cycles", TRCD_NS, TRCD_CYC_DFLT);
    $display("tRFC  = %0d ns -> %0d cycles", TRFC_NS, TRFC_CYC_DFLT);
    $display("tWR   = %0d ns -> %0d cycles", TWR_NS, TWR_CYC_DFLT);
    $display("tDAL  = tWR+tRP -> %0d cycles", TDAL_CYC_DFLT);
    $display("tMRD  = max(2, %0d) -> %0d cycles", TCH_TMP_DFLT, TMRD_CYC_DFLT);
    $display("tREFI = %0d ns -> %0d cycles", TREFI_NS, TREFI_CYC_DFLT);

    $display("--- Policy / scheduler (defaults) -----------------");
    $display("Row-open policy            : %s",
             (KEEP_OPEN_DFLT != 0) ? "KEEP OPEN" : "CLOSED PAGE");
    $display("Credit max/soft/force      : %0d / %0d / %0d", REF_CREDITS_MAX_DFLT,
             REF_SOFT_THRESH_DFLT, REF_FORCE_THRESH_DFLT);

    $display("Clocking (generic fallback): sdram_clk = ~clk; CAP_READ_NEGEDGE default=%0d",
             READ_NEGEDGE_DFLT);
    $display("See file header for the recommended PLL 0°/180° solution.");

    $display("--- Address mapping -------------------------------");
    $display("bank = addr[22:21]");
    $display("row  = {addr[24:23], addr[20:10]}");
    $display("col  = {addr[10:2], A0=0} (BL=2)");
    $display("====================================================");
  end

  localparam [3:0] CMD_MRS = 4'b0000;
  localparam [3:0] CMD_ACT = 4'b0011;
  localparam [3:0] CMD_READ = 4'b0101;
  localparam [3:0] CMD_WRITE = 4'b0100;
  localparam [3:0] CMD_BST = 4'b0110;
  localparam [3:0] CMD_PRE = 4'b0010;
  localparam [3:0] CMD_REF = 4'b0001;
  localparam [3:0] CMD_NOP = 4'b0111;

  reg [3:0] command, command_nxt;
  reg cke, cke_nxt;
  reg [1:0] dqm, dqm_nxt;
  reg [12:0] saddr, saddr_nxt;
  reg [1:0] ba, ba_nxt;
  reg [15:0] dq, dq_nxt;
  reg oe, oe_nxt;

  assign sdram_clk = ~clk;

  assign sdram_cke   = cke;
  assign sdram_addr  = saddr;
  assign sdram_dqm   = dqm;
  assign {sdram_csn, sdram_rasn, sdram_casn, sdram_wen} = command;
  assign sdram_ba    = ba;
  assign sdram_dq_oe = oe;
  assign sdram_dq_out= dq;

  reg [15:0] dq_negedge;
  always @(negedge clk) begin
    if (!resetn) dq_negedge <= 16'h0000;
    else dq_negedge <= sdram_dq_in;
  end
  wire [15:0] dq_rd;

  reg [2:0] cap_cas_lat, cap_cas_lat_nxt;
  reg cap_read_negedge, cap_read_negedge_nxt;
  reg [3:0] cap_read_extra_cyc, cap_read_extra_cyc_nxt;
  assign dq_rd = (cap_read_negedge) ? dq_negedge : sdram_dq_in;

  localparam RESET = 0;
  localparam ASSERT_CKE = 1;
  localparam INIT_PRE_ALL = 2;
  localparam INIT_REF0 = 3;
  localparam INIT_REF1 = 4;
  localparam INIT_MRS = 5;
  localparam IDLE = 6;
  localparam ACTIVATE = 7;
  localparam PRE_BANK = 8;
  localparam PRE_ALL = 9;
  localparam REFRESH = 10;
  localparam READ_CMD = 11;
  localparam READ_L = 12;
  localparam READ_H = 13;
  localparam WRITE_L = 14;
  localparam WRITE_H = 15;
  localparam WAIT_STATE = 16;

  localparam STATE_W = 5;
  reg [STATE_W-1:0] state, state_nxt;
  reg [STATE_W-1:0] ret_state, ret_state_nxt;
  localparam WAIT_W = 16;
  reg [WAIT_W-1:0] wait_cnt, wait_cnt_nxt;

  reg        ready_nxt;
  reg [31:0] dout_nxt;
  reg update_ready, update_ready_nxt;
  reg init_done_nxt;

  reg [15:0] ref_timer, ref_timer_nxt;
  reg [3:0] ref_credit, ref_credit_nxt;

  wire [ 1:0] cur_bank_w = addr[22:21];
  wire [12:0] cur_row_w = {addr[24:23], addr[20:10]};

  reg [3:0] bank_open_valid, bank_open_valid_nxt;
  reg [12:0] open_row0, open_row1, open_row2, open_row3;
  reg [12:0] open_row0_nxt, open_row1_nxt, open_row2_nxt, open_row3_nxt;

  reg [12:0] open_row_cur;
  always @* begin
    case (cur_bank_w)
      2'd0: open_row_cur = open_row0;
      2'd1: open_row_cur = open_row1;
      2'd2: open_row_cur = open_row2;
      default: open_row_cur = open_row3;
    endcase
  end
  wire same_row_hit = (bank_open_valid[cur_bank_w] == 1'b1) && (open_row_cur == cur_row_w);

  reg [15:0] tim_trp_cyc, tim_trp_cyc_nxt;
  reg [15:0] tim_trcd_cyc, tim_trcd_cyc_nxt;
  reg [15:0] tim_tmrd_cyc, tim_tmrd_cyc_nxt;
  reg [15:0] tim_trfc_cyc, tim_trfc_cyc_nxt;
  reg [15:0] tim_twr_cyc, tim_twr_cyc_nxt;
  reg [15:0] tim_tdal_cyc, tim_tdal_cyc_nxt;
  reg [15:0] tim_trefi_cyc, tim_trefi_cyc_nxt;

  reg pol_keep_open, pol_keep_open_nxt;

  reg [3:0] ref_credits_max, ref_credits_max_nxt;
  reg [3:0] ref_force_thresh, ref_force_thresh_nxt;
  reg [3:0] ref_soft_thresh, ref_soft_thresh_nxt;

  reg ctl_mrs_pulse, ctl_mrs_pulse_nxt;
  reg ctl_reinit_pulse, ctl_reinit_pulse_nxt;

  reg [31:0] cfg_rdata_nxt;
  reg        cfg_done_nxt;

  always @(posedge clk) begin
    if (!resetn) begin
      state              <= RESET;
      ret_state          <= RESET;
      ready              <= 1'b0;
      init_done          <= 1'b0;
      wait_cnt           <= 0;
      dout               <= 32'h0;
      command            <= CMD_NOP;
      dqm                <= 2'b11;
      dq                 <= 16'h0;
      ba                 <= 2'b00;
      oe                 <= 1'b0;
      saddr              <= 13'h0;
      update_ready       <= 1'b0;
      cke                <= 1'b0;
      cfg_rdata          <= 32'h0;
      cfg_done           <= 1'b0;

      ref_timer          <= TREFI_CYC_DFLT[15:0];
      ref_credit         <= 4'd0;

      bank_open_valid    <= 4'b0000;
      open_row0          <= 13'h0000;
      open_row1          <= 13'h0000;
      open_row2          <= 13'h0000;
      open_row3          <= 13'h0000;

      tim_trp_cyc        <= TRP_CYC_DFLT[15:0];
      tim_trcd_cyc       <= TRCD_CYC_DFLT[15:0];
      tim_tmrd_cyc       <= TMRD_CYC_DFLT[15:0];
      tim_trfc_cyc       <= TRFC_CYC_DFLT[15:0];
      tim_twr_cyc        <= TWR_CYC_DFLT[15:0];
      tim_tdal_cyc       <= TDAL_CYC_DFLT[15:0];
      tim_trefi_cyc      <= TREFI_CYC_DFLT[15:0];

      cap_cas_lat        <= CAS[2:0];
      pol_keep_open      <= (KEEP_OPEN_DFLT != 0);
      cap_read_negedge   <= (READ_NEGEDGE_DFLT != 0);
      cap_read_extra_cyc <= READ_EXTRA_CYC_DFLT[3:0];

      ref_credits_max    <= REF_CREDITS_MAX_DFLT[3:0];
      ref_force_thresh   <= REF_FORCE_THRESH_DFLT[3:0];
      ref_soft_thresh    <= REF_SOFT_THRESH_DFLT[3:0];

      ctl_mrs_pulse      <= 1'b0;
      ctl_reinit_pulse   <= 1'b0;

    end else begin
      state              <= state_nxt;
      ret_state          <= ret_state_nxt;
      init_done          <= init_done_nxt;
      ready              <= ready_nxt;
      wait_cnt           <= wait_cnt_nxt;
      dout               <= dout_nxt;
      command            <= command_nxt;
      dqm                <= dqm_nxt;
      dq                 <= dq_nxt;
      ba                 <= ba_nxt;
      oe                 <= oe_nxt;
      saddr              <= saddr_nxt;
      update_ready       <= update_ready_nxt;
      cke                <= cke_nxt;

      ref_timer          <= ref_timer_nxt;
      ref_credit         <= ref_credit_nxt;

      bank_open_valid    <= bank_open_valid_nxt;
      open_row0          <= open_row0_nxt;
      open_row1          <= open_row1_nxt;
      open_row2          <= open_row2_nxt;
      open_row3          <= open_row3_nxt;

      tim_trp_cyc        <= tim_trp_cyc_nxt;
      tim_trcd_cyc       <= tim_trcd_cyc_nxt;
      tim_tmrd_cyc       <= tim_tmrd_cyc_nxt;
      tim_trfc_cyc       <= tim_trfc_cyc_nxt;
      tim_twr_cyc        <= tim_twr_cyc_nxt;
      tim_tdal_cyc       <= tim_tdal_cyc_nxt;
      tim_trefi_cyc      <= tim_trefi_cyc_nxt;

      cap_cas_lat        <= cap_cas_lat_nxt;
      pol_keep_open      <= pol_keep_open_nxt;
      cap_read_negedge   <= cap_read_negedge_nxt;
      cap_read_extra_cyc <= cap_read_extra_cyc_nxt;

      ref_credits_max    <= ref_credits_max_nxt;
      ref_force_thresh   <= ref_force_thresh_nxt;
      ref_soft_thresh    <= ref_soft_thresh_nxt;

      ctl_mrs_pulse      <= ctl_mrs_pulse_nxt;
      ctl_reinit_pulse   <= ctl_reinit_pulse_nxt;

      cfg_rdata          <= cfg_rdata_nxt;
      cfg_done           <= cfg_done_nxt;
    end
  end

  always @* begin

    state_nxt           = state;
    init_done_nxt       = init_done;
    ret_state_nxt       = ret_state;
    ready_nxt           = 1'b0;
    wait_cnt_nxt        = wait_cnt;
    dout_nxt            = dout;
    command_nxt         = CMD_NOP;
    dqm_nxt             = dqm;
    cke_nxt             = cke;
    saddr_nxt           = saddr;
    ba_nxt              = ba;
    dq_nxt              = dq;
    oe_nxt              = 1'b0;
    update_ready_nxt    = update_ready;

    bank_open_valid_nxt = bank_open_valid;
    open_row0_nxt       = open_row0;
    open_row1_nxt       = open_row1;
    open_row2_nxt       = open_row2;
    open_row3_nxt       = open_row3;

    ref_timer_nxt       = (ref_timer != 0) ? (ref_timer - 1'b1) : tim_trefi_cyc;
    ref_credit_nxt      = ref_credit;
    if (ref_timer == 0) begin
      if (ref_credit < ref_credits_max) ref_credit_nxt = ref_credit + 1'b1;
    end

    tim_trp_cyc_nxt        = tim_trp_cyc;
    tim_trcd_cyc_nxt       = tim_trcd_cyc;
    tim_tmrd_cyc_nxt       = tim_tmrd_cyc;
    tim_trfc_cyc_nxt       = tim_trfc_cyc;
    tim_twr_cyc_nxt        = tim_twr_cyc;
    tim_tdal_cyc_nxt       = tim_tdal_cyc;
    tim_trefi_cyc_nxt      = tim_trefi_cyc;

    cap_cas_lat_nxt        = cap_cas_lat;
    pol_keep_open_nxt      = pol_keep_open;
    cap_read_negedge_nxt   = cap_read_negedge;
    cap_read_extra_cyc_nxt = cap_read_extra_cyc;

    ref_credits_max_nxt    = ref_credits_max;
    ref_force_thresh_nxt   = ref_force_thresh;
    ref_soft_thresh_nxt    = ref_soft_thresh;

    ctl_mrs_pulse_nxt      = ctl_mrs_pulse;
    ctl_reinit_pulse_nxt   = ctl_reinit_pulse;

    cfg_done_nxt           = 1'b0;
    cfg_rdata_nxt          = cfg_rdata;

    if (cfg_wr) begin
      case (cfg_addr)
        6'h00:   tim_trp_cyc_nxt = cfg_wdata[15:0];
        6'h01:   tim_trcd_cyc_nxt = cfg_wdata[15:0];
        6'h02:   tim_tmrd_cyc_nxt = (cfg_wdata[15:0] < 16'd2) ? 16'd2 : cfg_wdata[15:0];
        6'h03:   tim_trfc_cyc_nxt = cfg_wdata[15:0];
        6'h04:   tim_twr_cyc_nxt = cfg_wdata[15:0];
        6'h05:   tim_tdal_cyc_nxt = cfg_wdata[15:0];
        6'h06:   tim_trefi_cyc_nxt = cfg_wdata[15:0];
        6'h07: begin
          cap_cas_lat_nxt   = cfg_wdata[2:0];
          ctl_mrs_pulse_nxt = 1'b1;
        end
        6'h08:   pol_keep_open_nxt = cfg_wdata[0];
        6'h09:   cap_read_negedge_nxt = cfg_wdata[0];
        6'h0A:   cap_read_extra_cyc_nxt = cfg_wdata[3:0];
        6'h0B:   ref_credits_max_nxt = cfg_wdata[3:0];
        6'h0C:   ref_force_thresh_nxt = cfg_wdata[3:0];
        6'h0D:   ref_soft_thresh_nxt = cfg_wdata[3:0];
        6'h10: begin
          if (cfg_wdata[0]) ctl_mrs_pulse_nxt = 1'b1;
          if (cfg_wdata[1]) ctl_reinit_pulse_nxt = 1'b1;
        end
        default: ;
      endcase
      cfg_done_nxt = 1'b1;
    end

    if (cfg_rd) begin
      case (cfg_addr)
        6'h00:   cfg_rdata_nxt <= {16'h0, tim_trp_cyc};
        6'h01:   cfg_rdata_nxt <= {16'h0, tim_trcd_cyc};
        6'h02:   cfg_rdata_nxt <= {16'h0, tim_tmrd_cyc};
        6'h03:   cfg_rdata_nxt <= {16'h0, tim_trfc_cyc};
        6'h04:   cfg_rdata_nxt <= {16'h0, tim_twr_cyc};
        6'h05:   cfg_rdata_nxt <= {16'h0, tim_tdal_cyc};
        6'h06:   cfg_rdata_nxt <= {16'h0, tim_trefi_cyc};
        6'h07:   cfg_rdata_nxt <= {29'h0, cap_cas_lat};
        6'h08:   cfg_rdata_nxt <= {31'h0, pol_keep_open};
        6'h09:   cfg_rdata_nxt <= {31'h0, cap_read_negedge};
        6'h0A:   cfg_rdata_nxt <= {28'h0, cap_read_extra_cyc};
        6'h0B:   cfg_rdata_nxt <= {28'h0, ref_credits_max};
        6'h0C:   cfg_rdata_nxt <= {28'h0, ref_force_thresh};
        6'h0D:   cfg_rdata_nxt <= {28'h0, ref_soft_thresh};
        6'h11:   cfg_rdata_nxt <= {31'h0, init_done};
        default: cfg_rdata_nxt <= 32'h0;
      endcase
      cfg_done_nxt = 1'b1;
    end

    case (state)
      RESET: begin
        cke_nxt       = 1'b0;
        wait_cnt_nxt  = WAIT_200US[WAIT_W-1:0];
        ret_state_nxt = ASSERT_CKE;
        state_nxt     = WAIT_STATE;
      end
      ASSERT_CKE: begin
        cke_nxt       = 1'b1;
        wait_cnt_nxt  = 2;
        ret_state_nxt = INIT_PRE_ALL;
        state_nxt     = WAIT_STATE;
      end
      INIT_PRE_ALL: begin
        command_nxt         = CMD_PRE;
        saddr_nxt[10]       = 1'b1;
        wait_cnt_nxt        = tim_trp_cyc;
        bank_open_valid_nxt = 4'b0000;
        ret_state_nxt       = INIT_REF0;
        state_nxt           = WAIT_STATE;
      end
      INIT_REF0: begin
        command_nxt   = CMD_REF;
        wait_cnt_nxt  = tim_trfc_cyc;
        ret_state_nxt = INIT_REF1;
        state_nxt     = WAIT_STATE;
      end
      INIT_REF1: begin
        command_nxt   = CMD_REF;
        wait_cnt_nxt  = tim_trfc_cyc;
        ret_state_nxt = INIT_MRS;
        state_nxt     = WAIT_STATE;
      end
      INIT_MRS: begin
        command_nxt   = CMD_MRS;
        saddr_nxt     = {1'b0, NO_WRITE_BURST, OP_MODE, cap_cas_lat, ACCESS_TYPE, BURST_LENGTH};
        wait_cnt_nxt  = tim_tmrd_cyc;
        ret_state_nxt = IDLE;
        state_nxt     = WAIT_STATE;
      end
      IDLE: begin
        dqm_nxt          = 2'b11;
        update_ready_nxt = 1'b0;
        init_done_nxt    = 1'b1;

        if (ctl_reinit_pulse) begin
          ctl_reinit_pulse_nxt = 1'b0;
          cke_nxt              = 1'b0;
          wait_cnt_nxt         = WAIT_200US[WAIT_W-1:0];
          bank_open_valid_nxt  = 4'b0000;
          ret_state_nxt        = ASSERT_CKE;
          state_nxt            = WAIT_STATE;

        end else if (ctl_mrs_pulse) begin
          if (bank_open_valid != 4'b0000) begin
            command_nxt         = CMD_PRE;
            saddr_nxt[10]       = 1'b1;
            wait_cnt_nxt        = tim_trp_cyc;
            bank_open_valid_nxt = 4'b0000;
            ret_state_nxt       = INIT_MRS;
            state_nxt           = WAIT_STATE;
          end else begin
            state_nxt = INIT_MRS;
          end
          ctl_mrs_pulse_nxt = 1'b0;

        end else if (ref_credit >= ref_force_thresh ||
                    (ref_credit >= ref_soft_thresh && !(valid && !ready))) begin
          if (bank_open_valid != 4'b0000) begin
            command_nxt         = CMD_PRE;
            saddr_nxt[10]       = 1'b1;
            wait_cnt_nxt        = tim_trp_cyc;
            bank_open_valid_nxt = 4'b0000;
            ret_state_nxt       = REFRESH;
            state_nxt           = WAIT_STATE;
          end else begin
            command_nxt    = CMD_REF;
            wait_cnt_nxt   = tim_trfc_cyc;
            ref_credit_nxt = (ref_credit != 0) ? (ref_credit - 1'b1) : 4'd0;
            ret_state_nxt  = IDLE;
            state_nxt      = WAIT_STATE;
          end

        end else if (valid && !ready) begin
          ba_nxt = cur_bank_w;

          if (pol_keep_open) begin
            if (same_row_hit) begin
              if (wmask == 4'b0000) state_nxt = READ_CMD;
              else state_nxt = WRITE_L;
            end else begin
              if (bank_open_valid[cur_bank_w]) begin
                command_nxt   = CMD_PRE;
                saddr_nxt[10] = 1'b0;
                ba_nxt        = cur_bank_w;
                wait_cnt_nxt  = tim_trp_cyc;
                case (cur_bank_w)
                  2'd0: bank_open_valid_nxt[0] = 1'b0;
                  2'd1: bank_open_valid_nxt[1] = 1'b0;
                  2'd2: bank_open_valid_nxt[2] = 1'b0;
                  default: bank_open_valid_nxt[3] = 1'b0;
                endcase
                ret_state_nxt = ACTIVATE;
                state_nxt     = WAIT_STATE;
              end else begin
                state_nxt = ACTIVATE;
              end
            end

          end else begin
            state_nxt = ACTIVATE;
          end
        end
      end

      ACTIVATE: begin
        command_nxt   = CMD_ACT;
        ba_nxt        = cur_bank_w;
        saddr_nxt     = cur_row_w;
        wait_cnt_nxt  = tim_trcd_cyc;
        ret_state_nxt = (wmask == 4'b0000) ? READ_CMD : WRITE_L;

        if (pol_keep_open) begin
          case (cur_bank_w)
            2'd0: begin
              open_row0_nxt = cur_row_w;
              bank_open_valid_nxt[0] = 1'b1;
            end
            2'd1: begin
              open_row1_nxt = cur_row_w;
              bank_open_valid_nxt[1] = 1'b1;
            end
            2'd2: begin
              open_row2_nxt = cur_row_w;
              bank_open_valid_nxt[2] = 1'b1;
            end
            default: begin
              open_row3_nxt = cur_row_w;
              bank_open_valid_nxt[3] = 1'b1;
            end
          endcase
        end
        state_nxt = WAIT_STATE;
      end

      READ_CMD: begin
        command_nxt   = CMD_READ;
        dqm_nxt       = 2'b00;
        ba_nxt        = cur_bank_w;
        saddr_nxt     = pol_keep_open ? col_ko : col_ap;
        wait_cnt_nxt  = cap_cas_lat + cap_read_extra_cyc;
        ret_state_nxt = READ_L;
        state_nxt     = WAIT_STATE;
      end

      READ_L: begin
        dqm_nxt        = 2'b00;
        dout_nxt[15:0] = dq_rd;
        state_nxt      = READ_H;
      end

      READ_H: begin
        dqm_nxt          = 2'b00;
        dout_nxt[31:16]  = dq_rd;
        wait_cnt_nxt     = pol_keep_open ? 16'd1 : tim_trp_cyc;
        update_ready_nxt = 1'b1;
        ret_state_nxt    = IDLE;
        state_nxt        = WAIT_STATE;
      end

      WRITE_L: begin
        command_nxt = CMD_WRITE;
        dqm_nxt     = ~wmask[1:0];
        ba_nxt      = cur_bank_w;
        saddr_nxt   = pol_keep_open ? col_ko : col_ap;
        dq_nxt      = din[15:0];
        oe_nxt      = 1'b1;
        state_nxt   = WRITE_H;
      end

      WRITE_H: begin
        command_nxt      = CMD_NOP;
        dqm_nxt          = ~wmask[3:2];
        ba_nxt           = cur_bank_w;
        saddr_nxt        = pol_keep_open ? col_ko : col_ap;
        dq_nxt           = din[31:16];
        oe_nxt           = 1'b1;

        wait_cnt_nxt     = pol_keep_open ? tim_twr_cyc : tim_tdal_cyc;
        update_ready_nxt = 1'b1;
        ret_state_nxt    = IDLE;
        state_nxt        = WAIT_STATE;
      end

      PRE_BANK: begin
        command_nxt   = CMD_PRE;
        saddr_nxt[10] = 1'b0;
        wait_cnt_nxt  = tim_trp_cyc;
        ret_state_nxt = IDLE;
        state_nxt     = WAIT_STATE;
      end
      PRE_ALL: begin
        command_nxt   = CMD_PRE;
        saddr_nxt[10] = 1'b1;
        wait_cnt_nxt  = tim_trp_cyc;
        ret_state_nxt = IDLE;
        state_nxt     = WAIT_STATE;
      end

      REFRESH: begin
        command_nxt    = CMD_REF;
        wait_cnt_nxt   = tim_trfc_cyc;
        ref_credit_nxt = (ref_credit != 0) ? (ref_credit - 1'b1) : 4'd0;
        ret_state_nxt  = IDLE;
        state_nxt      = WAIT_STATE;
      end

      WAIT_STATE: begin
        command_nxt  = CMD_NOP;
        wait_cnt_nxt = wait_cnt - 1'b1;
        if (wait_cnt == 1) begin
          state_nxt = ret_state;
          if (ret_state == IDLE && update_ready) begin
            update_ready_nxt = 1'b0;
            ready_nxt        = 1'b1;
          end
        end
      end

      default: begin
        state_nxt = IDLE;
      end
    endcase
  end

endmodule

`default_nettype wire
