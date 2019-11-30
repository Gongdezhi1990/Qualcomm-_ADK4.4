// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_REQUANTISE_SUBBAND_INCLUDED
#define MP3DEC_REQUANTISE_SUBBAND_INCLUDED

// *****************************************************************************
// MODULE:
//    $mp3dec.requantise_subband
//
// DESCRIPTION:
//    Requantise all samples in a subband.
//
// INPUTS:
//    - r0 = scalefactor, pretab and scalefac_multiplier factor
//    - r1 = number of samples in this sub-band
//    - r4 = 0x200000         (not changed)
//    - I1 = pointer to the first sample of current subband (Read pointer)
//    - I3 = x43_lookup2[-9]  (not changed)
//    - I4 = pointer to the first sample of current subband (Write pointer)
//    - M2 = number of remaining non-zero samples in this grch
//    - M3 = 9                (not changed)
//    - r9 = number of samples from previous region (0 when starting a new region/granule)
//    - I0 = points to the next region size in region_size buffer (see read_huffman for details)
//
// OUTPUTS:
//    - I1 = (Updated)
//    - I4 = (Updated)
//    - M2 = (Updated)
//    - r9 = Number of remaining samples in this region
//    - I0 = (Updated)
//
// TRASHED REGISTERS:
//    r0-3, rMAC, r5-6, DoLoop, I2
//
// *****************************************************************************
.MODULE $M.mp3dec.requantise_subband;
   .CODESEGMENT MP3DEC_REQUANTISE_SUBBAND_PM;
   .DATASEGMENT DM;

   $mp3dec.requantise_subband:

   .VAR sign_r0;
   .VAR requantise_routine;

   // check rzero
   M2 = M2 - r1,
    r5 = M[I1, -1];              // dummy read, rewind
   if POS jump all_non_zero;
      r1 = r1 + M2;
      if LE rts;
   all_non_zero:

   // region check
   Null = r9 - 0;
   if GT jump not_end_of_region;
      r2 = M[I0, 1]; // next region size
      r3 = M[I0, 1]; // is_big flag
      r9 = r2;
      r2 = &start_inner_loop_generic;
      r6 = &start_inner_loop_fast;
      Null = r3;
      if Z r2 = r6;
      M[requantise_routine] = r2;
   not_end_of_region:
   r9 = r9 - r1;


   r6 = M[$mp3dec.adjusted_global_gain];

   // r6 = adjusted scalefactor
   r6 = r6 - r0,
    r0 = M[I1,1];          // read first sample of the subband

   // r5 = scalefactor shift amount
   r5 = r6 ASHIFT -2;

   // r6 = scalefactor multiply factor
   r6 = r6 AND 3;

   r10 = r1;               // r10 = sfb_width

   r2 = M[requantise_routine];
   r6 = M[$mp3dec.two2qtrx_lookup + r6];
   jump r2;

   start_inner_loop_generic:

   do inner_loop_generic;

      r1 =  SIGNDET r0;
      Null = r1 - 18;
      if GE jump x43_first32;
         M[sign_r0] = r0;
         if NEG r0 = -r0;
         r1 = SIGNDET r0;

         I2 = r1 + (&$mp3dec.x43_lookup1 - 9);
         r2 = r0 LSHIFT r1;       // r2 = x'
         Null = r2 AND r4;
         if NZ I2 = I3 + r1;      // I2 = pointer in coef table to use

         r0 = M[I2,M3];           // get exponent coef

         r3 = r5 + r0,            // r3 = (scalefactor shift amount) + Exponent
          rMAC = M[I2,M3];        // get x'^0 coef

         r1 = r2 * r2 (frac),     // r1 = x'^2
          r0 = M[I2,M3];          // get x'^2 coef

         rMAC = rMAC + r1 * r0,
          r0 = M[I2,M3];          // get x'^1 coef
         rMAC = rMAC + r2 * r0;

         rMAC = rMAC * r6;        // now do the * 2^((scalefac+exp)/4)
         rMAC = rMAC ASHIFT r3;

         Null = M[sign_r0];
         if NEG rMAC = -rMAC;
         jump sample_quantised;

      x43_first32:
         rMAC = M[r0 + (&$mp3dec.x43_lookup32 + 32)];          // get exponent coef

         rMAC = rMAC * r6;       // now do the * 2^((scalefac+exp)/4)
         rMAC = rMAC ASHIFT r5;
      sample_quantised:

      M[I4,1] = rMAC,
       r0 = M[I1,1];
   inner_loop_generic:

   rts;


   start_inner_loop_fast:

   do inner_loop_fast;
      rMAC = M[r0 + (&$mp3dec.x43_lookup32 + 32)];          // get exponent coef
      rMAC = rMAC * r6;       // now do the * 2^((scalefac+exp)/4)
      rMAC = rMAC ASHIFT r5;
      M[I4,1] = rMAC,
       r0 = M[I1,1];
   inner_loop_fast:

   rts;


.ENDMODULE;

#endif
