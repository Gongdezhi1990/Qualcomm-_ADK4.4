// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CELT_PREEMPHASIS_INCLUDED
#define CELT_PREEMPHASIS_INCLUDED
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.preemphasis
//
// DESCRIPTION:
//   applying preempahsis filter to the input
//
// OUTPUTS:
//  I5/L5 in-place input/output buffer 
//  r5 = object
//  r10 = frame size
//  r7 = channel (0-> left, 1->right)
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.preemphasis;
   .CODESEGMENT CELT_PREEMPHASIS_PM;
   .DATASEGMENT DM;
   $celt.preemphasis:

   r0 = M[$celt.enc.left_ibuf_addr];
   r1 = M[$celt.enc.left_ibuf_len];
   I5 = r0;
   L5 = r1;
#ifdef BASE_REGISTER_MODE  
   r0 = M[$celt.enc.left_ibuf_start_addr];
   push r0; 
   pop B5;
#endif 
   r0 = M[r5 + $celt.enc.PREEMPH_LEFT_AUDIO_FIELD];
   I0 = r0;
   r3 = 0.5;//0.5; //scale factor
   r0 = M[r5 + $celt.enc.CELT_CHANNELS_FIELD];
   M0 = r0 + 1;
   r4 = M[r5 + $celt.enc.MODE_E_PRED_COEF_FIELD];   //r0 = alpha
   r4 = -r4;
   r4 = r4 * r3(frac);
   r6 = r5;
   r0 = M[r5 + $celt.enc.HIST_OLA_LEFT_FIELD];
   I6 = r0;
   chan_loop:
      I1 = I0;
      r0 = M[r5 + $celt.enc.MODE_OVERLAP_FIELD];
      I0 = I0 + r0;
      r10 = M[r5 + $celt.enc.MODE_AUDIO_FRAME_SIZE_FIELD];
      r10 = r10 - 1;
      r2 = M[r6 + $celt.enc.PREEMPH_HIST_SAMPLE_FIELD];  
      r1 = M[I5, 0];
      rMAC = r2 * r4, r2 = M[I5, 1];                                                             
      do deemphasis_loop;
         rMAC = rMAC + r1 * r3, r1 = M[I5, 0];
         //rMAC = rMAC ASHIFT 1;
         rMAC = r4 * r2, M[I0, 1] = rMAC, r2 = M[I5, 1]; 
      deemphasis_loop:
      rMAC = rMAC + r1 * r3;
      //rMAC = rMAC ASHIFT 1;
      M[I0, 1] = rMAC;
      M[r6 + $celt.enc.PREEMPH_HIST_SAMPLE_FIELD] = r2;      
      
      // copy overlap
      r10 = M[r5 + $celt.enc.MODE_OVERLAP_FIELD];
      I0 = I0 - r10;
      do copy_hist_ola_loop;
         r0 = M[I0, 1], r1 = M[I6, 0];
         M[I1, 1] = r1, M[I6, 1] = r0;
      copy_hist_ola_loop:
      
      // set up registers for second channel
      r0 = M[$celt.enc.right_ibuf_addr];
      r1 = M[$celt.enc.right_ibuf_len];
      I5 = r0;
      L5 = r1;
#ifdef BASE_REGISTER_MODE        
      r0 = M[$celt.enc.right_ibuf_start_addr];
      push r0;
      pop B5;
#endif      
      r6 = r6 + 1;
      r0 = M[r5 + $celt.enc.PREEMPH_RIGHT_AUDIO_FIELD];
      I0 = r0; 
      r0 = M[r5 + $celt.enc.HIST_OLA_RIGHT_FIELD];
      I6 = r0;
      // run for right channel if exisiting
      M0 = M0 - 1;
   if NZ jump chan_loop;   
   L5 = 0;
#ifdef BASE_REGISTER_MODE  
   push Null;
   pop B5;
#endif
   
   rts;   
.ENDMODULE;
#endif
