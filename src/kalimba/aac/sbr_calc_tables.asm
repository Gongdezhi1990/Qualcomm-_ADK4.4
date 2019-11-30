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
//    $aacdec.sbr_calc_tables
//
// DESCRIPTION:
//    calculate tables used in SBR decoding process
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r8, r10, rMAC, I1-I4, M1, Div
//    - $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_calc_tables;
   .CODESEGMENT AACDEC_SBR_CALC_TABLES_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_calc_tables:

   // push rLink onto stack
   push rLink;

   // by default SBR_fs_index = 2 * (core AAC decoder sample rate)
   r0 = M[$aacdec.sf_index];
   r4 = r0 - 3;

   // r1 = startMin
   r8 = M[$aacdec.sbr_startMinTable + r4];

   // r2 = SBR offset index
   r2 = M[$aacdec.sbr_offsetIndexTable + r4];

   // calculate k0
   r3 = M[$aacdec.sbr_offset + r2];

   // r5 = SBR_bs_start_freq
   r5 = M[$aacdec.sbr_info + $aacdec.SBR_bs_start_freq];
   #ifdef AACDEC_SBR_QMF_STOP_CHANNEL_OFFSET_IN_FLASH
      r0 = r3 + r5;
      r2 = M[$flash.windowed_data16.address];
      call $aacdec.sbr_read_one_word_from_flash;
   #else
      r0 = M[r3 + r5];
   #endif

   // r1 = k0
   r1 = r8 + r0;
   M[$aacdec.sbr_info + $aacdec.SBR_k0] = r1;

   r2 = M[$aacdec.sbr_info + $aacdec.SBR_bs_stop_freq];
   if NEG jump k2_calc_complete;
      Null = r2 - 14;
      if GE jump bs_stop_freq_not_less_than_14;
         // r1 = stopMin
         r8 = M[$aacdec.sbr_stopMinTable + r4];
         // r2 = min(bs_stop_freq, 13)
         r5 = r2 - 13;
         if POS r2 = r2 - r5;
         r5 = M[$aacdec.sbr_qmf_stop_channel_offset + r4];
         #ifdef AACDEC_SBR_QMF_STOP_CHANNEL_OFFSET_IN_FLASH
            r0 = r5 + r2;
            r2 = M[$flash.windowed_data16.address];
            call $aacdec.sbr_read_one_word_from_flash;
         #else
            r0 = M[r5 + r2];
         #endif
         r2 = r8 + r0;
         jump cap_k2_at_64;
      bs_stop_freq_not_less_than_14:
      if NE jump bs_stop_freq_not_eq_14;
         r2 = r1 LSHIFT 1;
         jump cap_k2_at_64;
      bs_stop_freq_not_eq_14:
      Null = r2 - 15;
      if NE jump bs_stop_freq_not_eq_15;
         r2 = r1 * 3 (int);

   bs_stop_freq_not_eq_15:
   cap_k2_at_64:

   // k2 = min(r2, 64);
   r5 = r2 - 64;
   if POS r2 = r2 - r5;

   M[$aacdec.sbr_info + $aacdec.SBR_k2] = r2;


   k2_calc_complete:

   Null = M[$aacdec.sbr_info + $aacdec.SBR_bs_freq_scale];
   if Z jump bs_freq_scale_is_zero;
      call $aacdec.sbr_fmaster_table_calc_fscale_gt_zero;
      jump end_fmaster_table_calc;
   bs_freq_scale_is_zero:
      call $aacdec.sbr_fmaster_table_calc_fscale_eq_zero;
   end_fmaster_table_calc:

   Null = M[$aacdec.possible_frame_corruption];
   if NZ jump $aacdec.possible_corruption;

   call $aacdec.sbr_fband_tables;

   // pop rLink from stack
   jump $pop_rLink_and_rts;


.ENDMODULE;

#endif
