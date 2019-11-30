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
//    $aacdec.sbr_hf_assembly_save_persistent_gain_signal_envelopes
//
// DESCRIPTION:
//    saves each envelope of the Gain arrays (signal (G) and noise (Q))
//    which may be required in the subsequent frame if smoothing mode is used
//    to apply the gains
//
// INPUTS:
//    -
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    -
//    -
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_hf_assembly_save_persistent_gain_signal_envelopes;
   .CODESEGMENT AACDEC_SBR_HF_ASSEMBLY_SAVE_PERSISTENT_GAIN_SIGNAL_ENVELOPES_PM;
   .DATASEGMENT DM;


   $aacdec.sbr_hf_assembly_save_persistent_gain_signal_envelopes:


   // SBR_index_noise_prev[ch] = SBR_f_index_noise
   r0 = M[$aacdec.tmp + $aacdec.SBR_f_index_noise];
   M[($aacdec.sbr_info + $aacdec.SBR_index_noise_prev) + r5] = r0;

   // SBR_psi_is_prev[ch] = SBR_f_index_sine
   r0 = M[$aacdec.tmp + $aacdec.SBR_f_index_sine];
   M[($aacdec.sbr_info + $aacdec.SBR_psi_is_prev) + r5] = r0;

   // write persistent envelopes into SBR_G_temp and SBR_Q_temp arrays
   r6 = M[($aacdec.sbr_info + $aacdec.SBR_GQ_index) + r5];
   r7 = r5 * 5 (int);
   r8 = &$aacdec.sbr_info;

   M0 = 4;
   r0 = r5 * ($aacdec.SBR_M_MAX * 2) (int);
   M1 = r0 - $aacdec.SBR_M_MAX;

   save_persistent_g_and_temp_envelopes_loop:
      r6 = r6 + 1;
      Null = r6 - 5;
      if GE r6 = 0;

      r0 = r7 + r6;

      r2 = M[($aacdec.sbr_info + $aacdec.SBR_G_TEMP_LIM_ENV_ADDR_ARRAY_FIELD) + r0];
      Null = r8 - r2;
      if Z jump g_and_q_temp_envelope_saved;
         r8 = r2;

         r10 = M[$aacdec.tmp + $aacdec.SBR_calc_gain_boost_data_per_envelope];

         M1 = M1 + $aacdec.SBR_M_MAX;

         I0 = r2;
         r2 = M[($aacdec.sbr_info + $aacdec.SBR_Q_TEMP_LIM_ENV_ADDR_ARRAY_FIELD) + r0];
         I4 = r2;
         I1 = (&$aacdec.sbr_info + $aacdec.SBR_G_TEMP_PERSISTENT_ENVELOPES_ARRAY_FIELD) + M1;
         I5 = (&$aacdec.sbr_info + $aacdec.SBR_Q_TEMP_PERSISTENT_ENVELOPES_ARRAY_FIELD) + M1;

         do save_persistent_envelopes_inner_loop;
            r2 = M[I0, 1],
             r1 = M[I4, 1];
            M[I1, 1] = r2,
             M[I5, 1] = r1;
         save_persistent_envelopes_inner_loop:

      g_and_q_temp_envelope_saved:

      r1 = (&$aacdec.sbr_info + $aacdec.SBR_G_TEMP_PERSISTENT_ENVELOPES_ARRAY_FIELD) + M1;
      M[($aacdec.sbr_info + $aacdec.SBR_G_TEMP_LIM_ENV_ADDR_ARRAY_FIELD) + r0] = r1;

      r1 = (&$aacdec.sbr_info + $aacdec.SBR_Q_TEMP_PERSISTENT_ENVELOPES_ARRAY_FIELD) + M1;
      M[($aacdec.sbr_info + $aacdec.SBR_Q_TEMP_LIM_ENV_ADDR_ARRAY_FIELD) + r0] = r1;

   M0 = M0 - 1;
   if NZ jump save_persistent_g_and_temp_envelopes_loop;


   rts;



.ENDMODULE;

#endif




