// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef  CELT_MATH_FUNCTIONS_INCLUDED
#define  CELT_MATH_FUNCTIONS_INCLUDED
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.idiv32
//
// DESCRIPTION:
//   unsigned 32 bit division
//
// INPUTS:
//    r1:r0 = divisor
//    r3:r2 = dividend
// OUTPUTS:
//    r7:r6 = quotient (exact)
// TRASHED REGISTERS:
//  rMAC, r0, r3, r4, r8, r10, M1
// NOTE:
// - max 48 cycles
// - code 53 words
// - must be put in RAM
// TODO:OPT NEEDED
// ****************************************************************************
.MODULE $M.celt.idiv32;
   .CODESEGMENT CELT_IDIV32_PM;
   .DATASEGMENT DM;
   $celt.idiv32:
   #if !defined(KAL_ARCH3) && !defined(KAL_ARCH5)
   
      // normalise divisor  to 23 bits
      rMAC12 = r3(ZP);
      rMAC0 = r2;
      r10 = signdet rMAC;
      r4 = rMAC LSHIFT r10;

      // shift dividend   to 45 bits
      rMAC12 = r1(ZP);
      rMAC0 = r0;
      r7 = signdet rMAC;
      r7 = r7 - 2;
      r8 = r7 + 24;
      r8 = rMAC LSHIFT r8;
      rMAC = rMAC LSHIFT r7;
      rMAC0 = r8;

      // divide normalised dividend/divisor
      Div = rMAC / r4;

      // divisor truncated when normalise?
      r8 = r10 - 24;
      if NEG jump truncate_proc;
      // which one shifted more dividend or divisor?
      r8 = r8 - r7;
      if POS jump div_rem;
         // result will be less than 23 bits
         r7 = 0;
         r6 = DivResult;
         r6 = r6 LSHIFT r8;
         rts;
      div_rem:
      // result might be more than 23 bits
      r10 = r8 - 24;
      r7 = DivResult;
      r6 = r7 LSHIFT r8;
      r7 = r7 LSHIFT r10;
      // divide the remainder to divisor 
      r0 = DivRemainder;
      rMAC = r0 LSHIFT r10;
      r0 = r0 LSHIFT r8;
      rMAC0 = r0;      
      Div = rMAC / r4;
      // add result to previous division result
      r4 = DivResult;
      r6 = r6 + r4;
      r7 = r7 + carry;
      rts;
      truncate_proc:
         // divisor truncated, 
         r8 = r8 - r7;
         r7 = DivResult;
         r6 = r7 LSHIFT r8;
         r8 = r8 - 24;
         r7 = r7 LSHIFT r8;
         // the result might be one more than the actual value
         rMAC = r6*r2 (UU);
         r8 = rMAC LSHIFT 23;
         rMAC0 = rMAC1;
         rMAC12 = rMAC2(ZP);
         rMAC = rMAC + r7*r2(SU);
         rMAC = rMAC + r6*r3(SU);
         r4 = rMAC LSHIFT 23;
         Null = r0 - r8;
         Null = r1 - r4 -borrow;
         if POS rts;
            r6 = r6 - 1;
            r7 = r7 - borrow;
      rts;
   #else //#if !defined(KAL_ARCH3) && !defined(KAL_ARCH5)
      rMAC12 = r3(ZP);
      rMAC0 = r2;
      r10 = signdet rMAC;
      r4 = rMAC LSHIFT r10;

      rMAC12 = r1(ZP);
      rMAC0 = r0;
      r7 = signdet rMAC;
      r7 = r7 - 2;
      rMAC = rMAC LSHIFT r7 (56bit);

      Div = rMAC / r4;
      r8 = r10 - 24;
      if NEG jump truncate_proc;
      r8 = r8 - r7;
      if POS jump div_rem;
         r7 = 0;
         r6 = DivResult;
         r6 = r6 LSHIFT r8;
         rts;
      div_rem:
      r10 = r8 - 24;
      r7 = DivResult;
      r6 = r7 LSHIFT r8;
      r7 = r7 LSHIFT r10;
      
      rMAC = DivRemainder;
      rMAC = rMAC LSHIFT r10 (56bit);
      Div = rMAC / r4;
      r4 = DivResult;
      r6 = r6 + r4;
      r7 = r7 + carry;

      rts;
      truncate_proc:
         r8 = r8 - r7;
         r7 = DivResult;
         r6 = r7 LSHIFT r8;
         r8 = r8 - 24;
         r7 = r7 LSHIFT r8;
         rMAC = r6*r2 (UU);
         r8 = rMAC LSHIFT 23;
         rMAC0 = rMAC1;
         rMAC12 = rMAC2(ZP);
         rMAC = rMAC + r7*r2(SU);
         rMAC = rMAC + r6*r3(SU);
         r4 = rMAC LSHIFT 23;
         Null = r0 - r8;
         Null = r1 - r4 -borrow;
         if POS rts;
            r6 = r6 - 1;
            r7 = r7 - borrow;
      rts;
