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
//    $aacdec.initialise_ps_stereo_mixing_for_qmf_freq_bins_flash
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
.MODULE $M.aacdec.initialise_ps_stereo_mixing_for_qmf_freq_bins_flash;
   .CODESEGMENT AACDEC_INITIALISE_PS_STEREO_MIXING_FOR_QMF_FREQ_BINS_FLASH_PM;
   .DATASEGMENT DM;

   $aacdec.initialise_ps_stereo_mixing_for_qmf_freq_bins_flash:

   // initialise pointers and parameters for QMF Stereo Mixing

   r0 = &$aacdec.sbr_x_real + 640;  //&$aacdec.X_sbr_curr_real;
   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_SK_REAL_BASE_ADDR] = r0;
   r0 = &$aacdec.sbr_x_imag + 1664; //&$aacdec.X_sbr_curr_imag;
   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_SK_IMAG_BASE_ADDR] = r0;
   r0 = &$aacdec.X_sbr_other_real;
   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_DK_REAL_BASE_ADDR] = r0;
   r0 = &$aacdec.X_sbr_other_imag;
   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_DK_IMAG_BASE_ADDR] = r0;

   r0 = $aacdec.X_SBR_WIDTH;
   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_INTER_SAMPLE_STRIDE] = r0;
   r0 = 1;
   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_INTER_SUBBAND_STRIDE] = r0;

   M1 = $aacdec.PS_NUM_HYBRID_FREQ_BANDS_WHEN_20_PAR_BANDS;
   r0 = $aacdec.PS_NUM_FREQ_BANDS_WHEN_20_PAR_BANDS;    // extend frequency_bands loop bound to process remaining QMF subbands
   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_FREQ_BAND_LOOP_BOUND] = r0;

   rts;

.ENDMODULE;

#endif
