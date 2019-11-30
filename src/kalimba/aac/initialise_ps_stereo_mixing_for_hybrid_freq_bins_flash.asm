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
//    $aacdec.initialise_ps_stereo_mixing_for_hybrid_freq_bins_flash
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
.MODULE $M.aacdec.initialise_ps_stereo_mixing_for_hybrid_freq_bins_flash;
   .CODESEGMENT AACDEC_INITIALISE_PS_STEREO_MIXING_FOR_HYBRID_FREQ_BINS_FLASH_PM;
   .DATASEGMENT DM;



   $aacdec.initialise_ps_stereo_mixing_for_hybrid_freq_bins_flash:



   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_TEMP_R8] = r8;

   // initialise pointers and parameters for hybrid Stereo Mixing

   // if(PS_IID_MODE < 3)
   r0 = 3;
   Null = r0 - M[$aacdec.ps_info + $aacdec.PS_IID_MODE];
   if LE jump fine_resolution_stereo_mixing;
      // coarse resolution
      r0 = &$aacdec.ps_iid_coarse_resolution_scale_factor_table + $aacdec.PS_IID_NUM_QUANT_STEPS_COARSE_RES;
      jump end_if_coarse_or_fine_stereo_mixing;
   // else
   fine_resolution_stereo_mixing:
      // fine resolution
      r0 = &$aacdec.ps_iid_fine_resolution_scale_factor_table + $aacdec.PS_IID_NUM_QUANT_STEPS_FINE_RES;
   end_if_coarse_or_fine_stereo_mixing:

   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_IID_ZERO_SCALE_FACTOR_TABLE_POINTER] = r0;

   // initialise base address pointers for hybrid section
   r0 = M[$aacdec.X_ps_hybrid_real_address + 0];
   r1 = M[$aacdec.X_ps_hybrid_imag_address + 0];
   r2 = M[$aacdec.X_ps_hybrid_real_address + 1];
   r3 = M[$aacdec.X_ps_hybrid_imag_address + 1];
   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_SK_REAL_BASE_ADDR] = r0;
   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_SK_IMAG_BASE_ADDR] = r1;
   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_DK_REAL_BASE_ADDR] = r2;
   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_DK_IMAG_BASE_ADDR] = r3;

   r0 = 1;
   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_INTER_SAMPLE_STRIDE] = r0;
   r0 = $aacdec.PS_NUM_SAMPLES_PER_FRAME;
   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_INTER_SUBBAND_STRIDE] = r0;

   M1 = 0;
   r0 = $aacdec.PS_NUM_HYBRID_FREQ_BANDS_WHEN_20_PAR_BANDS;    // extend frequency_bands loop bound to process remaining QMF subbands
   M[$aacdec.tmp + $aacdec.PS_STEREO_MIXING_FREQ_BAND_LOOP_BOUND] = r0;

   I3 = &$aacdec.ps_h12_previous_envelope;
   I6 = &$aacdec.ps_h21_previous_envelope;
   I7 = &$aacdec.ps_h22_previous_envelope;


   r0 = 1;


   rts;




.ENDMODULE;

#endif
