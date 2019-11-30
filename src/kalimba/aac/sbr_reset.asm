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
//    $aacdec.sbr_reset
//
// DESCRIPTION:
//    Reset the sbr section of the decoder
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - I1, I4, r0, r1
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_reset;
   .CODESEGMENT AACDEC_SBR_RESET_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_reset:

   M[$aacdec.sbr_info + $aacdec.SBR_reset] = Null;

   I1 = &$aacdec.sbr_info + $aacdec.SBR_bs_start_freq;
   I4 = (&$aacdec.sbr_info + $aacdec.SBR_bs_start_freq) + 1;

   // if(sbr.bs_start_freq ~= sbr.bs_start_freq_prev)
   r0 = M[I1, 2],
    r1 = M[I4, 2];
   Null = r0 - r1;
   if NZ jump set_sbr_reset_flag;
      // elseif(sbr.bs_stop_freq ~= sbr.bs_stop_freq_prev)
      r0 = M[I1, 2],
       r1 = M[I4, 2];
      Null = r0 - r1;
      if NZ jump set_sbr_reset_flag;
         // elseif(sbr.bs_freq_scale ~= sbr.bs_freq_scale_prev)
         r0 = M[I1, 2],
          r1 = M[I4, 2];
         Null = r0 - r1;
         if NZ jump set_sbr_reset_flag;
            // elseif(sbr.bs_alter_scale ~= sbr.bs_alter_scale_prev)
            r0 = M[I1, 2],
             r1 = M[I4, 2];
            Null = r0 - r1;
            if NZ jump set_sbr_reset_flag;
               // elseif(sbr.bs_xover_band ~= sbr.bs_xover_band_prev)
               r0 = M[I1, 2],
                r1 = M[I4, 2];
               Null = r0 - r1;
               if NZ jump set_sbr_reset_flag;
                  // elseif(sbr.bs_noise_bands ~= sbr.bs_noise_bands_prev)
                  r0 = M[I1, 0],
                   r1 = M[I4, 0];
                  Null = r0 - r1;
                  if NZ jump set_sbr_reset_flag;
                     // SBR_reset = 0
                     jump reset_flag_assigned;

   set_sbr_reset_flag:

   r0 = 1;
   M[$aacdec.sbr_info + $aacdec.SBR_reset] = r0;


   reset_flag_assigned:


   I1 = &$aacdec.sbr_info + $aacdec.SBR_bs_start_freq;
   I4 = (&$aacdec.sbr_info + $aacdec.SBR_bs_start_freq) + 1;


   r0 = M[I1, 2];

   M[I4, 2] = r0,    // sbr.bs_start_freq_prev = sbr.bs_start_freq
    r0 = M[I1, 2];

   M[I4, 2] = r0,    // sbr.bs_stop_freq_prev = sbr.bs_stop_freq
    r0 = M[I1, 2];

   M[I4, 2] = r0,    // sbr.bs_freq_scale_prev = sbr.bs_freq_scale
    r0 = M[I1, 2];

   M[I4, 2] = r0,    // sbr.bs_alter_scale_prev = sbr.bs_alter_scale
    r0 = M[I1, 2];

   M[I4, 2] = r0,    // sbr.bs_xover_band_prev = sbr.bs_xover_band
    r0 = M[I1, 0];

   M[I4, 0] = r0;    // sbr.bs_noise_bands_prev = sbr.bs_noise_bands



   // return to sbr_extension_data
   rts;


.ENDMODULE;

#endif
