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
module kianv_harris_mc_edition #(
    parameter RESET_ADDR = 0,
    parameter NUM_ENTRIES_ITLB = 64,
    parameter NUM_ENTRIES_DTLB = 64
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire [15:0] sysclk_mhz_q8_8,
    output wire        mem_valid,
    input  wire        mem_ready,
    output wire [ 3:0] mem_wstrb,
    output wire [33:0] mem_addr,
    output wire [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,
    output wire [31:0] PC,
    input  wire        access_fault,
    input  wire        IRQ3,
    input  wire        IRQ7,
    input  wire        IRQ9,
    input  wire        IRQ11,
    output wire [63:0] timer_counter,
    output wire        is_instruction,
    output wire        icache_flush
);

  wire [                 31:0] Instr;
  wire [                  6:0] op;
  wire [                  2:0] funct3;
  wire [                  6:0] funct7;
  wire [                  0:0] immb10;

  wire                         Zero;

  wire [`RESULT_WIDTH    -1:0] ResultSrc;
  wire [`ALU_CTRL_WIDTH  -1:0] ALUControl;
  wire [`SRCA_WIDTH      -1:0] ALUSrcA;
  wire [`SRCB_WIDTH      -1:0] ALUSrcB;
  wire [                  2:0] ImmSrc;
  wire [`STORE_OP_WIDTH  -1:0] STOREop;
  wire [`LOAD_OP_WIDTH   -1:0] LOADop;
  wire [`MUL_OP_WIDTH    -1:0] MULop;
  wire [`DIV_OP_WIDTH    -1:0] DIVop;
  wire [`CSR_OP_WIDTH    -1:0] CSRop;
  wire                         CSRwe;
  wire                         CSRre;
  wire [                  4:0] Rs1;
  wire [                  4:0] Rs2;
  wire [                  4:0] Rd;

  wire                         RegWrite;
  wire                         PCWrite;
  wire                         AdrSrc;
  wire                         MemWrite;
  wire                         store_instr;
  wire                         incr_inst_retired;
  wire                         ALUOutWrite;

  wire                         mul_valid;
  wire                         mul_ready;
  wire                         div_valid;
  wire                         div_ready;

  assign op     = Instr[6:0];
  assign funct3 = Instr[14:12];
  assign funct7 = Instr[31:25];
  assign Rs1    = Instr[19:15];
  assign Rs2    = Instr[24:20];
  assign Rd     = Instr[11:7];

  wire        amo_temp_write_operation;
  wire        amo_set_reserved_state_load;
  wire        amo_buffered_data;
  wire        amo_buffered_address;
  wire        amo_reserved_state_load;
  wire        muxed_Aluout_or_amo_rd_wr;
  wire        select_ALUResult;
  wire        select_amo_temp;

  wire        exception_event;
  wire [31:0] cause;
  wire [31:0] badaddr;
  wire        mret;
  wire        sret;
  wire        wfi_event;
  wire        csr_access_fault;
  wire [31:0] mstatus;

  wire        IRQ_TO_CPU_CTRL1;
  wire        IRQ_TO_CPU_CTRL3;
  wire        IRQ_TO_CPU_CTRL5;
  wire        IRQ_TO_CPU_CTRL7;
  wire        IRQ_TO_CPU_CTRL9;
  wire        IRQ_TO_CPU_CTRL11;

  wire        page_fault;
  wire        selectPC;
  wire        tlb_flush;
  wire        tlb_flush_csr;
  wire [31:0] satp;
  wire [ 1:0] privilege_mode;

  wire        cpu_mem_ready;
  wire        cpu_mem_valid;

  wire [ 3:0] cpu_mem_wstrb;
  wire [31:0] cpu_mem_addr;
  wire [31:0] cpu_mem_wdata;
  wire [31:0] cpu_mem_rdata;
  wire [31:0] sv32_fault_address;

  wire [ 1:0] addr_align_bits;

  wire        stall;

  wire        mstatus_tvm = `GET_MSTATUS_TVM(mstatus);
  wire        mstatus_tw = `GET_MSTATUS_TW(mstatus);
  wire        mstatus_tsr = `GET_MSTATUS_TSR(mstatus);

  control_unit control_unit_I (
      .clk               (clk),
      .resetn            (resetn),
      .op                (op),
      .funct3            (funct3),
      .funct7            (funct7),
      .immb10            (immb10),
      .Zero              (Zero),
      .Rs1               (Rs1),
      .Rs2               (Rs2),
      .Rd                (Rd),
      .ResultSrc         (ResultSrc),
      .ALUControl        (ALUControl),
      .ALUSrcA           (ALUSrcA),
      .ALUSrcB           (ALUSrcB),
      .ImmSrc            (ImmSrc),
      .STOREop           (STOREop),
      .LOADop            (LOADop),
      .CSRop             (CSRop),
      .CSRwe             (CSRwe),
      .CSRre             (CSRre),
      .RegWrite          (RegWrite),
      .PCWrite           (PCWrite),
      .AdrSrc            (AdrSrc),
      .fault_address     (sv32_fault_address),
      .mstatus_tsr_tw_tvm({mstatus_tsr, mstatus_tw, mstatus_tvm}),

      .satp_mode(`GET_SATP_MODE(satp) == 1'b1),

      .MemWrite         (MemWrite),
      .store_instr      (store_instr),
      .is_instruction   (is_instruction),
      .stall            (stall),
      .incr_inst_retired(incr_inst_retired),
      .ALUOutWrite      (ALUOutWrite),
      .mem_valid        (cpu_mem_valid),
      .mem_ready        (cpu_mem_ready),
      .cpu_mem_addr     (cpu_mem_addr),
      .MULop            (MULop),
      .access_fault     (access_fault),
      .page_fault       (page_fault),
      .selectPC         (selectPC),
      .tlb_flush        (tlb_flush),
      .icache_flush     (icache_flush),

      .mul_valid(mul_valid),
      .mul_ready(mul_ready),
      .DIVop    (DIVop),
      .div_valid(div_valid),
      .div_ready(div_ready),

      .amo_temp_write_operation   (amo_temp_write_operation),
      .amo_set_reserved_state_load(amo_set_reserved_state_load),
      .amo_buffered_data          (amo_buffered_data),
      .amo_buffered_address       (amo_buffered_address),
      .amo_reserved_state_load    (amo_reserved_state_load),
      .muxed_Aluout_or_amo_rd_wr  (muxed_Aluout_or_amo_rd_wr),
      .select_ALUResult           (select_ALUResult),
      .select_amo_temp            (select_amo_temp),

      .exception_event (exception_event),
      .cause           (cause),
      .badaddr         (badaddr),
      .mret            (mret),
      .sret            (sret),
      .wfi_event       (wfi_event),
      .privilege_mode  (privilege_mode),
      .csr_access_fault(csr_access_fault),

      .IRQ_TO_CPU_CTRL1 (IRQ_TO_CPU_CTRL1),
      .IRQ_TO_CPU_CTRL3 (IRQ_TO_CPU_CTRL3),
      .IRQ_TO_CPU_CTRL5 (IRQ_TO_CPU_CTRL5),
      .IRQ_TO_CPU_CTRL7 (IRQ_TO_CPU_CTRL7),
      .IRQ_TO_CPU_CTRL9 (IRQ_TO_CPU_CTRL9),
      .IRQ_TO_CPU_CTRL11(IRQ_TO_CPU_CTRL11)
  );

  datapath_unit #(
      .RESET_ADDR(RESET_ADDR)
  ) datapath_unit_I (
      .clk            (clk),
      .resetn         (resetn),
      .sysclk_mhz_q8_8(sysclk_mhz_q8_8),

      .ResultSrc (ResultSrc),
      .ALUControl(ALUControl),
      .ALUSrcA   (ALUSrcA),
      .ALUSrcB   (ALUSrcB),
      .ImmSrc    (ImmSrc),
      .STOREop   (STOREop),
      .LOADop    (LOADop),
      .CSRop     (CSRop),
      .CSRwe     (CSRwe),
      .CSRre     (CSRre),
      .Zero      (Zero),
      .immb10    (immb10),

      .RegWrite         (RegWrite),
      .PCWrite          (PCWrite),
      .AdrSrc           (AdrSrc),
      .MemWrite         (MemWrite),
      .incr_inst_retired(incr_inst_retired),
      .store_instr      (store_instr),
      .ALUOutWrite      (ALUOutWrite),
      .Instr            (Instr),

      .mem_wstrb(cpu_mem_wstrb),
      .mem_addr (cpu_mem_addr),
      .mem_wdata(cpu_mem_wdata),
      .mem_rdata(cpu_mem_rdata),

      .MULop      (MULop),
      .mul_valid  (mul_valid),
      .mul_ready  (mul_ready),
      .DIVop      (DIVop),
      .div_valid  (div_valid),
      .div_ready  (div_ready),
      .ProgCounter(PC),

      .amo_temp_write_operation   (amo_temp_write_operation),
      .amo_set_reserved_state_load(amo_set_reserved_state_load),
      .amo_buffered_data          (amo_buffered_data),
      .amo_buffered_address       (amo_buffered_address),
      .amo_reserved_state_load    (amo_reserved_state_load),
      .muxed_Aluout_or_amo_rd_wr  (muxed_Aluout_or_amo_rd_wr),
      .select_ALUResult           (select_ALUResult),
      .select_amo_temp            (select_amo_temp),

      .exception_event (exception_event),
      .cause           (cause),
      .badaddr         (badaddr),
      .mret            (mret),
      .sret            (sret),
      .wfi_event       (wfi_event),
      .privilege_mode  (privilege_mode),
      .csr_access_fault(csr_access_fault),
      .mstatus         (mstatus),
      .satp            (satp),
      .tlb_flush       (tlb_flush_csr),
      .timer_counter   (timer_counter),
      .page_fault      (page_fault),
      .selectPC        (selectPC),

      .IRQ3             (IRQ3),
      .IRQ7             (IRQ7),
      .IRQ9             (IRQ9),
      .IRQ11            (IRQ11),
      .IRQ_TO_CPU_CTRL1 (IRQ_TO_CPU_CTRL1),
      .IRQ_TO_CPU_CTRL3 (IRQ_TO_CPU_CTRL3),
      .IRQ_TO_CPU_CTRL5 (IRQ_TO_CPU_CTRL5),
      .IRQ_TO_CPU_CTRL7 (IRQ_TO_CPU_CTRL7),
      .IRQ_TO_CPU_CTRL9 (IRQ_TO_CPU_CTRL9),
      .IRQ_TO_CPU_CTRL11(IRQ_TO_CPU_CTRL11)
  );

  sv32 #(
      .NUM_ENTRIES_ITLB(`NUM_ENTRIES_ITLB),
      .NUM_ENTRIES_DTLB(`NUM_ENTRIES_DTLB)
  ) mmu_I (
      .clk   (clk),
      .resetn(resetn),

      .cpu_valid(cpu_mem_valid),
      .cpu_ready(cpu_mem_ready),
      .cpu_wstrb(cpu_mem_wstrb),
      .cpu_addr (cpu_mem_addr),
      .cpu_wdata(cpu_mem_wdata),
      .cpu_rdata(cpu_mem_rdata),

      .mem_valid    (mem_valid),
      .mem_ready    (mem_ready),
      .mem_wstrb    (mem_wstrb),
      .mem_addr     (mem_addr),
      .mem_wdata    (mem_wdata),
      .mem_rdata    (mem_rdata),
      .fault_address(sv32_fault_address),

      .privilege_mode(privilege_mode),
      .is_instruction(is_instruction),
      .tlb_flush     (tlb_flush | tlb_flush_csr),
      .stall         (stall),
      .satp          (satp),
      .mstatus       (mstatus),
      .page_fault    (page_fault)
  );

endmodule