#endif //#if !defined(KAL_ARCH3) && !defined(KAL_ARCH5)
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.log2_frac
//
// DESCRIPTION:
//   log2 function(must be bit exact)
//
// INPUTS:
//    rMAC = input
// OUTPUTS:
//    r0  = output
// TRASHED REGISTERS:
//  rMAC, r2, r2, r6, r7
// NOTE:
// TODO:OPT NEEDED
// ****************************************************************************
.MODULE $M.celt.log2_frac;
   .CODESEGMENT CELT_LOG2_FRAC_PM;
   .DATASEGMENT DM;
   $celt.log2_frac:
   r1 = signdet rMAC;
   #if defined(KAL_ARCH3) || defined(KAL_ARCH5)
      r1 = r1 -7;
      rMAC = rMAC ASHIFT r1(56bit);
      r1 = 40 -r1;
   #else
      r1 = r1 -6;
      rMAC = rMAC ASHIFT r1;
      rMAC = rMAC * 0.5 (frac);
      r1 = 41 - r1;
   #endif
   r2 = 1 LSHIFT r0;
   r1 = r1 - 1;
   r10 = r0+1;
   r6 = 0.5;
   r0 = r1 LSHIFT r0;  
   r7 = (0x7FFF);
   r1 = 1;
   do comp_loop;
      NULL = rMAC LSHIFT -16;
      if NZ r0 = r0 + r2;
      Null = rMAC LSHIFT -16;
      if NZ rMAC = rMAC * r6 (frac);
      rMAC = rMAC * rMAC;
      rMAC = rMAC + r1 * r7;
      rMAC = rMAC LSHIFT 8;
      r2 = r2 LSHIFT -1;
   comp_loop:
   rMAC = rMAC - 0x8000;
   if GT r0 = r0 + r1; 
   rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.imusdiv32
//
// DESCRIPTION:
//   calc (ab - c) /d
//
// INPUTS:
//    r1:r0 = a
//    r2:r3 = b
//    r4:r5 = c
//    r10 = d (8 bit)
// OUTPUTS:
//   r2:r3 = output
// TRASHED REGISTERS:
//  rMAC, r5-r8, rMAC
// NOTE:
// TODO:OPT NEEDED TODO:BC7OPT
// ****************************************************************************
.MODULE $M.celt.imusdiv32;
   .CODESEGMENT CELT_IMUSDIV32_PM;
   .DATASEGMENT DM;
   $celt.imusdiv32:
   
   // calc a*b
   rMAC = r0 * r2 (UU);
   r6 = rMAC LSHIFT 23;
   rMAC0 = rMAC1;
   rMAC12 = rMAC2 (ZP);
   rMAC = rMAC + r1 * r2 (SU);
   rMAC = rMAC + r3 * r0 (SU);
   r7 = rMAC LSHIFT 23;
   rMAC0 = rMAC1;
   rMAC12 = rMAC2 (SE);
   rMAC = rMAC + r1 * r3 (SS);
   r8 = rMAC LSHIFT 23;
   
   // calc a*b-c
   r6 = r6 - r4;
   r7 = r7 - r5 - Borrow;
   r8 = r8 - Borrow;
   
   // divide to d (result can be up to 32 bits)
   rMAC  = r8; 
   rMAC0 = r7;
   Div = rMAC/r10;
   r3 = DivResult;
   r2 = DivRemainder;
   r8 = r10 LSHIFT 1;
   rMAC = r2;
   rMAC0 = r6;
   Div = rMAC/r8;
   r2 = DivResult;
   r8 = DivRemainder;
   r2 = r2 + r2;
   r7 = 1;
   Null = r8 - r10;
   if POS r2 = r2 + r7;
   rts;
 .ENDMODULE;
 
 // *****************************************************************************
 // MODULE:
 //    $celt.bitexact_cos
 //
 // DESCRIPTION:
 //   calc bit exact cosine as defined in celt reference
 //
 // INPUTS:
 //    r0 = input
 // OUTPUTS:
 //   r1 = output
 // TRASHED REGISTERS:
  // NOTE:
 // TODO:OPT NEEDED TODO:BC7OPT
 // ****************************************************************************
 .MODULE $M.celt.bitexact_cos;
    .CODESEGMENT CELT_IMUSDIV32_PM;
    .DATASEGMENT DM;
   $celt.bitexact_cos:
   rMAC = r0*r0;
   r3 = 1;
   rMAC = rMAC + r3*4096;
   r2 = rMAC ASHIFT (24-14);
   rMAC = r2 - 32767;
   if POS r2 = r2 - rMAC;
   
   rMAC = r2 * (-626);
   rMAC = rMAC + r3*16384;
   rMAC = rMAC ASHIFT 8;
   rMAC = rMAC + 8277;
   
   rMAC = r2 * rMAC;
   rMAC = rMAC + r3*16384;
   rMAC = rMAC ASHIFT 8;
   rMAC = rMAC - 7651;
   
   rMAC = r2 * rMAC;
   rMAC = rMAC + r3*16384;
   rMAC = rMAC ASHIFT 8;
   r2 = rMAC - r2;
   if POS r2= -r3;
   r2 = r2 + 32768;
      
   rts;
 .ENDMODULE;
#endif
