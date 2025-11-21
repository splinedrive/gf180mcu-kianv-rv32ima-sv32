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
`include "riscv_defines.vh"

module sv32 #(
    parameter NUM_ENTRIES_ITLB = 64,
    parameter NUM_ENTRIES_DTLB = 64
) (
    input wire clk,
    input wire resetn,

    input  wire        cpu_valid,
    output reg         cpu_ready,
    input  wire [ 3:0] cpu_wstrb,
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    output reg  [31:0] cpu_rdata,

    output reg         mem_valid,
    input  wire        mem_ready,
    output reg  [ 3:0] mem_wstrb,
    output reg  [33:0] mem_addr,
    output reg  [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,

    input  wire is_instruction,
    input  wire tlb_flush,
    output reg  stall,

    input  wire [31:0] satp,
    input  wire [31:0] mstatus,
    input  wire [ 1:0] privilege_mode,
    output reg  [31:0] fault_address,
    output reg         page_fault
);

  localparam STATE_IDLE = 0, STATE_TRANSLATE = 1, STATE_ACCESS = 2, STATE_LAST = 3;
  localparam STATE_WIDTH = $clog2(STATE_LAST);

  reg [STATE_WIDTH-1:0] state_q, state_d;

  wire [33:0] data_phys_addr;
  reg         data_translate_valid;
  wire        data_translate_ready;
  wire        data_page_fault;

  wire [33:0] instr_phys_addr;
  reg         instr_translate_valid;
  wire        instr_translate_ready;
  wire        instr_page_fault;

  wire [31:0] pte_entry;

  wire        ptw_valid;
  wire        ptw_ready;
  wire        ptw_mem_valid;
  reg         ptw_mem_ready;
  wire [31:0] ptw_mem_addr;
  reg  [31:0] ptw_mem_rdata;

  wire        instr_ptw_valid;
  wire        instr_ptw_ready;
  wire        data_ptw_valid;
  wire        data_ptw_ready;

  reg         cpu_valid_q;
  reg  [ 3:0] cpu_wstrb_q;
  reg  [31:0] cpu_addr_q;
  reg  [31:0] cpu_wdata_q;
  reg  [31:0] satp_q;
  reg  [31:0] mstatus_q;
  reg  [ 1:0] priv_mode_q;
  reg         is_instr_q;

  wire        translation_start;
  wire        translation_done;
  wire        any_page_fault;

  assign translation_start = cpu_valid && (state_q == STATE_IDLE) && !page_fault;
  assign translation_done  = instr_translate_ready || data_translate_ready;
  assign any_page_fault    = instr_page_fault || data_page_fault;

  always @(posedge clk) begin
    if (!resetn) begin
      page_fault    <= 1'b0;
      fault_address <= 32'b0;
    end else begin
      page_fault <= any_page_fault;
      if (any_page_fault) fault_address <= cpu_addr_q;
    end
  end

  always @(posedge clk) begin
    if (!resetn) begin
      cpu_valid_q           <= 1'b0;
      cpu_wstrb_q           <= 4'd0;
      cpu_addr_q            <= 32'd0;
      cpu_wdata_q           <= 32'd0;
      satp_q                <= 32'd0;
      mstatus_q             <= 32'd0;
      priv_mode_q           <= 2'd0;
      is_instr_q            <= 1'b0;
      instr_translate_valid <= 1'b0;
      data_translate_valid  <= 1'b0;
    end else begin
      if (translation_start) begin
        cpu_valid_q           <= cpu_valid;
        cpu_wstrb_q           <= cpu_wstrb;
        cpu_addr_q            <= cpu_addr;
        cpu_wdata_q           <= cpu_wdata;
        satp_q                <= satp;
        mstatus_q             <= mstatus;
        priv_mode_q           <= privilege_mode;
        is_instr_q            <= is_instruction;
        instr_translate_valid <= is_instruction;
        data_translate_valid  <= !is_instruction;
      end else if (translation_done) begin
        instr_translate_valid <= 1'b0;
        data_translate_valid  <= 1'b0;
      end
    end
  end

  always @(*) begin
    state_d = state_q;
    case (state_q)
      STATE_IDLE: state_d = translation_start ? STATE_TRANSLATE : STATE_IDLE;
      STATE_TRANSLATE:
      state_d = any_page_fault ? STATE_IDLE : (translation_done ? STATE_ACCESS : STATE_TRANSLATE);
      STATE_ACCESS: state_d = mem_ready ? STATE_IDLE : STATE_ACCESS;
      default: state_d = STATE_IDLE;
    endcase
  end

  always @(posedge clk)
    if (!resetn) state_q <= STATE_IDLE;
    else state_q <= state_d;

  wire [33:0] selected_phys_addr = is_instr_q ? instr_phys_addr : data_phys_addr;

  always @(*) begin

    stall         = 1'b0;
    cpu_ready     = 1'b0;
    cpu_rdata     = 32'b0;
    mem_valid     = 1'b0;
    mem_addr      = 34'b0;
    mem_wstrb     = 4'b0;
    mem_wdata     = 32'b0;
    ptw_mem_ready = 1'b0;
    ptw_mem_rdata = 32'b0;

    case (state_q)
      STATE_IDLE: begin
        cpu_ready = 1'b0;
      end

      STATE_TRANSLATE: begin
        stall         = 1'b1;
        mem_addr      = {2'b00, ptw_mem_addr};
        mem_wstrb     = 4'b0000;
        mem_valid     = ptw_mem_valid;
        ptw_mem_ready = mem_ready;
        ptw_mem_rdata = mem_rdata;

        if (translation_done && !any_page_fault) begin
          mem_addr  = selected_phys_addr;
          mem_wstrb = cpu_wstrb_q;
          mem_wdata = cpu_wdata_q;
          cpu_rdata = mem_rdata;
          mem_valid = cpu_valid_q;
          cpu_ready = mem_ready;
        end
      end

      STATE_ACCESS: begin
        mem_addr  = selected_phys_addr;
        mem_wstrb = cpu_wstrb_q;
        mem_wdata = cpu_wdata_q;
        cpu_rdata = mem_rdata;
        mem_valid = cpu_valid_q;
        cpu_ready = mem_ready;
      end
    endcase
  end

  assign ptw_valid       = is_instr_q ? instr_ptw_valid : data_ptw_valid;
  assign instr_ptw_ready = is_instr_q && ptw_ready;
  assign data_ptw_ready  = !is_instr_q && ptw_ready;

  sv32_table_walk #(
      .NUM_ENTRIES_ITLB(`NUM_ENTRIES_ITLB),
      .NUM_ENTRIES_DTLB(`NUM_ENTRIES_DTLB),
      .ITLB_WAYS       (4),
      .DTLB_WAYS       (4)
  ) ptw_inst (
      .clk           (clk),
      .resetn        (resetn),
      .address       (cpu_addr_q),
      .satp          (satp_q),
      .pte           (pte_entry),
      .is_instruction(is_instr_q),
      .tlb_flush     (tlb_flush),
      .valid         (ptw_valid),
      .ready         (ptw_ready),
      .walk_mem_valid(ptw_mem_valid),
      .walk_mem_ready(ptw_mem_ready),
      .walk_mem_addr (ptw_mem_addr),
      .walk_mem_rdata(ptw_mem_rdata)
  );

  sv32_translate_instruction_to_physical instr_translator (
      .clk             (clk),
      .resetn          (resetn),
      .address         (cpu_addr_q),
      .satp_sv32_mode  (satp_q[31]),
      .physical_address(instr_phys_addr),
      .page_fault      (instr_page_fault),
      .privilege_mode  (priv_mode_q),
      .valid           (instr_translate_valid),
      .ready           (instr_translate_ready),
      .walk_valid      (instr_ptw_valid),
      .walk_ready      (instr_ptw_ready),
      .pte             (pte_entry)
  );

  sv32_translate_data_to_physical data_translator (
      .clk             (clk),
      .resetn          (resetn),
      .address         (cpu_addr_q),
      .satp_sv32_mode  (satp_q[31]),
      .physical_address(data_phys_addr),
      .is_write        (|cpu_wstrb_q),
      .page_fault      (data_page_fault),
      .privilege_mode  (priv_mode_q),
      .mstatus         (mstatus_q),
      .valid           (data_translate_valid),
      .ready           (data_translate_ready),
      .walk_valid      (data_ptw_valid),
      .walk_ready      (data_ptw_ready),
      .pte_            (pte_entry)
  );

endmodule
