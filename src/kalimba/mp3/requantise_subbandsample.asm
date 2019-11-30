// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_REQUANTISE_SUBBANDSAMPLE_INCLUDED
#define MP3DEC_REQUANTISE_SUBBANDSAMPLE_INCLUDED

// *****************************************************************************
// MODULE:
//    $mp3dec.requantise_subbandsample
//
// DESCRIPTION:
//    Requantise subband sample
//
// INPUTS:
//    - r0 = huffman value
//    - r4 = 0x200000
//    - r5 = scalefactor shift amount
//    - r6 = scalefactor multiply fraction
//    - I3 = x43_lookup2[-9]
//    - M3 = 9
//    - M2 = 32
//
// OUTPUTS:
//    - rMAC = Requantised subband samples
//           = (r0 ^ (4/3) * scalefactor_faction) << scalefactor_shift
//
// TRASHED REGISTERS:
//    r0-r3, I2
//
// *****************************************************************************
.MODULE $M.mp3dec.requantise_subbandsample;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $mp3dec.requantise_subbandsample:

   Null = r0 - 32;
   if NEG jump x43_first32;

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
      rts;

   x43_first32:
   I2 =  r0 + &$mp3dec.x43_lookup32;
   r0 = M[I2,M2];          // get exponent coef

   r3 = r5 + r0,           // r3 = (scalefactor shift amount) + Exponent
    rMAC = M[I2,M2];       // get x'^0 coef

   rMAC = rMAC * r6;       // now do the * 2^((scalefac+exp)/4)
   rMAC = rMAC ASHIFT r3;
   rts;

.ENDMODULE;

#endif