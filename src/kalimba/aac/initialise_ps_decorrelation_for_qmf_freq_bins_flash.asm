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
//    $aacdec.initialise_ps_decorrelation_for_qmf_freq_bins_flash
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
.MODULE $M.aacdec.initialise_ps_decorrelation_for_qmf_freq_bins_flash;
   .CODESEGMENT AACDEC_INITIALISE_PS_DECORRELATION_FOR_QMF_FREQ_BINS_FLASH_PM;
   .DATASEGMENT DM;

   $aacdec.initialise_ps_decorrelation_for_qmf_freq_bins_flash:

   // initialise pointers and parameters for QMF decorrelation

   r0 = M[$aacdec.tmp + $aacdec.PS_DECORRELATION_FLASH_TABLES_DM_ADDRESS];
   r0 = r0 + ($aacdec.PS_NUM_HYBRID_SUB_SUBBANDS * (2 + ($aacdec.PS_NUM_ALLPASS_LINKS * 2)));

   I0 = r0 + $aacdec.PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS;
   I4 = r0 + ($aacdec.X_SBR_WIDTH + $aacdec.PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS);
   r1 = r0 + ($aacdec.X_SBR_WIDTH * 2);
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_G_DECAY_SLOPE_FILTER_TABLE_BASE_ADDR] = r1;
   I2 = r0 + (($aacdec.X_SBR_WIDTH * 2) + (($aacdec.PS_DECORRELATION_NUM_ALLPASS_BANDS - $aacdec.PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS + 1) * $aacdec.PS_NUM_ALLPASS_LINKS) //...
                                        + ($aacdec.PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS * $aacdec.PS_NUM_ALLPASS_LINKS));
   I6 = I2 + ($aacdec.X_SBR_WIDTH * $aacdec.PS_NUM_ALLPASS_LINKS);

   r0 = &$aacdec.sbr_x_real + 640;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_SK_IN_REAL_BASE_ADDR] = r0;
   r0 = &$aacdec.sbr_x_imag + 1664;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_SK_IN_IMAG_BASE_ADDR] = r0;
   r0 = $aacdec.X_SBR_WIDTH;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_NUM_FREQ_BINS_PER_SAMPLE] = r0;

   r0 = &$aacdec.X_sbr_other_real;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_DK_OUT_REAL_BASE_ADDR] = r0;
   r0 = &$aacdec.X_sbr_other_imag;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_DK_OUT_IMAG_BASE_ADDR] = r0;

   r0 = &$aacdec.ps_qmf_allpass_feedback_buffer;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_ALLPASS_FEEDBACK_BUFFER_ADDRESS] = r0;

   r0 = ($aacdec.PS_NUM_ALLPASS_LINKS*(4*(($aacdec.PS_DECORRELATION_NUM_ALLPASS_BANDS - $aacdec.PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS) + 1)));
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_ALLPASS_FEEDBACK_BUFFER_SIZE] = r0;

   r0 = (($aacdec.PS_DECORRELATION_NUM_ALLPASS_BANDS - $aacdec.PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS) + 1);
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_NUMBER_HYBRID_OR_QMF_ALLPASS_FREQS] = r0;

   r0 = &$aacdec.ps_prev_frame_last_two_qmf_samples_real;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_LAST_TWO_SAMPLES_BUFFER_REAL_ADDR] = r0;

   r0 = &$aacdec.ps_prev_frame_last_two_qmf_samples_imag;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_LAST_TWO_SAMPLES_BUFFER_IMAG_ADDR] = r0;

   r0 = &$aacdec.ps_qmf_allpass_feedback_buffer;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_ALLPASS_FEEDBACK_BUFFER_M_EQS_ZERO_ADDR] = r0;
   r0 = &$aacdec.ps_qmf_allpass_feedback_buffer + (3 * (($aacdec.PS_DECORRELATION_NUM_ALLPASS_BANDS - $aacdec.PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS) + 1));
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_ALLPASS_FEEDBACK_BUFFER_M_EQS_ONE_ADDR] = r0;
   r0 = &$aacdec.ps_qmf_allpass_feedback_buffer + ((3 + 4) * (($aacdec.PS_DECORRELATION_NUM_ALLPASS_BANDS - $aacdec.PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS) + 1));
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_ALLPASS_FEEDBACK_BUFFER_M_EQS_TWO_ADDR] = r0;

   rts;

.ENDMODULE;

#endif
