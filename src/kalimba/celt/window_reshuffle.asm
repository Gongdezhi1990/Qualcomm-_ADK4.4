// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.   
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CELT_WINDOW_RESHUFFLE_INCLUDED
#define CELT_WINDOW_RESHUFFLE_INCLUDED
#include "stack.h"
// *****************************************************************************
// MODULE:
//    $celt.window_reshuffle
//
// DESCRIPTION:
//    apply window and overlap to the input buffer and reshuffle it more suitable
//    for mdct transform
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
// ***************************************************************************************
.MODULE $M.celt.window_reshuffle;
   .CODESEGMENT CELT_WINDOW_RESHUFFLE_PM;
   .DATASEGMENT DM;
   $celt.window_reshuffle:

   r7 = M[r5 + $celt.enc.MODE_OVERLAP_FIELD];   //OV
   r7 = r7 LSHIFT -1;                           //OV/2
   I0 = r7 + I0;
   I3 = I0 - 1;                                 
   I1 = I3 + r8;                               
   I2 = I0 + r8;                                
   r0 = M[r5 + $celt.enc.MODE_WINDOW_ADDR_FIELD];   
   I4 = r0 + r7;                               
   I5 = I4 - 1;                                
   
   M0 = 2;
   M1 = -2;
   M2 = 1;
   r10 = r7 LSHIFT -1;
   r10 = r10 - M2, r0 = M[I4, M0], r2 = M[I1, M1];  
   rMAC = r0 * r2, r2 = M[I2, M0];
   r1 = M[I5, M1];
   do window_rs1_loop;
      rMAC = rMAC + r1*r2, r2 = M[I0, M0];
      rMAC = r2 * r0, M[I6, M2] = rMAC, r2 = M[I3, M1];
      rMAC = rMAC - r1*r2,  r0 = M[I4, M0], r2 = M[I1, M1];
      rMAC = r0*r2, M[I7, M2] = rMAC, r2 = M[I2, M0];
      r1 = M[I5, M1];
   window_rs1_loop:
   rMAC = rMAC + r1*r2, r2 = M[I0, M0];
   rMAC = r2 * r0, M[I6, M2] = rMAC, r2 = M[I3, M1];
   rMAC = rMAC - r1*r2;
   M[I7, M2] = rMAC;   

   r10 = r8 LSHIFT -1;
   r10 = r10 - r7;
   if LE jump end_flat_copy;
   r10 = r10 - M2, r0 = M[I0, M0];
   do flat_copy_loop;
      r1 = M[I1, M1], M[I7, M2] = r0;
      r0 = M[I0, M0], M[I6, M2] = r1;
   flat_copy_loop:
   r1 = M[I1, M1], M[I7, M2] = r0;
   M[I6, M2] = r1;   
   end_flat_copy:

   r0 = M[r5 + $celt.enc.MODE_WINDOW_ADDR_FIELD];   
   I4 = r0;                               //w1
   I5 = I4 + r7;                          //w2
   I5 = I5 + r7;
   I5 = I5 - 1;
   r10 = r7 LSHIFT -1;
   I2 = I0 - r8;                                 //xp2[-N2]
   I3 = I1 + r8;                                //xp1[N2]   
   
   r10 = r10 - M2, r0 = M[I5, M1], r2 = M[I1, M1];  
   rMAC = r0 * r2, r2 = M[I2, M0];
   r1 = M[I4, M0];
   do window_rs2_loop;
      rMAC = rMAC - r1*r2, r2 = M[I0, M0];
      rMAC = r2 * r0, M[I6, M2] = rMAC, r2 = M[I3, M1];
      rMAC = rMAC + r1*r2,  r0 = M[I5, M1], r2 = M[I1, M1];
      rMAC = r0*r2, M[I7, M2] = rMAC, r2 = M[I2, M0];
      r1 = M[I4, M0];
   window_rs2_loop:
   rMAC = rMAC - r1*r2, r2 = M[I0, M0];
   rMAC = r2 * r0, M[I6, M2] = rMAC, r2 = M[I3, M1];
   rMAC = rMAC + r1*r2, r2 = M[I1, M1];
   M[I7, M2] = rMAC;   

   // pop rLink from stack
   rts;


.ENDMODULE;


#endif
