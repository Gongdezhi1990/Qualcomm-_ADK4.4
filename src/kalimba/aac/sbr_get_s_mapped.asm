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
//    $aacdec.sbr_get_s_mapped
//
// DESCRIPTION:
//    Calculate the S_mapped variable
//
// INPUTS:
//    - M2 current_band
//    - r5 current channel (0/1)
//    - r8 envelope 'l'
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r2
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_get_s_mapped;
   .CODESEGMENT AACDEC_SBR_GET_S_MAPPED_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_get_s_mapped:

   // push rLink onto stack
   push rLink;

   // if(SBR_bs_freq_res[ch][l] == 1)
   r0 = r5 * 6 (int);
   r0 = r0 + r8;
   r0 = M[($aacdec.sbr_info + $aacdec.SBR_bs_freq_res) + r0];
   Null = r0 - 1;
   if NZ jump low_frequency_resolution;
      //((l >= SBR_l_A[ch]) || ...
         // ... (SBR_bs_add_harmonic_prev[ch][current_band]&&SBR_bs_add_harmonic_flag_prev[ch]))
      r0 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_l_A) + r5];
      Null = r8 - r0;
      if GE jump set_if_add_harmonic_in_curr_band_hi_f_res;
         r0 = r5 * 49 (int);
         r0 = r0 + M2;
         Null = M[($aacdec.sbr_info +  $aacdec.SBR_bs_add_harmonic_prev) + r0];
         if Z jump clear_s_mapped;
            Null = M[($aacdec.sbr_info + $aacdec.SBR_bs_add_harmonic_flag_prev) + r5];
            if Z jump clear_s_mapped;
               set_if_add_harmonic_in_curr_band_hi_f_res:
               // SBR_S_mapped = SBR_bs_add_harmonic[ch][current_band]
               r0 = r5 * 64 (int);
               r0 = r0 + M2;
               r0 = M[($aacdec.sbr_info + $aacdec.SBR_bs_add_harmonic) + r0];
               M[$aacdec.tmp_mem_pool + $aacdec.SBR_S_mapped] = r0;
               jump exit;

   low_frequency_resolution:

   // lb = first Hi-resolution band in current Low-resolution band
   // lb = (2*current_band) - bitand(SBR_Nhigh, 1)
   r0 = M[$aacdec.sbr_info + $aacdec.SBR_Nhigh];
   r0 = r0 AND 1;
   r2 = M2 + M2;
   r2 = r2 - r0;

   // ub = first Hi-resolution band in next Low-resolution band
   // ub = (2*(current_band+1)) - bitand(SBR_Nhigh, 1)
   r1 = M2 + 1;
   r1 = r1 * 2 (int);
   r1 = r1 - r0;

   // for b=lb:ub-1,
   check_bands_loop:

      // if((l >= SBR_l_A[ch]) || ...
         // (SBR_bs_add_harmonic_prev[ch][b]&&SBR_bs_add_harmonic_flag_prev[ch]))
      r0 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_l_A) + r5];
      Null = r8 - r0;
      if GE jump set_if_add_harmonic_in_curr_band_low_f_res;
         r0 = r5 * 49 (int);
         r0 = r0 + r2;
         Null = M[($aacdec.sbr_info + $aacdec.SBR_bs_add_harmonic_prev) + r0];
         if Z jump eval_loop_index;
            Null = M[($aacdec.sbr_info + $aacdec.SBR_bs_add_harmonic_flag_prev) + r5];
            if Z jump eval_loop_index;
               set_if_add_harmonic_in_curr_band_low_f_res:
               // if(SBR_bs_add_harmonic[ch][b] == 1)
               r0 = r5 * 64 (int);
               r0 = r0 + r2;
               r0 = M[($aacdec.sbr_info + $aacdec.SBR_bs_add_harmonic) + r0];
               if Z jump eval_loop_index;
                  M[$aacdec.tmp_mem_pool + $aacdec.SBR_S_mapped] = r0;
                  jump exit;

   eval_loop_index:
   r2 = r2 + 1;
   Null = r1 - r2;
   if GT jump check_bands_loop;


   clear_s_mapped:
   M[$aacdec.tmp_mem_pool + $aacdec.SBR_S_mapped] = Null;


   exit:


   // pop rLink from stack
   jump $pop_rLink_and_rts;



.ENDMODULE;

#endif
