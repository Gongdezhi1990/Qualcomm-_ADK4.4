// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_COMPUTE_ALLOCATION_INCLUDED
#define CELT_COMPUTE_ALLOCATION_INCLUDED
#include "stack.h"

#include "celt.h"
// *****************************************************************************
// MODULE:
//    $celt.compute_allocation
//
// DESCRIPTION:
//    Computes how many pulses are allocated to each band
//
// INPUTS:
//    - r5 = pointer to the structure
//
// OUTPUTS:
//    none
//
// TRASHED REGISTERS:
//    Everything except r5
//
// NOTE: 
//  not optimised, must stay bit-exact  
// *****************************************************************************
.MODULE $M.celt.compute_allocation;
   .CODESEGMENT CELT_COMPUTE_ALLOCATION_PM;
   .DATASEGMENT DM;
   
   $celt.compute_allocation:
   
   // push rLink onto stack
   $push_rLink_macro;

   // see how many bits used so far
   r4 = 0;
   r0 = M[r5 + $celt.dec.TELL_FUNC_FIELD];
   call r0;

   // calc bits available
   r3 = M[r5 + $celt.dec.CELT_CODEC_FRAME_SIZE_FIELD];
   r3 = r3 * 8 (int);
   r3 = r3 - r0;
   r3 = r3 - 1;
   r3 = r3 LSHIFT $celt.BITRES;
   // init:  r6 = lo, r7 = hi
   r6 = 0;
   r7 = M[r5 + $celt.dec.MODE_NB_ALLOC_VECTORS_FIELD];
   r7 = r7 - 1;   
   find_lo_hi_loop:
   r0 = r7 - r6;
   Null = r0 - 1;
   if Z jump end_bits_loop;
      r4 = r6 + r7;
      r4 = r4 LSHIFT -1;
      r10 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
      r0 = r10*r4(int);
      r10 = r10 - 1;
      r1 = M[r5 + $celt.dec.MODE_ALLOC_VECTORS_ADDR_FIELD];
      I6 = r1 + r0;
      r1 = r1 - r1, r0 = M[I6, 1];      
      do bits1_loop;
         r1 = r1 + r0, r0 = M[I6, 1];
      bits1_loop:
      r1 = r1 + r0;
      r2 = (1<<$celt.BITRES);
      r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
      if NZ r2 = r2 + r2;
      r1 = r1 * r2 (int);
      Null = r1 - r3;
      if GT r7 = r4;
      Null = r1 - r3;
      if LE r6 = r4;
   jump find_lo_hi_loop;
   end_bits_loop:
   r10 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
   r0 = r6*r10(int);
   r1 = M[r5 + $celt.dec.MODE_ALLOC_VECTORS_ADDR_FIELD];
   I5 = r0 + r1;
   r0 = r7*r10(int);
   I6 = r0 + r1;
   r0 = M[r5 + $celt.dec.BITS1_FIELD];
   I2 = r0;
   r0 = M[r5 + $celt.dec.BITS2_FIELD];
   I3 = r0;
   r2 = 1;
   r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   if NZ r2 = r2 + r2;
   r10 = r10 - 1;
   r1 = M[I6, 1];
   r1 = r1 * r2(int), r0 = M[I5, 1];
   do bits_loop;
      r0 = r0 * r2(int), r1= M[I6, 1], M[I3, 1] = r1;
      r1 = r1 * r2(int), r0= M[I5, 1], M[I2, 1] = r0;
   bits_loop:
   r0 = r0 * r2(int), M[I3, 1] = r1;
   M[I2, 1] = r0;
   
   call  $celt.interp_bits2pulses;

   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.interp_bits2pulses
