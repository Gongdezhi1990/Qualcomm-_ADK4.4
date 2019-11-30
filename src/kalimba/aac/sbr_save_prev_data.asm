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
//    $aacdec.sbr_save_prev_data
//
// DESCRIPTION:
//    Save data from this frame that is required for next frame
//
// INPUTS:
//    - r5 channel
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r2, r10, I1, I2
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_save_prev_data;
   .CODESEGMENT AACDEC_SBR_SAVE_PREV_DATA_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_save_prev_data:

   // push rLink onto stack
   push rLink;

   // SBR_bs_add_harmonic_flag_prev[ch] = SBR_bs_add_harmonic_flag[ch]
   r0 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_add_harmonic_flag) + r5];
   M[($aacdec.sbr_info + $aacdec.SBR_bs_add_harmonic_flag_prev) + r5] = r0;

   // SBR_bs_add_harmonic_prev[ch][0:48] = SBR_bs_add_harmonic[ch][0:48]
   r0 = r5 * 49 (int);
   I1 = (&$aacdec.sbr_info + $aacdec.SBR_bs_add_harmonic_prev) + r0;
   r0 = r5 * 64 (int);
   I2 = (&$aacdec.sbr_info + $aacdec.SBR_bs_add_harmonic) + r0;

   r10 = 48;

   do bs_add_harmonic_prev_loop;
      r0 = M[I2, 1];
      M[I1, 1] = r0;
   bs_add_harmonic_prev_loop:


   // SBR_freq_res_prev[ch] = SBR_bs_freq_res[ch][SBR_bs_num_env[ch]-1]
   r0 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_num_env) + r5];
   r1 = r5 * 6 (int);
   r1 = r1 + r0;
   r1 = M[($aacdec.sbr_info + $aacdec.SBR_bs_freq_res - 1) + r1];
   M[($aacdec.sbr_info + $aacdec.SBR_freq_res_prev) + r5] = r1;


   // if(SBR_l_A[ch] == SBR_bs_num_env[ch])
   r2 = 1;
   r1 = M[($aacdec.tmp_mem_pool + $aacdec.SBR_l_A) + r5];
   Null = r1 - r0;
   if NZ r2 = 0;
   M[($aacdec.sbr_info + $aacdec.SBR_prevEnvIsShort) + r5] = r2;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif
