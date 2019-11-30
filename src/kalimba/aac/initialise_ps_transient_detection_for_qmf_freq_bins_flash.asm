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
//    $aacdec.initialise_ps_transient_detection_for_qmf_freq_bins_flash
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
.MODULE $M.aacdec.initialise_ps_transient_detection_for_qmf_freq_bins_flash;
   .CODESEGMENT AACDEC_INITIALISE_PS_TRANSIENT_DETECTION_FOR_QMF_FREQ_BINS_FLASH_PM;
   .DATASEGMENT DM;


   $aacdec.initialise_ps_transient_detection_for_qmf_freq_bins_flash:


   // initialise pointers and parameters for QMF Transient-Detection

   r0 = &$aacdec.X_sbr_curr_real;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_SK_IN_REAL_BASE_ADDR] = r0;
   r0 = &$aacdec.X_sbr_curr_imag;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_SK_IN_IMAG_BASE_ADDR] = r0;
   r0 = $aacdec.X_SBR_WIDTH;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_NUM_FREQ_BINS_PER_SAMPLE] = r0;
   r0 = 1;
   M[$aacdec.tmp + $aacdec.PS_TRANSIENT_DETECTOR_INTER_SUBBAND_STRIDE] = r0;

   I1 = &$aacdec.map_freq_bands_to_20_par_bands_x_num_samples_per_frame_table + $aacdec.PS_NUM_HYBRID_FREQ_BANDS_WHEN_20_PAR_BANDS;
   I5 = &$aacdec.frequency_border_table_20_par_bands + $aacdec.PS_NUM_HYBRID_FREQ_BANDS_WHEN_20_PAR_BANDS;

   M1 = $aacdec.PS_NUM_HYBRID_FREQ_BANDS_WHEN_20_PAR_BANDS;
   r0 = $aacdec.PS_NUM_FREQ_BANDS_WHEN_20_PAR_BANDS;
   M[$aacdec.tmp + $aacdec.PS_TRANSIENT_DETECTOR_SUBBAND_LOOP_BOUND] = r0;


   rts;




.ENDMODULE;

#endif
