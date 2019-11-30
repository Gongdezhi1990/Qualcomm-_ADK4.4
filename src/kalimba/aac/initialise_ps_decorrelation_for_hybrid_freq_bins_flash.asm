// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_PARAMETRIC_STEREO_ADDITIONS

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.initialise_ps_decorrelation_for_hybrid_freq_bins_flash
//
// DESCRIPTION:
//    -
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - toupdate
//
// *****************************************************************************
.MODULE $M.aacdec.initialise_ps_decorrelation_for_hybrid_freq_bins_flash;
   .CODESEGMENT AACDEC_INITIALISE_PS_DECORRELATION_FOR_HYBRID_FREQ_BINS_FLASH_PM;
   .DATASEGMENT DM;


   $aacdec.initialise_ps_decorrelation_for_hybrid_freq_bins_flash:


   // push rLink onto stack
   push rLink;



   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_TEMP_R8] = r8;


   #ifdef AACDEC_PARAMETRIC_STEREO_PHI_FRACT_TABLES_IN_FLASH
      #ifdef KALASM3_NO_DATA_FLASH
      r0 = &$aacdec.ps_decorrelation;
      #else
      r0 = &$aacdec.ps_decorrelation;
      r2 = M[$flash.windowed_data16.address];
      call $flash.map_page_into_dm;
      #endif
      // initialise pointers for Hybrid section
      M[$aacdec.tmp + $aacdec.PS_DECORRELATION_FLASH_TABLES_DM_ADDRESS] = r0;
   #else
      I0 = &$aacdec.ps_phi_fract_qmf_bands_real + $aacdec.PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS;
      I4 = &$aacdec.ps_phi_fract_qmf_bands_imag + $aacdec.PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS;
      r1 = &$aacdec.g_decay_slope_filter_20_parameter_bands_qmf_bands_table;
      M[$aacdec.tmp + $aacdec.PS_DECORRELATION_G_DECAY_SLOPE_FILTER_TABLE_BASE_ADDR] = r1;
      I2 = &$aacdec.ps_phi_fract_allpass_qmf_bands_real - $aacdec.PS_NUM_ALLPASS_LINKS;
      I6 = &$aacdec.ps_phi_fract_allpass_qmf_bands_imag - $aacdec.PS_NUM_ALLPASS_LINKS;
   #endif


   // initialise hybrid decorrelation pointers and parametrs
   r0 = M[$aacdec.X_ps_hybrid_real_address + 0];
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_SK_IN_REAL_BASE_ADDR] = r0;
   r0 = M[$aacdec.X_ps_hybrid_imag_address + 0];
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_SK_IN_IMAG_BASE_ADDR] = r0;

   r0 = M[$aacdec.X_ps_hybrid_real_address + 1];
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_DK_OUT_REAL_BASE_ADDR] = r0;
   r0 = M[$aacdec.X_ps_hybrid_imag_address + 1];
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_DK_OUT_IMAG_BASE_ADDR] = r0;

   r0 = 1;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_NUM_FREQ_BINS_PER_SAMPLE] = r0;

   r0 = &$aacdec.ps_hybrid_allpass_feedback_buffer;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_ALLPASS_FEEDBACK_BUFFER_ADDRESS] = r0;

   r0 = $aacdec.PS_NUM_ALLPASS_LINKS * 4 * ($aacdec.PS_NUM_HYBRID_SUB_SUBBANDS - 2);
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_ALLPASS_FEEDBACK_BUFFER_SIZE] = r0;

   r0 = ($aacdec.PS_NUM_HYBRID_SUB_SUBBANDS - 2);
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_NUMBER_HYBRID_OR_QMF_ALLPASS_FREQS] = r0;

   r0 = &$aacdec.ps_prev_frame_last_two_hybrid_samples_real;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_LAST_TWO_SAMPLES_BUFFER_REAL_ADDR] = r0;

   r0 = &$aacdec.ps_prev_frame_last_two_hybrid_samples_imag;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_LAST_TWO_SAMPLES_BUFFER_IMAG_ADDR] = r0;

   M1 = 0;
   r1 = $aacdec.PS_NUM_HYBRID_SUB_SUBBANDS - 2;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_SUBBAND_LOOP_BOUND] = r1;

   // load hybrid gDecaySlope_filter[m=0:2]
   r0 = 0.65143905753106;
   M[($aacdec.tmp + $aacdec.PS_G_DECAY_SLOPE_FILTER_A) + 0] = r0;
   r0 = 0.56471812200776;
   M[($aacdec.tmp + $aacdec.PS_G_DECAY_SLOPE_FILTER_A) + 1] = r0;
   r0 = 0.48954165955695;
   M[($aacdec.tmp + $aacdec.PS_G_DECAY_SLOPE_FILTER_A) + 2] = r0;


   r0 = &$aacdec.ps_hybrid_allpass_feedback_buffer;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_ALLPASS_FEEDBACK_BUFFER_M_EQS_ZERO_ADDR] = r0;
   r0 = &$aacdec.ps_hybrid_allpass_feedback_buffer + (3 * ($aacdec.PS_NUM_HYBRID_SUB_SUBBANDS - 2));
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_ALLPASS_FEEDBACK_BUFFER_M_EQS_ONE_ADDR] = r0;
   r0 = &$aacdec.ps_hybrid_allpass_feedback_buffer + ((3 + 4) * ($aacdec.PS_NUM_HYBRID_SUB_SUBBANDS - 2));
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_ALLPASS_FEEDBACK_BUFFER_M_EQS_TWO_ADDR] = r0;


   r0 = 1;




   // pop rLink from stack
   jump $pop_rLink_and_rts;



.ENDMODULE;

#endif
