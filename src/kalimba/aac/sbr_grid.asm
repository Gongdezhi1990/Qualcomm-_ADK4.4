// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_SBR_ADDITIONS

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.sbr_grid
//
// DESCRIPTION:
//    Get information about how the current SBR frame is subdivided
//
// INPUTS:
//    - r5 ch
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r4, r6-r8, r10, I1, I4
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_grid;
   .CODESEGMENT AACDEC_SBR_GRID_PM;
   .DATASEGMENT DM;


   $aacdec.sbr_grid:

   // push rLink onto stack
   push rLink;

   // SBR_bs_frame_class
   call $aacdec.get2bits;
   M[($aacdec.sbr_np_info + $aacdec.SBR_bs_frame_class) + r5] = r1;

   // switch(SBR_bs_frame_class)
   Null = r1 - $aacdec.SBR_FIXFIX;
   if NZ jump not_fixfix;
      // case FIXFIX
      call $aacdec.get2bits;
      r10 = 1 LSHIFT r1;
      // SBR_bs_num_env[ch] = min(r0, 5)
      r1 = r10 - 5;
      if GT r10 = r10 - r1;
      M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5] = r10;
      r8 = r10;

      // read 1 bit
      call $aacdec.get1bit;

      r0 = r5 * 6 (int);
      I1 = r0 + (&$aacdec.sbr_info + $aacdec.SBR_bs_freq_res);

      // for 1:SBR_bs_num_env[ch]

      do fixfix_bs_freq_res_loop;
         M[I1, 1] = r1;
      fixfix_bs_freq_res_loop:

      // SBR_abs_bord_lead[ch] = 0
      M[($aacdec.tmp_mem_pool + $aacdec.SBR_abs_bord_lead) + r5] = Null;
      // SBR_abs_bord_trail[ch] = SBR_numTimeSlots
      r1 = $aacdec.SBR_numTimeSlots;
      M[($aacdec.tmp_mem_pool + $aacdec.SBR_abs_bord_trail) + r5] = r1;

      jump end_switch_bs_frame_class;
   not_fixfix:
   Null = r1 - $aacdec.SBR_FIXVAR;
   if NZ jump not_fixvar;
      // case FIXVAR

      // SBR_abs_bord_trail[ch] = SBR_bs_var_bord_1[ch] ...
      //                          + SBR_numTimeSlots
      // read 2 bits
      call $aacdec.get2bits;
      r1 = r1 + $aacdec.SBR_numTimeSlots;
      M[($aacdec.tmp_mem_pool + $aacdec.SBR_abs_bord_trail) + r5] = r1;

      // SBR_bs_num_env[ch] = SBR_bs_num_rel_1[ch] + 1
      // read 2 bits
      call $aacdec.get2bits;
      r8 = r1 + 1;
      M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5] = r8;

      r4 = r5 * 5 (int);
      I1 = (&$aacdec.tmp_mem_pool + $aacdec.SBR_bs_rel_bord) + r4;
      I4 = (&$aacdec.tmp_mem_pool + $aacdec.SBR_bs_rel_bord_1) + r4;

      // SBR_bs_num_env[ch] - 1
      r10 = r1;

      do fixvar_rel_bord_loop;
         // read 2 bits
         call $aacdec.get2bits;
         r1 = r1 LSHIFT 1;
         r1 = r1 + 2;
         M[I1, 1] = r1,
          M[I4, 1] = r1;
      fixvar_rel_bord_loop:

      // ptr_bits = SBR_log2Table[SBR_bs_num_env[ch]]
      r0 = M[($aacdec.SBR_log2Table+1) + r8];
      // SBR_bs_pointer[ch] = getbits(ptr_bits)
      call $aacdec.getbits;
      M[($aacdec.sbr_np_info + $aacdec.SBR_bs_pointer) + r5] = r1;

      r0 = r5 * 6 (int);
      r0 = r0 +  (&$aacdec.sbr_info + $aacdec.SBR_bs_freq_res);

      r10 = r8;
      I1 = r0 + r8;
      I1 = I1 - 1;

      do fixvar_bs_freq_res_loop;
         call $aacdec.get1bit;
         M[I1, -1] = r1;
      fixvar_bs_freq_res_loop:

      M[($aacdec.tmp_mem_pool + $aacdec.SBR_abs_bord_lead) + r5] = Null;

      jump end_switch_bs_frame_class;
   not_fixvar:
   Null = r1 - $aacdec.SBR_VARFIX;
   if NZ jump not_varfix;
      // case VARFIX

      // SBR_abs_bord_lead[ch] = getbits(2)
      // read 2 bits
      call $aacdec.get2bits;
      M[($aacdec.tmp_mem_pool + $aacdec.SBR_abs_bord_lead) + r5] = r1;

      // SBR_bs_num_env[ch] = SBR_bs_num_rel_0[ch] + 1
      // read 2 bits
      call $aacdec.get2bits;
      M[($aacdec.tmp_mem_pool + $aacdec.SBR_bs_num_rel_0) + r5] = r1;
      r8 = r1 + 1;
      M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5] = r8;

      r2 = r5 * 5 (int);
      I1 = (&$aacdec.tmp_mem_pool + $aacdec.SBR_bs_rel_bord_0) + r2;
      I4 = (&$aacdec.tmp_mem_pool + $aacdec.SBR_bs_rel_bord) + r2;

      // SBR_bs_num_env[ch] - 1
      r10 = r8 - 1;

      do varfix_bs_rel_bord_loop;
         // read 2 bits
         call $aacdec.get2bits;
         r1 = r1 LSHIFT 1;
         r1 = r1 + 2;
         M[I1, 1] = r1,
          M[I4, 1] = r1;
      varfix_bs_rel_bord_loop:

      // ptr_bits = SBR_log2Table[SBR_bs_num_env[ch]+1]
      r0 = M[($aacdec.SBR_log2Table+1) + r8];
      // SBR_bs_pointer[ch] = getbits(ptr_bits)
      call $aacdec.getbits;
      M[($aacdec.sbr_np_info + $aacdec.SBR_bs_pointer) + r5] = r1;

      r10 = r8;
      r0 = r5 * 6 (int);
      I1 = (&$aacdec.sbr_info + $aacdec.SBR_bs_freq_res) + r0;

      do varfix_bs_freq_res_loop;
         call $aacdec.get1bit;
         M[I1, 1] = r1;
      varfix_bs_freq_res_loop:

      r1 = $aacdec.SBR_numTimeSlots;
      M[($aacdec.tmp_mem_pool + $aacdec.SBR_abs_bord_trail) + r5] = r1;

      jump end_switch_bs_frame_class;
   not_varfix:
   Null = r1 - $aacdec.SBR_VARVAR;
   if NZ jump end_switch_bs_frame_class;
      // case VARVAR

      // SBR_abs_bord_lead[ch] = getbits(2)
      // read 2 bits
      call $aacdec.get2bits;
      M[($aacdec.tmp_mem_pool + $aacdec.SBR_abs_bord_lead) + r5] = r1;

      // SBR_abs_bord_trail[ch] = getbits(2) + SBR_numTimeSlots
      // read 2 bits
      call $aacdec.get2bits;
      r1 = r1 + $aacdec.SBR_numTimeSlots;
      M[($aacdec.tmp_mem_pool + $aacdec.SBR_abs_bord_trail) + r5] = r1;

      // SBR_bs_num_rel_0[ch]
      // read 2 bits
      call $aacdec.get2bits;
      M[($aacdec.tmp_mem_pool + $aacdec.SBR_bs_num_rel_0) + r5] = r1;
      r4 = r1;
      // SBR_bs_num_rel_1[ch]
      // read 2 bits
      call $aacdec.get2bits;
      M[($aacdec.tmp_mem_pool + $aacdec.SBR_bs_num_rel_1) + r5] = r1;
      r6 = r4 + r1;

      // SBR_bs_num_env[ch] = SBR_bs_num_rel_0[ch] ...
      //                       + SBR_bs_num_rel_1[ch] + 1
      r8 = r6 + 1;
      M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5] = r8;

      r2 = r5 * 5 (int);
      I1 = (&$aacdec.tmp_mem_pool + $aacdec.SBR_bs_rel_bord_0) + r2;

      // SBR_bs_num_rel_0[ch]
      r10 = r4;

      do varvar_bs_rel_bord_0_loop;
         // read 2 bits
         call $aacdec.get2bits;
         r1 = r1 LSHIFT 1;
         r1 = r1 + 2;
         M[I1, 1] = r1;
      varvar_bs_rel_bord_0_loop:

      // SBR_bs_num_rel_1[ch]
      r10 = r6 - r4;
      r1 = r5 * 5 (int);
      I1 = (&$aacdec.tmp_mem_pool + $aacdec.SBR_bs_rel_bord_1) + r1;

      do varvar_bs_rel_bord_1_loop;
         // read 2 bits
         call $aacdec.get2bits;
         r1 = r1 LSHIFT 1;
         r1 = r1 + 2;
         M[I1, 1] = r1;
      varvar_bs_rel_bord_1_loop:

      // ptr_bits = SBR_log2Table[SBR_bs_num_env[ch]+1]
      r0 = M[($aacdec.SBR_log2Table+1) + r8];
      // SBR_bs_pointer[ch] = getbits(ptr_bits)
      call $aacdec.getbits;
      M[($aacdec.sbr_np_info + $aacdec.SBR_bs_pointer) + r5] = r1;

      r10 = r8;
      r0 = r5 * 6 (int);
      I1 = (&$aacdec.sbr_info + $aacdec.SBR_bs_freq_res) + r0;

      do varvar_bs_freq_res_loop;
         // read 1 bit
         call $aacdec.get1bit;
         M[I1, 1] = r1;
      varvar_bs_freq_res_loop:

   end_switch_bs_frame_class:


   r0 = 1;
   Null = r8 - 1;
   if GT r0 = r0 + r0;
   M[($aacdec.tmp_mem_pool + $aacdec.SBR_bs_num_noise) + r5] = r0;


   call $aacdec.sbr_envelope_time_border_vector;

   call $aacdec.sbr_envelope_noise_border_vector;


   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
