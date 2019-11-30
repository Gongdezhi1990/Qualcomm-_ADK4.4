// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CELT_BANDS_PROCESSING_INCLUDED
#define CELT_BANDS_PROCESSING_INCLUDED
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.compute_band_energies
//
// DESCRIPTION:
//    calculates band energies
//
// INPUTS:
//   I2 = pointer to input mdct frequency bins 
//   I1 = address of output band energies(normal)
//   I5 = address of output band energies(logarithmic)
// OUTPUTS:
//   None
// TRASHED REGISTERS:
//    everything except r5    
// *****************************************************************************
.MODULE $M.celt.compute_band_energies;
   .CODESEGMENT CELT_COMPUTE_BAND_ENERGIES_PM;
   .DATASEGMENT DM;
   $celt.compute_band_energies:
   // push rLink onto stack
   $push_rLink_macro;

   r0 = M[r5 + $celt.enc.MODE_NB_EBANDS_FIELD];
   M3 = r0;
   r0 = M[r5 + $celt.enc.MODE_EBANDS_ADDR_FIELD];
   I3 = r0;
   I6 = r2;
   calc_bande_loop:
      r6 = 1;
      r0 = M[I3, 1];
      r1 = M[I3, 0];
      r10 = r1 - r0;
      r10 = r10 - 1;
      rMAC = 0, r0 = M[I2, 1];
      do calc_en_loop;
         rMAC = rMAC + r0*r0, r0 = M[I2, 1];
      calc_en_loop:
      rMAC = rMAC + r0*r0;
      if Z rMAC = rMAC + r6*r6;
      r8 = signdet rMAC;
      r8 = r8 AND 0xFFFFFE;
      rMAC = rMAC ASHIFT r8 (56bit);
      push I3;
      call $math.sqrt48;
      pop I3;
      r1 = r8 * (-0.5)(frac);
      M[I1, 1] = r0;            //gain
      r1 = r1 - I6;
      M[I1, 0] = r1;            //shift
      rMAC = r0;
      call $math.log2_table;
      r1 = M[I1, 1];
      r1 = r1 + 13;   //adjust scale 
      r1 = r1 ASHIFT 16; ///???
      r0 = r0 + r1;
      M[I5, 1] = r0;
      M3 = M3 - 1;
   if NZ jump calc_bande_loop;

   // pop rLink from stack
   jump $pop_rLink_and_rts;


.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.normalise_bands
//
// DESCRIPTION:
//    nomalize bands to have unity energy in each band
//
// INPUTS:
//   I2 = pointer to input mdct frequency bins 
//   I1 = address of input band energies(normal)
//   I5 = address of output nomalized frequency bins
//   r2 = amount of shift
// OUTPUTS:
//   None
// TRASHED REGISTERS:
//    everything except r5    
// *****************************************************************************
.MODULE $M.celt.normalise_bands;
   .CODESEGMENT CELT_NORMALISE_BANDS_PM;
   .DATASEGMENT DM;
   $celt.normalise_bands:
   // push rLink onto stack
   $push_rLink_macro;

   r0 = M[r5 + $celt.enc.MODE_NB_EBANDS_FIELD];
   M3 = r0;
   r0 = M[r5 + $celt.enc.MODE_EBANDS_ADDR_FIELD];
   I3 = r0;
   I6 = r2;
   norm_bands_loop:
      r0 = M[I3, 1];
      r1 = M[I3, 0];
      r10 = r1 - r0;
      r10 = r10 - 1;
      r0 = M[I1, 1];   //gain
      r1 = M[I1, 1];   //shift
      r1 = r1 + I6;
      r1 = 1 - r1;
      rMAC = 0.125;
      Div = rMAC/ r0;
      r0 = DivResult;
      r2 = M[I2, 1];
      rMAC = r2 * r0;
      do normalize_band_loop;
         rMAC = rMAC ASHIFT r1 (56bit), r2 = M[I2, 1];
         rMAC = r2 * r0, M[I5, 1] = rMAC;         
      normalize_band_loop:
      rMAC = rMAC ASHIFT r1 (56bit);
      M[I5, 1] = rMAC; 
   M3 = M3 - 1;
   if NZ jump norm_bands_loop; 
   r0 = M[I3, 1];
   r1 = M[I3, 0];
   r10 = r1 - r0;
   r0 = 0;
   do zero_last_band;
       M[I5, 1] = r0;
   zero_last_band:
   
   // pop rLink from stack
   jump $pop_rLink_and_rts;


.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.bands_process
//
// DESCRIPTION:
//    groups the spectrum to a number of bands and normalises each band separately
//
// INPUTS:
//   
// OUTPUTS:
//   None
// TRASHED REGISTERS:
//    everything except r5    
// *****************************************************************************
.MODULE $M.celt.bands_process;
   .CODESEGMENT CELT_BAND_PROCESS_PM;
   .DATASEGMENT DM;
   $celt.bands_process:
   // push rLink onto stack
   $push_rLink_macro;

   // -- compute band energies (left channel)
   r2 = M[$celt.enc.max_sband + 0];
   r0 = M[r5 + $celt.enc.FREQ_FIELD];
   I2 = r0;
   r0 = M[r5 + $celt.enc.BANDE_FIELD];
   I1 = r0;
   r0 = M[r5 + $celt.enc.LOG_BANDE_FIELD];
   I5 = r0;
   call $celt.compute_band_energies;

   // -- nomalise bands (left channel)
   r2 = M[$celt.enc.max_sband + 0];
   r0 = M[r5 + $celt.enc.FREQ_FIELD];
   I2 = r0;
   r0 = M[r5 + $celt.enc.BANDE_FIELD];
   I1 = r0;
   r0 = M[r5 + $celt.enc.NORM_FREQ_FIELD];
   I5 = r0;
   call $celt.normalise_bands;
   
   // -- return if it's mono encoding
   r0 = M[r5 + $celt.enc.CELT_CHANNELS_FIELD];
   if Z  jump $pop_rLink_and_rts;
   
   // -- compute band energies (right channel)
   r2 = M[$celt.enc.max_sband + 1];
   r0 = M[r5 + $celt.enc.FREQ2_FIELD];
   I2 = r0;
   r0 = M[r5 + $celt.enc.BANDE_FIELD];
   I1 = r0 + $celt.MAX_BANDSx2;
   
   r0 = M[r5 + $celt.enc.LOG_BANDE_FIELD];
   I5 = r0 + $celt.MAX_BANDS;
   call $celt.compute_band_energies;

   // -- normalise bands (right channel)
   r2 = M[$celt.enc.max_sband + 1];
   r0 = M[r5 + $celt.enc.FREQ2_FIELD];
   I2 = r0;
   r0 = M[r5 + $celt.enc.BANDE_FIELD];
   I1 = r0 + $celt.MAX_BANDSx2;
   
   r0 = M[r5 + $celt.enc.NORM_FREQ_FIELD];
   r1 = M[r5 + $celt.enc.MODE_MDCT_SIZE_FIELD];
   I5 = r0 + r1;
   call $celt.normalise_bands;
      
   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
#endif