//
// DESCRIPTION:
//
// INPUTS:
//    - r5 = pointer to the structure
//
// OUTPUTS:
//    none
//
// TRASHED REGISTERS:
//    Everything except r5
//
// NOTE: 
//  needs optimization, must stay bit-exact    
// *****************************************************************************
.MODULE $M.celt.interp_bits2pulses;
   .CODESEGMENT CELT_INTERP_BITS2PULSES_PM;
   .DATASEGMENT DM;
   
   $celt.interp_bits2pulses:
   // push rLink onto stack
   $push_rLink_macro;
   r6 = 0;
   r7 = 1<<$celt.BITRES;
   M0 = 1;
   find_hi_lo_loop:
   r0 = r7 - r6;
   Null = r0 - 1;
   if Z jump find_hi_lo_loop_end;
      r4 = r6 + r7;
      r4 = r4 LSHIFT -1;
      r10 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
      r10 = r10 - 1;
      r2 = 1<<$celt.BITRES;
      r2 = r2 - r4;
      r0 = M[r5 + $celt.dec.BITS1_FIELD];
      I2 = r0;
      r0 = M[r5 + $celt.dec.BITS2_FIELD];
      I3 = r0;
      rMAC = 0, r0 = M[I2, 1];
      rMAC = rMAC + r0*r2, r0 = M[I3, 1];
      do avg_loop1;
         rMAC = rMAC + r0*r4, r0 = M[I2, 1];
         rMAC = rMAC + r0*r2, r0 = M[I3, 1];
      avg_loop1:
      rMAC = rMAC + r0*r4;
      r0 = rMAC LSHIFT 23;
      Null = r0 - r3;
      if GT r7 = r4;
      Null = r0 - r3;
      if LE r6 = r4;
   jump find_hi_lo_loop;
   
   find_hi_lo_loop_end:
   r0 = M[r5 + $celt.dec.BITS1_FIELD];
   I2 = r0;
   r0 = M[r5 + $celt.dec.BITS2_FIELD];
   I3 = r0;
   r0 = M[r5 + $celt.dec.PULSES_FIELD];
   I4 = r0;
   r10 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
   r2 = 1<<$celt.BITRES;
   r2 = r2 - r6;
   rMAC = 0, r0 = M[I2, 1];
   do avg_loop2;
      r0 = r0*r2 (int), r1 = M[I3, 1];
      r1 = r1 * r6 (int);
      r4 = r1 + r0, r0 = M[I2, M0];
      rMAC = rMAC + r4, M[I4, 1] = r4;
   avg_loop2:   
   
   r10 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
   rMAC = r3 - rMAC;
   rMAC0 = rMAC1;
   rMAC12 = Null(ZP);
   Div = rMAC/r10;
   r0 = M[r5 + $celt.dec.PULSES_FIELD];
   I2 = r0;
   I3 = I2;
   r0 = M[I2, M0];   
   r2 = DivResult;
   do add_per_band_loop;
      r1 = r0 +  r2, r0 = M[I2, M0];
      M[I3, M0] = r1;
   add_per_band_loop:
   
   r10 = DivRemainder;
   r2 = 1;
   r0 = M[r5 + $celt.dec.PULSES_FIELD];
   I2 = r0;
   I3 = I2, r0 = M[I2, M0];   
   do add_reamin_loop;
      r1 = r0 +  r2, r0 = M[I2, M0];
      M[I3, M0] = r1;
   add_reamin_loop:  
   
   r3 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
   M3 = r3;
   M1 = 0;
   r0 = M[r5 + $celt.dec.MODE_EBANDS_ADDR_FIELD];
   I3 = r0;
   r0 = M[r5 + $celt.dec.PULSES_FIELD];
   I2 = r0;        
   r0 = M[r5 + $celt.dec.FINE_QUANT_FIELD];
   I6 = r0;     
   r0 = M[r5 + $celt.dec.FINE_PRIORITY_FIELD];
   I7 = r0;  //fine-pr
   r0 = M[I3, 1];   //ebands[j];
   r1 = M[I3, 0];   
   //N=r1
   loop_calc_bits:
      r1 = r1 - r0; 
      push r1;         //save r1
      rMAC = 0;        //rMAC=N
      rMAC0 = r1;
      r0 = $celt.BITRES; 
      call $celt.log2_frac;       
      r3 = $celt.FINE_OFFSET - r0; 
      //offset = r3
      pop r1;
      r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD]; 
      r4 = r0*r1(int);                            
      r4 = r4 + r1;                               
      r2 = r4 + r0;                               
      r2 = r2 LSHIFT $celt.BITRES;                
      r4 = r4 *r3(int), r1 = M[I2, 0];            
      r4 = r1 - r4;                               
      r1 = r0 LSHIFT $celt.BITRES;                
      r4 = r4 - r1;                               
      if NEG r4 = 0; 
      //r4 = offset
      r1 = r2 + r2;                               
      r6 = r4 + r4;                               
      r6 = r6 + r2;                               
      rMAC = 0;
      rMAC0 = r6;
      Div = rMAC / r1; 
      r6 = DivResult;                             
      r3 = r6 * r2 (int);                         
      r1 = 1;
      Null = r3 - r4;
      if NEG r1 = r1 - r1, r3 = M[I2, M1];
      //r1 = fine-p
      r2 = r6 LSHIFT r0; //r7=eb(j)*C
      r4 = r3 LSHIFT (-$celt.BITRES);
      Null = r2 - r4;                     
      if GT r2 = r4;
      r6 = -r0;
      r2 = r2 LSHIFT r6, M[I7, 1] = r1; 
      r7 = r2 - 7;
      if POS r2 = r2 - r7;
      r0 = r0 + $celt.BITRES;
      r2 = r2 LSHIFT r0, M[I6, 1] = r2;
      r3 = r3 - r2, r0 = M[I3, 1];
      if NEG r3 = r3 - r3, r1 = M[I3, M1];
      M3 = M3 - M0, M[I2, 1] = r3;
   if NZ jump   loop_calc_bits;    
   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;
#endif
