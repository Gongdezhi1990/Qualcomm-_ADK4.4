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
//    $aacdec.initialise_ps_transient_detection_for_hybrid_freq_bins_flash
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
.MODULE $M.aacdec.initialise_ps_transient_detection_for_hybrid_freq_bins_flash;
   .CODESEGMENT AACDEC_INITIALISE_PS_TRANSIENT_DETECTION_FOR_HYBRID_FREQ_BINS_FLASH_PM;
   .DATASEGMENT DM;


   $aacdec.initialise_ps_transient_detection_for_hybrid_freq_bins_flash:


   // push rLink onto stack
   push rLink;



   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_TEMP_R8] = r8;

   // allocate temporary memory for Gain_transient_ratio[n=0:31][parameter_band=0:19] and double(P[n=0:31][parameter_band=0:19])
   r0 = (2 * $aacdec.PS_NUM_SAMPLES_PER_FRAME * $aacdec.PS_NUM_PAR_BANDS_IN_BASELINE_DECORRELATION);
   call $aacdec.frame_mem_pool_allocate;

   M[$aacdec.tmp + $aacdec.PS_INPUT_POWER_MATRIX_BASE_ADDR] = r1;

   r10 = (2 * $aacdec.PS_NUM_SAMPLES_PER_FRAME);
   I0 = r1;
   r0 = 0;
   DO clear_input_power_array_loop_msb;
      M[I0,1] = r0;
   clear_input_power_array_loop_msb:

   r10 = (2 * $aacdec.PS_NUM_SAMPLES_PER_FRAME);
   I0 = r1 + ($aacdec.PS_NUM_SAMPLES_PER_FRAME * $aacdec.PS_NUM_PAR_BANDS_IN_BASELINE_DECORRELATION);
   DO clear_input_power_array_loop_lsb;
      M[I0,1] = r0;
   clear_input_power_array_loop_lsb:

   // use tmp_mem_pool[ [2048:2048+511]; sbr_temp_2[0:639-512] ] as temporary memory
   // for PS_GAIN_TRANSIENT_RATIO[n=0:31][parameter_band=0:19]
   r0 = (&$aacdec.tmp_mem_pool + 2048);
   M[$aacdec.tmp + $aacdec.PS_GAIN_TRANSIENT_RATIO_ADDR] = r0;
   // I7 -> PS_GAIN_TRANSIENT_RATIO[n=0:31][parameter_band=0]
   I7 = r0;

   I0 = &$aacdec.ps_power_peak_decay_nrg_prev + 0;
   I3 = &$aacdec.ps_power_smoothed_peak_decay_diff_nrg_prev + 0;
   I2 = &$aacdec.ps_smoothed_input_power_prev + 0;

   // initialise pointers and parameters for hybrid Transient Detection
   r0 = M[$aacdec.X_ps_hybrid_real_address + 0];
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_SK_IN_REAL_BASE_ADDR] = r0;
   r0 = M[$aacdec.X_ps_hybrid_imag_address + 0];
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_SK_IN_IMAG_BASE_ADDR] = r0;
   r0 = 1;
   M[$aacdec.tmp + $aacdec.PS_DECORRELATION_NUM_FREQ_BINS_PER_SAMPLE] = r0;
   r0 = $aacdec.PS_NUM_SAMPLES_PER_FRAME;
   M[$aacdec.tmp + $aacdec.PS_TRANSIENT_DETECTOR_INTER_SUBBAND_STRIDE] = r0;

   I1 = &$aacdec.map_freq_bands_to_20_par_bands_x_num_samples_per_frame_table + 0;
   I5 = &$aacdec.frequency_border_table_20_par_bands + 0;

   r0 = $aacdec.PS_NUM_HYBRID_FREQ_BANDS_WHEN_20_PAR_BANDS;
   M[$aacdec.tmp + $aacdec.PS_TRANSIENT_DETECTOR_SUBBAND_LOOP_BOUND] = r0;

   M1 = 0;
   M2 = 1;

   r0 = 1;



   // pop rLink from stack
   jump $pop_rLink_and_rts;



.ENDMODULE;

#endif
