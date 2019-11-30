// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_ALIAS_REDUCTION_INCLUDED
#define MP3DEC_ALIAS_REDUCTION_INCLUDED

#include "mp3.h"

// *****************************************************************************
// MODULE:
//    $mp3dec.alias_reduction
//
// DESCRIPTION:
//    Carries out alias reduction on both left and right channels of the current
//    granule.
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    rMAC, r0-r3, r6, r7, r10, DoLoop, I0, I1, I4, I5, M0-3
//
// NOTES:
//    Alias reduction is done on any subbands that use long windows.  Hence
//    if in mixed block mode just the first 2 subbands must be processed.
//
//    Actually for MPEG2 (low sample rate extension) with mixed blocks it
//    should be the first 3 subbands, and for MPEG2.5 @8KHz it should be the
//    first 6 subbands.  As other decoders out there don't do this we currently
//    don't either, we just process the first 2.  This is thought to be an
//    ambiguity in the mpeg specification.
//
//    For alias reduction 8 butterfly operations are done per subband boundary
//
//    @verbatim
//       Alias reduction - butterfly operation
//
/*
//                    Cs[i] +
//      M[I0] -------o------>o------ M[I0]
//                    \    / -
//                     \  /  Ca[i]
//                      \/
//                      /\
//                     /  \  Ca[i]
//                    /    \ +
//      M[I1] -------o------>o------ M[I1]
//                    Cs[i] +
//    @endverbatim
*/
// *****************************************************************************
.MODULE $M.mp3dec.alias_reduction;
   .CODESEGMENT MP3DEC_ALIAS_REDUCTION_PM;
   .DATASEGMENT DM;

   $mp3dec.alias_reduction:

   r6 = M[$mp3dec.current_grch];
   r6 = r6 AND $mp3dec.GRANULE_MASK;

   M0 = 17;
   M1 = 18;
   M2 = 26;
   M3 = 10;

   chan_loop:

      // select appropriate channel buffer
      r2 = r6 AND $mp3dec.CHANNEL_MASK;
      if NZ jump is_right;
         #ifdef BASE_REGISTER_MODE
            r7 = M[$mp3dec.arbuf_start_left];
         #endif
         r0 = M[$mp3dec.arbuf_left_pointer];
         r1 = M[$mp3dec.arbuf_left_size];
         jump ar_Buf_initialised;
      is_right:
         #ifdef BASE_REGISTER_MODE
            r7 = M[$mp3dec.arbuf_start_right];
         #endif
         r0 = M[$mp3dec.arbuf_right_pointer];
         r1 = M[$mp3dec.arbuf_right_size];
      ar_Buf_initialised:
      I0 = r0;
      L0 = r1;
      #ifdef BASE_REGISTER_MODE
         push r7;
         pop B0;
      #endif
      I1 = r0,
       r0 = M[I0, M0];        // dummy read, I0 += 17;
      L1 = r1;
      #ifdef BASE_REGISTER_MODE
         push r7;
         pop B1;
      #endif
      r0 = M[I1, M1];         // dummy read I1 += 18;

      r0 = M[$mp3dec.block_type + r6];

      // if Mixedflag=0 & block_type=2 then no AR
      Null = r0 - $mp3dec.SHORT_MASK;
      if Z jump chan_done;

      // obtain the number of sub-bands according to rzero
      r7 = 1; // if Mixedflag=1 & block_type=2 then only sb 1-2
      Null = r0 - ($mp3dec.MIXED_MASK + $mp3dec.SHORT_MASK);
      if Z jump subband_loop;
      r1 = M[$mp3dec.rzerolength + r2];
      r1 = 583 - r1;
      r1 = r1 * 0.22222220897675 (frac);
      r7 = r1 ASHIFT -2;
      if LE jump chan_done;   // if r7 <= 0, this channel is all-zero
      r2 = r7 - 31;
      if GT r7 = r7 - r2;     // r7 = min(floor((583 - rzero)/18), 31);

      subband_loop:
         r10 = 8;
         I4 = &$mp3dec.ar_cs;
         I5 = &$mp3dec.ar_ca;
         do sample_loop;
            // r0 = top bufferfly input
            // r2 = Cs coef
            // r1 = bottom bufferfly input
            // r3 = Ca coef
            r0 = M[I0,0],
             r2 = M[I4,1];
            rMAC = r0 * r2,
             r1 = M[I1,0],
             r3 = M[I5,1];
            rMAC = rMAC - r1 * r3;

            // store top bufferfly output
            rMAC = r1 * r2,
             M[I0,-1] = rMAC;

            // store bottom bufferfly output
            rMAC = rMAC + r0 * r3;
            M[I1,1] = rMAC;
         sample_loop:

         r0 = M[I0, M2];         // dummy read, I0 += 26;
         r0 = M[I1, M3];         // dummy read, I1 += 10;
         r7 = r7 - 1;
      if NZ jump subband_loop;

      chan_done:
      r6 = r6 + 1;
      Null = r6 AND 1;
   if NZ jump chan_loop;
   L0 = 0;
   L1 = 0;
   #ifdef BASE_REGISTER_MODE
      push Null;
      push Null;
      pop B0;
      pop B1;
   #endif
   rts;

.ENDMODULE;

#endif
