// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CELT_MDCT_RADIX2_INCLUDED
#define CELT_MDCT_RADIX2_INCLUDED
#include "stack.h"
#include "fft.h"
// *****************************************************************************
// MODULE:
//    $celt.window_mdct_radix2
//
// DESCRIPTION:
//
// INPUTS:
// inputs:
//   I0 = input
//   I5 = output 
//   r8 = imdct size
//   r4 =
//   r6 = 0 -> left 1-> right
// TRASHED REGISTERS:
//    Assume everthing
//
// NOTET:
// 1- CELT supports any even frame size value between 64 and 512 samples, this function
//   is usable only for radix2 frame sizes, for other frame size values, an external
//   function is required to do IMDCT operation with the same interface
// 2- The code is similar to AAC decoder imdct, with some modifications
// ***************************************************************************************
.MODULE $M.celt.mdct_radix2;
   .CODESEGMENT CELT_MDCT_RADIX2_PM;
   .DATASEGMENT DM;
   $celt.mdct_radix2:
   // push rLink onto stack
   $push_rLink_macro;

   .VAR scale_factor;
   .VAR tmp_var;
   
   .VAR temp[6];
   M[temp + 0] = r8;
   r0 = I6;
   M[temp + 1] = r0;
   r0 = I7;
   M[temp + 2] = r0;
   r0 = I0;
   M[temp + 3] = r0; 
   M[temp + 5] = r5;
   
   
  
   // get scale factor from mode object
   r0 = M[r5 + $celt.enc.MODE_TRIG_OFFSET_FIELD];
   r1 = &$celt.mode.TRIG_VECTOR_SIZE;
   NULL = M[r5 + $celt.enc.SHORT_BLOCKS_FIELD];
   if Z r1 = 0;
   I2 = r0 + r1;
   M[temp + 4] = r0 + r1; 
   r0 = M[I2, 1];
   r0 = M[I2, 1];
   M[scale_factor] = r0;


   
   r2 = r8 LSHIFT -1;
   M[$celt.enc.fft_struct + $fft.NUM_POINTS_FIELD] = r2;
   r0 = I6;
   M[$celt.enc.fft_struct + $fft.REAL_ADDR_FIELD] = r0;
   r0 = I7;
   M[$celt.enc.fft_struct + $fft.IMAG_ADDR_FIELD] = r0;
   
   // compensation for negative global scale factors
   rMAC = r4;
   if POS jump no_further_scale;
      // get the size of fft (N)
      r2 = signdet r2;
      r2 = 22 - r2;
      
      // calc g = 2.0**(s / N)
      rMAC = rMAC ASHIFT -8 (56bit);
      Div = rMAC / r2;
      r0 = DivResult;      
      call $math.pow2_taylor;
      
      // sf = sf * g
      r1 = M[scale_factor];
      r1 = r1 * r0 (frac);
      M[scale_factor] = r1;
   no_further_scale:
   
   
   M3 = 4;
   M0 = 1;
   M1 = 0;
   r2 = M[I2,M0];
   r3 = M[I2, M0];
   r4 = M[I2, M0], r0 = M[I6, M1];
   r4 = - r4, r5 = M[I2, M0];
   r5 = - r5;
   I1 = &tmp_var;
   prerot_outer_loop:
      r10 = r8 LSHIFT -3;
      do prerot_inner_loop;
         rMAC = r0*r4,  r1 = M[I7, M1];
         rMAC = rMAC + r5*r1;
         rMAC = r1*r4, M[I6, M0] = rMAC;
         rMAC = rMAC - r0*r5;
         
         // update the multipliers: "c" and "s"
         rMAC = r4 * r2, M[I7, M0] = rMAC;      // (-c) * cfreq
         rMAC = rMAC - r5 * r3, r0 = M[I6, M1]; // (-c)'= (-c) * cfreq - (-s) * sfreq
         rMAC = r4 * r3, M[I1,M1] = rMAC;       // (-c_old) * sfreq
         rMAC = rMAC + r5 * r2;                 // (-s)' = (-c_old)*sfreq + (-s)*cfreq
         r5 = rMAC, r4 = M[I1,M1];              // r5 = (-s)'
      prerot_inner_loop:
      // load the constant points mid way to improve accuracy
      r4 = M[I2,M0];
      r4 = -r4, r5 = M[I2,M0];
      r5 = -r5;      
      M3 = M3 - M0;
   if NZ jump prerot_outer_loop;
   
   
   // set up data in fft_structure
   I7 = &$celt.enc.fft_struct;
   // -- call the ifft --
   r8 = M[scale_factor];
   //r8 = r8 * r8 (frac);
   call $math.scaleable_fft;


   r8 = M[temp + 0];
   r0 = M[temp + 3];  
   I4 = r0;
   I5 = I4 + r8;
   I5 = I5 - 1;
      
   r0 = M[temp + 4];
   I7 = r0 + 2;

   // calculate some bit reverse constants
   r6 = SIGNDET r8; // perform the last memory write
   #if defined(KAL_ARCH3) || defined(KAL_ARCH5)
   r6 = r6 + 2;                     
   #else
   r6 = r6 - 6;                     
   #endif
   r6 = 1 LSHIFT r6;
   M2 = r6;                         // bit reverse shift register
   r0 = M[temp + 1];
   call $math.address_bitreverse;
   I0 = r1;
   r0 = M[temp + 2];
   call $math.address_bitreverse;
   I1 = r1;
 
   // data is returned bit reversed, so enable bit reverse addressing on AG1
   rFlags = rFlags OR $BR_FLAG;

   // load bit reversed tmp c location
   I2 = BITREVERSE(&tmp_var);

   r6 = 4;
   M3 = -2;
   M0 = 1;
   M1 = 0;
   r2 = M[I7,M0];
   r3 = M[I7, M0];
   r4 = M[I7, M0], r0 = M[I1, M2];
   r5 = M[I7, M0];
   postrot_outer_loop:
      M0 = 2;
      r10 = r8 LSHIFT -3;
      do postrot_inner_loop;
         rMAC = r0*r5,  r1 = M[I0, M2];
         rMAC = rMAC + r4*r1;
         rMAC = r1*r5, M[I4, M0] = rMAC;
         rMAC = rMAC - r0*r4;
         
         // update the multipliers: "c" and "s"
         rMAC = r4 * r2, M[I5, M3] = rMAC;      // (-c) * cfreq
         rMAC = rMAC - r5 * r3, r0 = M[I1, M2]; // (-c)'= (-c) * cfreq - (-s) * sfreq
         rMAC = r4 * r3, M[I2,M1] = rMAC;       // (-c_old) * sfreq
         rMAC = rMAC + r5 * r2;                 // (-s)' = (-c_old)*sfreq + (-s)*cfreq
         r5 = rMAC, r4 = M[I2,M1];              // r5 = (-s)'
      postrot_inner_loop:
      // load the constant points mid way to improve accuracy
      M0 = 1;
      r4 = M[I7, M0];
      r6 = r6 - M0, r5 = M[I7,M0];
   if NZ jump postrot_outer_loop;

   rFlags = rFlags AND $NOT_BR_FLAG;
   
    r5 = M[temp + 5];
   // pop rLink from stack
   jump $pop_rLink_and_rts;


.ENDMODULE;


#endif
