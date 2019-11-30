// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_PITCH_INCLUDED
#define CELT_PITCH_INCLUDED
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.pitch_downsample
//
// DESCRIPTION:
//    downsamples time domains vector before searching for pitch
//    out(n)=(in(2*n-1)+in(2*n+1)+2*in(2*n))/4
// INPUTS:
//    I5/L5 = input
//    I1/L1 = output
//    r8 = vector length
// OUTPUTS:
// 
// TRASHED REGISTERS:
// 
// NOTE:
//   - can be in place
// *****************************************************************************
.MODULE $M.celt.pitch_downsample;
   .CODESEGMENT CELT_PITCH_DOWNSAMPLE_PM;
   .DATASEGMENT DM;
   $celt.pitch_downsample:  
   r10 = r8 LSHIFT -1;
   r10 = r10 - 1;
   r3 = 0.5;
   r4 = 0.25;              
   rMAC = 0, r2 = M[I5, 1];               
   do pitch_downsample_loop;
      rMAC = rMAC + r2*r3, r0 = M[I5, 1];  
      rMAC = rMAC + r0*r4, r2 = M[I5, 1];   
      rMAC = r0*r4, M[I1, 1] = rMAC;       
   pitch_downsample_loop:
   rMAC = rMAC + r2*r3, r0 = M[I5, 1];  
   rMAC = rMAC + r0*r4;   
   M[I1, 1] = rMAC;      
   rts;   
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.pitch_search
//
// DESCRIPTION:
//    search for pitch index 
// INPUTS:
//    r5 = pointer to celt_dec structure
//    I5 = input
//    I4 = lag input
//    r8 = len
//    M[max_pitch] = max pitch to search
//    M[lag] = max lag to consider
// OUTPUTS:
//    r4 = pitch index
// TRASHED REGISTERS:
// 
// NOTE:
// 
// ***************************************************************************** 
.MODULE $M.celt.pitch_search;
   .CODESEGMENT PITCH_SEARCH_PM;
   .DATASEGMENT DM;
   $celt.pitch_search:
   $push_rLink_macro;
   
   // -- Downsample by 2 again(main)
   r10 = r8 LSHIFT -2;
   r10 = r10 - 1;
   I6 = I5;
   I7 = I4;
   r0 = M[r5 + $celt.dec.PLC_XLP4_FIELD];
   I0 = r0;
   r0 = M[I6, 2];
   do down_2_first_lp;
      M[I0, 1] = r0, r0 = M[I6, 2];
   down_2_first_lp:
   M[I0, 1] = r0;

   // -- Downsample by 2 again(lag) 
   r10 = M[$celt.dec.lag];
   r10 = r10 - 1;
   r0 = M[r5 + $celt.dec.PLC_YLP4_FIELD];
   I0 = r0;
   r0 = M[I7, 2];
   do down_2_second_lp;
      M[I0, 1] = r0, r0 = M[I7, 2];
   down_2_second_lp:
   M[I0, 1] = r0;

   // -- Calc cross correllation
   r0 = M[$celt.dec.max_pitch];
   r0 = r0 LSHIFT -2;
   M0 = r0;
   M3 = -1;
   r6 = r8 LSHIFT -2;
   r0 = M[r5 + $celt.dec.PLC_XCORR_FIELD];
   I2 = r0;
   r4 = 8;
   r0 = M[r5 + $celt.dec.PLC_YLP4_FIELD];
   I3 = r0 + M0;
   M1 = 1;
   r7 = M[r5 + $celt.dec.PLC_XLP4_FIELD];
   coarse_search_loop:
      I0 = I3 - M0;
      I6 = r7;
      r10 = r6 - 1;
      rMAC = 0, r1 = M[I6, 1], r0 = M[I0, 1];
      do calc_sum_e_lp;
         rMAC = rMAC + r0*r1, r1 = M[I6, 1], r0 = M[I0, 1];  //TODO: make sure to put in different DMs
      calc_sum_e_lp:
      rMAC = rMAC + r0*r1;
      r4 = blksigndet rMAC, M[I2, 1] = rMAC;
      M0 = M0 - 1;   
   if NZ jump coarse_search_loop;

   // -- first search for pitch in xcor verctor
   r0 = M[$celt.dec.max_pitch];
   r0 = r0 LSHIFT -2;
   M3 = r0;
   r8 = r8 LSHIFT -2;
   r0 = M[r5 + $celt.dec.PLC_YLP4_FIELD];
   I3 = r0;
   r0 = M[r5 + $celt.dec.PLC_XCORR_FIELD];
   I6 =r0; 
   call $celt.find_best_pitch;
   r8 = r8 LSHIFT 2;
   
   // -- Reset xcorr
   r0 = M[$celt.dec.max_pitch];
   r0 = r0 LSHIFT -1;
   M3 = r0;
   r10 = r0;
   r0 = M[r5 + $celt.dec.PLC_XCORR_FIELD];
   I2 = r0;
   r0 = 0;
   do zero_xcor_loop;
      M[I2, 1] = r0;
   zero_xcor_loop:

   // -- fine xcorr arround the initial pitch search with higher resolution
   // TODO: code size optimisation
   r6 = M1 + M1; // lower estimate
   r7 = M2 + M2; // upper estimate
   Null = r6 - r7;
   if POS jump end_exch;
      r7 = r6;
      r6 = M2 + M2;
   end_exch:
   M3 = r7 - 2;  
   if NEG M3 = 0;
   M0 = r6 + 3; 
   r0 = M[$celt.dec.max_pitch];
   r0 = r0 LSHIFT -1;
   r1 = M0 - r0;
   if POS M0 = r0;
   r7 = r7 + 2;
   r6 = r6 - 2;
   I6 = I5;
   I7 = I4;
   r0 = M[r5 + $celt.dec.PLC_XCORR_FIELD];
   I2 = r0 + M3; 
   M2 = 1;
   r4 = 8;
   fine_search_loop:
     Null = M3 - r7;
     if LE jump do_update;
     Null = M3 - r6;
     if NEG jump end_update;
     do_update:
        I6 = I5;
        I3 = I4 + M3;
        r10 = r8 LSHIFT -1;
        r10 = r10 - 1;
        rMAC = 0, r0 = M[I3, 1], r1 = M[I6, 1];
        do calc_en_lp;
           rMAC = rMAC + r0* r1,  r0 = M[I3, 1], r1 = M[I6, 1];
        calc_en_lp:
        rMAC = rMAC + r0*r1;
        r4 = blksigndet rMAC, M[I2, 0] = rMAC;
   end_update:
   M3 = M3 + M2, r0 = M[I2, 1];
   Null = M3 - M0;
   if NZ jump fine_search_loop;
   
   // -- Search again with higher resolution
   r0 = M[$celt.dec.max_pitch];
   r0 = r0 LSHIFT -1;
   M3 = r0;
   r8 = r8 LSHIFT -1;
   I3 = I4;
   r0 = M[r5 + $celt.dec.PLC_XCORR_FIELD];
   I6 = r0;
   call $celt.find_best_pitch;
   r8 = r8 LSHIFT 1;
   
   // -- Input was downsampled, see if an offset +-1 is needed
   r7 = 0; 
   Null = M2;
   if Z jump end_offset_calc;
      r0 = M[$celt.dec.max_pitch];
      r0 = r0 LSHIFT -1;
      r0 = r0 - 2;
      Null = r0 - M1;
      if NEG jump end_offset_calc;
      r0 = M[r5 + $celt.dec.PLC_XCORR_FIELD];
      r0 = M2 + r0;
      r1 = M[r0+(-1)];
      r2 = M[r0];
      r3 = M[r0 + 1];
      r0 = r3 - r1;
      r4 = r2 - r1;
      r4 = r4 * 0.7(frac);
      r7 = 1;
      Null = r0 - r4;
      if GT jump end_offset_calc;
      r7 = -1;
      r4 = r2 - r3;
      r4 = r4 * 0.7(frac);
      Null = r4 + r0;
      if POS r7 = 0;
   end_offset_calc:
   r4 = M2 + M2;
   r4 = r4 - r7;
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.find_best_pitch
//
// DESCRIPTION:
//   find best pitch using xcorr vector
// INPUTS:
//   M3 = max pitch to search
//   r8 = vector len
//   I6 = xcorr vector
//   I3 = lag vector
// OUTPUTS:
//   
// TRASHED REGISTERS:
// 
// NOTE: 
// TODO: use simpler pitch search if possible
// ***************************************************************************** 
.MODULE $M.celt.find_best_pitch;
   .CODESEGMENT CELT_FINE_BEST_PITCH_PM;
   .DATASEGMENT DM;
   $celt.find_best_pitch:
   push r8;
   push r5;
   r5 =  r4;
   r10 = r8 - 1;
   I2 = I3;
   rMAC = 0, r0 = M[I2, 1];
   do calc_syy_loop;
      rMAC = rMAC + r0*r0, r0 = M[I2, 1];
   calc_syy_loop:
   rMAC = rMAC + r0*r0;

   I2 = I3 + r8; 
   I1 = I3;
   r0 = M[I6, 1];
   M0 = 0; 
   //  best_num   -> r7:r4
   //  best_den   -> r8:r10
   //  best_pitch -> M1:M2
   r8 = rMAC;
   r4 = -1;
   r7 = -1;
   r10 = 0;
   r6  = 0;
   M2  = 0;
   M1  = 1;
   I0 = 1;
   
   // Full rMAC is needed for higher resolution
   // TODO: BC7 use second rMAC
   r2 = rMAC0;
   r3 = rMAC1;
   find_pitch_loop:
      Null = r0 + Null;
      if LE jump end_best_update;
         r0 = r0 ASHIFT r5;
         r1 = r0 * r0 (frac);
         rMAC = r1*r6;
         rMAC = rMAC - r8*r7;
         if LE jump end_best_update;
            rMAC = r1*r10;
            rMAC = rMAC - r4*r8;
            if LE jump update_1_only;
               r7 = r4;
               r6 = r10;
               M1 = M2;
               r4 = r1;
               r10 = r8;
               M2 = M0;
            jump end_best_update;
            update_1_only:
               r7 = r1;
               r6 = r8;
               M1 = M0;
      end_best_update:
      r0 = M[I2, 1];
      rMAC = r3;
      rMAC0 = r2;
      rMAC = rMAC + r0*r0, r0 = M[I3, 1];
      rMAC = rMAC - r0*r0, r0 = M[I6, 1];    
      if LE rMAC = I0;   
      r2 = rMAC0;
      r3 = rMAC1;
      r8 = rMAC;
      M0 = M0 + 1;
      M3 = M3 - 1;
   if NZ jump find_pitch_loop;
   pop r5;
   pop r8;
   rts;
  .ENDMODULE;
#endif
