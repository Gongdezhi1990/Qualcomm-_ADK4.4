// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CELT_DEEMPHASIS_INCLUDED
#define CELT_DEEMPHASIS_INCLUDED
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.deemphasis
//
// DESCRIPTION:
//   applying deempahsis filter to the final output
// INPUTS:
//   r3 = start freq
//   r2 = decay
// OUTPUTS:
//  I5/L5 in-place input/output buffer 
//  r5 = object
//  r10 = frame size
//  r7 = channel (0-> left, 1->right)
// TRASHED REGISTERS:
// 
// NOTE:
// *****************************************************************************
.MODULE $M.celt.deemphasis;
   .CODESEGMENT CELT_DEEMPHASIS_PM;
   .DATASEGMENT DM;
   $celt.deemphasis:

#ifdef BASE_REGISTER_MODE
   r0 = M[$celt.dec.left_obuf_start_addr];
   push r0;
   pop B5;
#endif
   r0 = M[$celt.dec.left_obuf_addr];
   r1 = M[$celt.dec.left_obuf_len];
   I5 = r0;
   L5 = r1;

   r3 = 1.0;//1.0/2.0; //scale factor 
   M2 = -1;
   M3 = 2;
   r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   M0 = r0 + 1;
   r0 = M[r5 + $celt.dec.MODE_E_PRED_COEF_FIELD];   //r0 = alpha
   r6 = r5;
   chan_loop:
      r10 = M[r5 + $celt.dec.MODE_AUDIO_FRAME_SIZE_FIELD];
      r10 = r10 - 1;
      rMAC = M[r6 + $celt.dec.DEEMPH_HIST_SAMPLE_FIELD];                    
      rMAC = rMAC * r0, r1 = M[I5, 1];                                                             
      do deemphasis_loop;
         rMAC = rMAC + r1 * r3, r1 = M[I5, M2];
         r4 = rMAC ASHIFT 1;
         rMAC = rMAC * r0, M[I5, M3] = r4;
      deemphasis_loop:
      rMAC = rMAC + r1 * r3, r1 = M[I5, M2];
      r4 = rMAC ASHIFT 1;
      M[I5, M3] = r4;
      M[r6 + $celt.dec.DEEMPH_HIST_SAMPLE_FIELD] = rMAC; 

     // set up registers for second channel
#ifdef BASE_REGISTER_MODE
      r1 = M[$celt.dec.right_obuf_start_addr];
      push r1;
      pop B5;
#endif
      r1 = M[$celt.dec.right_obuf_addr];
      I5 = r1;
      r1 = M[$celt.dec.right_obuf_len];
      L5 = r1;
      r6 = r6 + 1;

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
